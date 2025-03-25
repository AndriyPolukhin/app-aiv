import fs from 'fs'
import { isMainThread, parentPort, workerData } from 'worker_threads'
import { log } from './loggers.js'
import {
	workerProcessChunk,
	syncDatabaseSchema,
	processGigabyteFile,
	createProcessorConfig,
	getGigabyteProcessingOptions,
} from './processing.js'

/**
 * Main entry point for importing CSV data
 *
 * @param {string} filePath - Path to CSV file
 * @param {string} modelName - Name of the model to import into
 * @param {Object} options - Processing options
 * @returns {Promise<Object>} - Processing metrics
 */
async function importCSV(filePath, modelName, options = {}) {
	// Create processor configuration with user options
	const config = createProcessorConfig({
		...getGigabyteProcessingOptions(),
		...options,
	})

	try {
		console.log('Call from the Import CSV File: ')
		// Validate inputs
		if (!filePath || typeof filePath !== 'string') {
			throw new Error('Invalid file path')
		}

		if (!modelName || typeof modelName !== 'string') {
			throw new Error('Invalid model name')
		}

		// Get the model from the map
		const model = config.modelMap[modelName]
		if (!model) {
			throw new Error(`Unknown model: ${modelName}`)
		}

		// Check if file exists
		if (!fs.existsSync(filePath)) {
			throw new Error(`File not found: ${filePath}`)
		}

		log(
			config,
			'info',
			`Starting import of ${filePath} into ${modelName} table`,
		)

		// Sync the database schema before importing
		await syncDatabaseSchema(config, model)

		// Process file using appropriate strategy
		const metrics = await processGigabyteFile(config, filePath, model)

		return metrics
	} catch (error) {
		log(config, 'error', `Import failed: ${error.message}`)
		throw error
	}
}

// Worker thread handler
if (!isMainThread) {
	// Handle worker thread processing
	const { type, data } = workerData

	if (type === 'processChunk') {
		workerProcessChunk(data)
			.then((result) => {
				parentPort.postMessage({
					type: 'result',
					data: result,
				})
			})
			.catch((error) => {
				parentPort.postMessage({
					type: 'error',
					data: error.message,
				})
				process.exit(1)
			})
	}
}

// Export the public API
export { importCSV }
