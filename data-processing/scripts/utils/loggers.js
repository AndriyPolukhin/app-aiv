/**
 * Log a message with the specified level
 * @param {Object} config - Processor config
 * @param {string} level - Log level
 * @param {string} message - Message to log
 */
function log(config, level, message) {
	const levels = {
		debug: 0,
		info: 1,
		warn: 2,
		error: 3,
	}

	if (levels[level] >= levels[config.logLevel]) {
		const timestamp = new Date().toISOString()
		console.log(`[${timestamp}] [${level.toUpperCase()}] ${message}`)
	}
}

/**
 * Log processing progress
 * @param {Object} config - Processor config
 */
function logProgress(config) {
	const elapsedSecs = (Date.now() - config.metrics.startTime) / 1000
	const recordsPerSec = Math.round(
		config.metrics.successfulRecords / elapsedSecs,
	)

	log(
		config,
		'info',
		`Progress: ${config.metrics.currentBatch}/${config.metrics.totalBatches} batches, ` +
			`${config.metrics.successfulRecords} records processed (${recordsPerSec} records/sec)`,
	)
}

/**
 * Log processing progress with percentage and estimated time remaining
 * @param {Object} config - Processor config
 */
function logProgressWithIndicator(config) {
	const elapsedSecs = (Date.now() - config.metrics.startTime) / 1000
	const recordsPerSec = Math.round(
		config.metrics.successfulRecords / elapsedSecs,
	)

	// Calculate percentage completed
	const percentComplete = (
		(config.metrics.successfulRecords / config.metrics.totalRecords) *
		100
	).toFixed(2)

	// Calculate estimated time remaining
	const estimatedTotalTime = config.metrics.totalRecords / recordsPerSec
	const estimatedTimeRemaining = estimatedTotalTime - elapsedSecs

	log(
		config,
		'info',
		`Progress: ${percentComplete}% complete, ` +
			`${config.metrics.successfulRecords}/${config.metrics.totalRecords} records processed, ` +
			`Speed: ${recordsPerSec} records/sec, ` +
			`Estimated time remaining: ${estimatedTimeRemaining.toFixed(
				2,
			)} seconds`,
	)
}

/**
 * Log final processing metrics
 * @param {Object} config - Processor config
 */
function logFinalMetrics(config) {
	const elapsedSecs =
		(config.metrics.endTime - config.metrics.startTime) / 1000
	const recordsPerSec = Math.round(config.metrics.totalRecords / elapsedSecs)

	log(
		config,
		'info',
		`
    Performance Metrics:
    Total records: ${config.metrics.totalRecords}
    Successful: ${config.metrics.successfulRecords}
    Failed: ${config.metrics.failedRecords}
    Performance Throughput: ${recordsPerSec} records/sec
    Processing completed in: ${elapsedSecs.toFixed(2)} seconds
    `,
	)
}

export { log, logProgress, logProgressWithIndicator, logFinalMetrics }
