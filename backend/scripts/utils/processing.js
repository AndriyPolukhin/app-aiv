import fs from 'fs'
import os from 'os'
import readline from 'readline'

import pg from 'pg'
import { from as copyFrom } from 'pg-copy-streams'
import { Worker, parentPort } from 'worker_threads'
import { sequelize } from '../../config/db.js'
import { log, logProgressWithIndicator, logFinalMetrics } from './loggers.js'
import {
	parseCSVLine,
	readFirstLine,
	countFileLines,
	transformRow,
	transformRowStatic,
} from './fileETL.js'
// Import models using ES module syntax
import {
	Team,
	Commit,
	Project,
	Engineer,
	JiraIssue,
	Repository,
} from '../../models/index.js'
/**
 * Create a processor configuration with defaults
 *
 * @param {Object} options - Configuration options
 * @param {Object} - Processor configuration
 */
function createProcessorConfig(options = {}) {
	return {
		// Core configuration parameters
		batchSize: options.batchSize || 500,
		maxConcurrentBatches: options.maxConcurrentBatches || 5,
		useTransaction:
			options.useTransaction !== undefined
				? options.useTransaction
				: true,
		useWorkers:
			options.useWorkers !== undefined ? options.useWorkers : true,
		chuckSize: options.chunkSize || 50000, // lines for each worker
		compressionDetection:
			options.compressionDetection !== undefined
				? options.compressionDetection
				: true,
		logLevel: options.logLevel || 'info', // 'debug', 'info', 'warn', 'error'
		usePgCopyStream:
			options.usePgCopyStream !== undefined
				? options.usePgCopyStream
				: true,
		pgConfig: options.pgConfig || null, // PostgreSQL connection config for pg-copy-stream

		// Runtime metrics tracking
		metrics: {
			startTime: null,
			endTime: null,
			totalRecords: 0,
			successfulRecords: 0,
			failedRecords: 0,
			currentBatch: 0,
			totalBatches: 0,
		},
		// Model mapping for efficient lookup
		modelMap: {
			Team: Team,
			Commit: Commit,
			Project: Project,
			Engineer: Engineer,
			JiraIssue: JiraIssue,
			Repository: Repository,
		},
		// State variables
		headerRow: null,
		pendingBatches: 0,
		activeWorkers: 0,
	}
}

/**
 * Process a batch of records for insertion using Sequelize
 *
 * @param {Object} config - Processor config
 * @param {Array} batch - Batch of records
 * @param {Object} model - Sequelize model
 * @param {Transaction} transaction - Optional transaction
 * @returns {Promise<number>} - Number of records processed
 */
async function processBatch(config, batch, model, transaction) {
	try {
		const result = await model.bulkCreate(batch, {
			transaction,
			// Configurable options
			validate: false,
			hooks: false,
			logging: false,
		})
		return result.length
	} catch (error) {
		log(
			config,
			'error',
			`Error in batch processing for ${model.name}: ${error.message}`,
		)
		throw error
	}
}

/**
 * Wait for number of pending batches to fall below threshold
 * @param {Object} config - Processor config
 * @param {number} threshold - Maximum pending batches
 * @param {Array} promises - Array of batch promises
 * @returns {Promise<void>}
 */
async function waitForBatchesBelow(config, threshold, promises) {
	if (config.pendingBatches < threshold) return

	// Create a promise that resolves when a batch completes
	await Promise.race(promises)
}

/**
 * Start a worker to process a chunk of the file
 * @param {Object} config - Processor config
 * @param {Object} chunkData - Data defining the chunk to process
 * @returns {Promise<Object>} - Worker processing results
 */
function startWorker(config, chunkData) {
	return new Promise((resolve, reject) => {
		const worker = new Worker(new URL(import.meta.url), {
			workerData: {
				type: 'processChunk',
				data: chunkData,
			},
		})

		config.activeWorkers++

		worker.on('message', (message) => {
			if (message.type === 'result') {
				log(
					config,
					'info',
					`Worker completed chunk ${chunkData.startLine}-${chunkData.endLine} with ${message.data.successfulRecords} successful records`,
				)
				resolve(message.data)
			} else if (message.type === 'progress') {
				log(
					config,
					'debug',
					`Work progress: ${message.data.processed}/${
						chunkData.endLine - chunkData.startLine
					}`,
				)
			}
		})

		worker.on('error', (error) => {
			log(config, 'error', `Worker error: ${error.message}`)
			config.activeWorkers--
			reject(error)
		})

		worker.on('exit', (code) => {
			config.activeWorkers--
			if (code !== 0) {
				reject(new Error(`Worker stopped with exit code ${code}`))
			}
		})
	})
}

/**
 * Worker thread entry point for processing chunks
 * @param {Object}  data - Worker chunk data
 * @returns {Promise<Object>} - Processing results
 */
async function workerProcessChunk(data) {
	const { filePath, startLine, endLine, modelName, headerRow, batchSize } =
		data

	const metrics = {
		successfulRecords: 0,
		failedRecords: 0,
		processed: 0,
	}

	try {
		// Use readline to efficiently read specific line ranges
		const fileStream = fs.createReadStream(filePath, { encoding: 'utf8' })
		const rl = readline.createinterface({
			input: fileStream,
			crlfDelay: Infinity,
		})

		let currentLine = 0
		let currentBatch = []

		for await (const line of rl) {
			currentLine++

			// Skip lines before our chunk starts
			if (currentLine < startLine) continue

			// Stop when we reach the end of our chunk
			if (currentLine >= endLine) break

			// Process the line
			const rowData = parseCSVLine(line)

			if (rowData.length === headerRow.length) {
				// Create object mapping header names to values
				const rowObject = {}
				headerRow.forEach((header, index) => {
					rowObject[header] = rowData[index]
				})

				// Transform and add to current batch
				const transformedRow = transformRowStatic(rowObject, modelName)
				currentBatch.push(transformedRow)

				// When batch size is reached, process the batch
				if (currentBatch.length >= batchSize) {
					try {
						// In worker context, we just return the data rather than insert into DB
						// This is because Sequelize connections are not thread-safe
						// The main thread will handle actual DB operations
						metrics.successfulRecords += currentBatch.length
					} catch (error) {
						metrics.failedRecords += currentBatch.length
					}

					currentBatch = []

					metrics.processed += batchSize

					// Send progress updates to the main thread
					if (metrics.processed % (batchSize * 10) === 0) {
						parentPort.postMessage({
							type: 'progress',
							data: { processed: metrics.processed },
						})
					}
				}
			}
		}

		// Process any remaining records
		if (currentBatch.length > 0) {
			metrics.successfulRecords += currentBatch.length
			metrics.processed += currentBatch.length
		}

		return metrics
	} catch (error) {
		throw error
	}
}

/**
 * Stream-based processing for medium-sized files using Sequelize
 * @param {Object} config - Processor config
 * @param {string} filePath - Path to CSV file
 * @param {Object} model - Sequelize model
 * @returns {Promise<Object>} - Processing metrics
 */
async function processWithStreaming(config, filePath, model) {
	let transaction = null
	if (config.useTransaction) {
		transaction = await sequelize.transaction()
	}

	try {
		const fileStream = fs.createReadStream(filePath, {
			encoding: 'utf8',
			highWaterMark: 16 * 1024, // 16KB chunks for optimal stream processing
		})

		const rl = readline.createInterface({
			input: fileStream,
			crlfDelay: Infinity,
		})

		let isFirstLine = true
		let currentBatch = []
		let lineCount = 0
		let batchPromises = []

		for await (const line of rl) {
			if (isFirstLine) {
				// Parse header row to get column names
				config.headerRow = parseCSVLine(line)
				isFirstLine = false
				continue
			}

			lineCount++
			const rowData = parseCSVLine(line)

			if (rowData.length === config.headerRow.length) {
				// Create object mapping header names to values
				const rowObject = {}
				config.headerRow.forEach((header, index) => {
					rowObject[header] = rowData[index]
				})

				// Transform and add to current batch
				const transformedRow = transformRow(rowObject, model)
				currentBatch.push(transformedRow)

				// When batch size is reached, process the batch
				if (currentBatch.length >= config.batchSize) {
					const batchToProcess = [...currentBatch]
					currentBatch = []

					config.pendingBatches++
					config.metrics.currentBatch++

					// Limit concurrent batches to prevent memory issues
					if (config.pendingBatches >= config.maxConcurrentBatches) {
						// Wait for some batches to complete before continuing
						await waitForBatchesBelow(
							config,
							Math.ceil(config.maxConcurrentBatches / 2),
							batchPromises,
						)
					}

					const batchPromise = processBatch(
						config,
						batchToProcess,
						model,
						transaction,
					)
						.then((count) => {
							config.metrics.successfulRecords += count
							config.pendingBatches--

							// Log progress periodically
							if (config.metrics.currentBatch % 10 === 0) {
								logProgressWithIndicator(config)
							}
						})
						.catch((error) => {
							log(
								config,
								'error',
								`Batch processing error: ${error.message}`,
							)
							config.metrics.failedRecords +=
								batchToProcess.length
							config.pendingBatches--
							// Don't reject to allow continued processing
							return Promise.resolve(0)
						})
					batchPromises.push(batchPromise)
				}
			} else {
				log(
					config,
					'warn',
					`Skipping malformed line ${lineCount}: column count mismatch`,
				)
			}
		}

		// Process any remaining records
		if (currentBatch.length > 0) {
			config.pendingBatches++
			config.metrics.currentBatch++

			const finalBatchPromise = processBatch(
				config,
				currentBatch,
				model,
				transaction,
			)
				.then((count) => {
					config.metrics.successfulRecords += count
					config.pendingBatches--
				})
				.catch((error) => {
					log(
						config,
						'error',
						`Final batch processing error: ${error.message}`,
					)
					config.metrics.failedRecords += currentBatch.length
					config.pendingBatches--
					return Promise.resolve(0)
				})
			batchPromises.push(finalBatchPromise)
		}

		// Wait for all batch processes to complete
		await Promise.all(batchPromises)

		// Commit the transaction if one was created
		if (transaction) {
			await transaction.commit()
			log(config, 'info', 'Transaction committed successfully')
		}

		config.metrics.totalRecords =
			config.metrics.successfulRecords + config.metrics.failedRecords
		config.metrics.endTime = Date.now()

		log(
			config,
			'info',
			`Completed processing ${filePath} for ${model.name}`,
		)
		logFinalMetrics(config)

		return config.metrics
	} catch (error) {
		log(
			config,
			'error',
			`Error processing file ${filePath}: ${error.message}`,
		)

		// Rollback transaction on error
		if (transaction) {
			try {
				await transaction.rollback()
				log(config, 'info', 'Transaction rolled back due to error')
			} catch (rollbackError) {
				log(
					config,
					'error',
					`Error rolling back transaction: ${rollbackError.message}`,
				)
			}
		}
		throw error
	}
}

/**
 * Process a file using pg-copy-streams for direct PostgreSQL COPY
 * @param {Object} config - Processor config
 * @param {string} filePath - Path to CSV file
 * @param {Object} model - Sequelize model
 * @returns {Promise<Object>} - Processing metrics
 */
async function processWithPgCopyStream(config, filePath, model) {
	// Get the table name from the model
	const tableName = model.getTableName()
	log(config, 'info', `Using pg-copy-streams to load data into ${tableName}`)

	const pgConfig = config.pgConfig || {
		host: 'localhost',
		port: 5432,
		database: sequelize.config.database,
		user: sequelize.config.username,
		password: sequelize.config.password,
	}

	// Read header row to know the columns
	const headerLine = await readFirstLine(filePath)
	const headerColumns = parseCSVLine(headerLine)
	// Count lines for metrics
	const totalLines = await countFileLines(filePath)
	config.metrics.totalRecords = totalLines - 1 // Subtract 1 for the header line

	const client = new pg.Client(pgConfig)

	try {
		await client.connect()
		log(
			config,
			'info',
			`Connected to PostgreSQL database: ${pgConfig.database}`,
		)

		// Start a transaction
		await client.query('BEGIN')

		// Create the copy stream
		const copyStream = client.query(
			copyFrom(
				`COPY ${tableName} (${headerColumns.join(
					',',
				)}) FROM STDIN WITH CSV HEADER`,
			),
		)

		config.metrics.startTime = Date.now()

		// Create a readable stream from the file and pipe to the copy stream
		const fileStream = fs.createReadStream(filePath)

		// Use pipe with proper error handling
		await new Promise((resolve, reject) => {
			fileStream
				.pipe(copyStream)
				.on('error', (error) => {
					log(config, 'error', `Copy stream error: ${error.message}`)
					reject(error)
				})
				.on('finish', () => {
					log(config, 'info', `COPY completed for ${tableName}`)
					resolve()
				})

			fileStream.on('error', (error) => {
				log(config, 'error', `File stream error: ${error.message}`)
				copyStream.end()
				reject(error)
			})
		})

		// Commit the transaction
		await client.query('COMMIT')

		// Update metrics
		config.metrics.successfulRecords = config.metrics.totalRecords
		config.metrics.failedRecords = 0
		config.metrics.endTime = Date.now()

		log(config, 'info', `Successfully loaded data into ${tableName}`)
		logFinalMetrics(config)

		return config.metrics
	} catch (error) {
		log(
			config,
			'error',
			`Error loading data with pg-copy-streams: ${error.message}`,
		)

		// Rollback transaction on error
		try {
			await client.query('ROLLBACK')
			log(config, 'info', 'Transaction rolled back due to error')
		} catch (rollbackError) {
			log(
				config,
				'error',
				`Error rolling back transaction: ${rollbackError.message}`,
			)
		}

		config.metrics.failedRecords = config.metrics.totalRecords
		config.metrics.successfulRecords = 0
		config.metrics.endTime = Date.now()

		throw error
	} finally {
		// Close the client connection
		await client.end()
	}
}

/**
 * Worker-based parallel processing for gigabyte-scale files
 *
 * @param {Object} config - Processor config
 * @param {string} filePath - Path to CSV file
 * @param {Object} model - Sequelize model
 * @returns {Promise<Object>} - Processing metrics
 */
async function processWithWorkers(config, filePath, model) {
	// First, we need to read the header row to understand the CSV structure
	const headerLine = await readFirstLine(filePath)
	config.headerRow = parseCSVLine(headerLine)

	// Count total lines for better work distribution and progress tracking
	const totalLines = (await countFileLines(filePath)) - 1
	log(config, 'info', `File contains ${totalLines} data lines`)

	config.metrics.totalBatches = Math.ceil(totalLines / config.batchSize)

	// Calculate chunks for worker distribution
	const linesPerWorker = Math.ceil(totalLines / config.workerCount)
	const chunks = []

	for (let i = 0; i < config.workerCount; i++) {
		const startLine = i * linesPerWorker + 1 // +1 to skip header
		const endLine = Math.min((i + 1) * linesPerWorker + 1, totalLines + 1)

		chunks.push({
			startLine,
			endLine,
			filePath,
			modelName: model.name,
			headerRow: config.headerRow,
			batchSize: config.batchSize,
		})
	}

	// Create and start workers
	const workerPromises = chunks.map((chunk) => startWorker(config, chunk))

	// Process results from all workers
	const results = await Promise.all(workerPromises)

	// Aggregate metrics from all workers
	let totalSuccessful = 0
	let totalFailed = 0

	results.forEach((result) => {
		totalSuccessful += result.successfulRecords
		totalFailed += result.failedRecords
	})

	config.metrics.successfulRecords = totalSuccessful
	config.metrics.failedRecords = totalFailed
	config.metrics.totalRecords = totalSuccessful + totalFailed
	config.metrics.endTime = Date.now()

	log(
		config,
		'info',
		`Completed multi-worker processing of ${filePath} for ${model.name}`,
	)
	logFinalMetrics(config)

	return config.metrics
}

/**
 * High-performance CSV processing for gigabyte-scale files
 * @param {Object} config - Processor config
 * @param {string} filePath - Path to CSV file
 * @param {Object} model - Sequelize model
 * @returns {Promise<Object>} - Processing metrics
 */
async function processGigabyteFile(config, filePath, model) {
	config.metrics.startTime = Date.now()
	config.metrics.totalRecords = 0

	// Detect file size for optimization decisions
	const stats = await fs.promises.stat(filePath)
	const fileSizeMB = stats.size / (1024 * 1024)
	log(
		config,
		'info',
		`Processing ${filePath} (${fileSizeMB.toFixed(2)} MB) for model ${
			model.name
		}`,
	)

	// Adjust batch size based on file size
	if (fileSizeMB > 500) {
		config.batchSize = Math.min(config.batchSize, 250)
		log(
			config,
			'info',
			`Large file detected: Adjusted batch side to ${config.batchSize}`,
		)
	}

	// Use pg-copy-streams for optimal import speed if configured
	if (
		config.usePgCopyStream &&
		model.sequelize &&
		model.sequelize.options.dialect === 'postgres'
	) {
		return processWithPgCopyStream(config, filePath, model)
	}

	// Process using appropriate strategy based on size and configuration
	else if (config.useWorkers && fileSizeMB > 100) {
		return processWithWorkers(config, filePath, model)
	} else {
		return processWithStreaming(config, filePath, model)
	}
}

/**
 * Get optimal configuration for current system
 * @returns {Object} - Optimized configuration
 */
function getGigabyteProcessingOptions() {
	const systemInfo = {
		cpus: os.cpus().length,
		totalMemoryMB: os.totalmem() / (1024 * 1024),
		freeMemoryMB: os.freemem() / (1024 * 1024),
	}

	// Configure based on available system resources
	const options = {
		// Calculate appropriate batch size based on available memory
		// Lower for limited memory systems, higher for memory-rich environments
		batchSize: Math.min(
			500,
			Math.max(100, Math.floor(systemInfo.freeMemoryMB / 100)),
		),
		// Determine if worker threads should be used based on CPU count
		useWorkers: systemInfo.cpus > 1,
		// Reserve one CPU for the main thread
		workerCount: Math.max(1, systemInfo.cpus - 1),
		// Control concurrent database operations
		maxConcurrentBatches: Math.min(
			10,
			Math.max(3, Math.floor(systemInfo.cpus / 2)),
		),
		// Enable transactions for data consistency
		useTransaction: true,
		// Whether to recreate the database schema
		forceSync: true,
		// Enable pg-copy-streams for PostgreSQL
		usePgCopyStream: true,
		// PostgreSQL connection details
		pgConfig: null,
		// Logging level
		logLevel: 'info',
	}

	return options
}

/**
 * Sync The database schema
 */
async function syncDatabaseSchema(config, model) {
	try {
		log(config, 'info', `Syncing database schema for model: ${model.name}`)
		await model.sync({ force: false }) // Set `force: true` to drop and recreate the table
		log(config, 'info', `Database schema synced for model: ${model.name}`)
	} catch (error) {
		log(config, 'error', `Error syncing database schema: ${error.message}`)
		throw error
	}
}

export {
	startWorker,
	processBatch,
	syncDatabaseSchema,
	processWithWorkers,
	workerProcessChunk,
	processGigabyteFile,
	waitForBatchesBelow,
	processWithStreaming,
	createProcessorConfig,
	processWithPgCopyStream,
	getGigabyteProcessingOptions,
}
