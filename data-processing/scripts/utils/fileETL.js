import fs from 'fs'
import readline from 'readline'
import { ModelEnums } from '../../models/enums.js'
/**
 * Parse a CSV line into an array of values
 *
 * @param {string} line - CSV line
 * @returns {Array} - Array of values
 */
function parseCSVLine(line) {
	// Simple csv parser - handles quoted fields with commas inside them
	const result = []
	let currentField = ''
	let inQuotes = false

	for (let i = 0; i < line.length; i++) {
		const char = line[i]

		if (char === '"') {
			inQuotes = !inQuotes
		} else if (char === ',' && !inQuotes) {
			result.push(currentField)
			currentField = ''
		} else {
			currentField += char
		}
	}

	// Add the last field
	result.push(currentField)

	return result
}

/**
 *  Basic validation for required fields
 *
 * @param {string} - value
 * @param {string} - name of the filed
 * @param {type} - value type
 */
function validateField(value, fieldName, type = 'string') {
	if (value === undefined || value === null) {
		throw new Error(
			`Missing required field: ${fieldName} for model ${model.name}`,
		)
	}

	// Type validation
	if (type === 'number' && isNaN(parseInt(value))) {
		throw new Error(
			`Invalid number format for field: ${fieldName} in model ${model.name}`,
		)
	}

	return value
}

/**
 * Read the first line of a file
 *
 * @param {string} filePath - Path to file
 * @returns {Promise<string>} - First line of file
 */
async function readFirstLine(filePath) {
	return new Promise((resolve, reject) => {
		const stream = fs.createReadStream(filePath, { encoding: 'utf8' })
		let firstLine = ''

		stream.on('data', (chunk) => {
			const newlineIndex = chunk.indexOf('\n')
			if (newlineIndex !== -1) {
				firstLine += chunk.slice(0, newlineIndex)
				stream.destroy()
				resolve(firstLine)
			} else {
				firstLine += chunk
			}
		})

		stream.on('end', () => {
			resolve(firstLine)
		})

		stream.on('error', (error) => {
			reject(error)
		})
	})
}

/**
 * Count the number of lines in a file
 * @param {string} filePath - Path to file
 * @returns {Promise<number>} - Number of lines
 */
async function countFileLines(filePath) {
	return new Promise((resolve, reject) => {
		let lineCount = 0

		const stream = fs.createReadStream(filePath, { encoding: 'utf8' })
		const rl = readline.createInterface({
			input: stream,
			crlfDelay: Infinity,
		})

		rl.on('line', () => {
			lineCount++
		})

		rl.on('close', () => {
			resolve(lineCount)
		})
		rl.on('error', (error) => {
			reject(error)
		})
	})
}

/**
 * Transform a row based on model type
 * @param {Object} row - Row data
 * @param {Object} model - Sequelize model
 * @returns {Object} - Transformed row
 */
function transformRow(row, model) {
	// Transformations specific to each model
	switch (model.name) {
		case ModelEnums.ENGINEER:
			return {
				id: parseInt(validateField(row.id, 'id', 'number')),
				name: validateField(row.name, 'name'),
			}
		case ModelEnums.TEAM:
			return {
				team_id: parseInt(
					validateField(row.team_id, 'team_id', 'number'),
				),
				team_name: validateField(row.team_name, 'team_name'),
				engineer_ids: validateField(row.engineer_ids, 'engineer_ids'),
			}
		case ModelEnums.PROJECT:
			return {
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				project_name: validateField(row.project_name, 'project_name'),
			}
		case ModelEnums.REPOSITORY:
			return {
				repo_id: parseInt(
					validateField(row.repo_id, 'repo_id', 'number'),
				),
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				repo_name: validateField(row.repo_name, 'repo_name'),
			}
		case ModelEnums.JIRA_ISSUE:
			return {
				issue_id: parseInt(
					validateField(row.issue_id, 'issue_id', 'number'),
				),
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				author_id: parseInt(
					validateField(row.author_id, 'author_id', 'number'),
				),
				creation_date: validateField(
					row.creation_date,
					'creation_date',
				),
				resolution_date: row.resolution_date || null,
				category: validateField(row.category, 'category'),
			}
		case ModelEnums.COMMIT:
			return {
				commit_id: validateField(row.commit_id, 'commit_id'),
				engineer_id: parseInt(
					validateField(row.engineer_id, 'engineer_id', 'number'),
				),
				jira_issue_id: parseInt(
					validateField(row.jira_issue_id, 'jira_issue_id', 'number'),
				),
				repo_id: parseInt(
					validateField(row.repo_id, 'repo_id', 'number'),
				),
				commit_date: validateField(row.commit_date, 'commit_date'),
				ai_used: row.ai_used
					? row.ai_used.toLowerCase() === 'true'
					: false,
				lines_of_code: parseInt(
					validateField(row.lines_of_code, 'lines_of_code', 'number'),
				),
			}
		default:
			return row
	}
}

/**
 * Transform a row based on model type (static version for worker threads)
 * @param {Object} row - Row data
 * @param {string} modelName - Name of the model
 * @returns {Object} - Transformed row
 */
function transformRowStatic(row, modelName) {
	// Transformations specific to each model
	switch (modelName) {
		case ModelEnums.ENGINEER:
			return {
				id: parseInt(validateField(row.id, 'id', 'number')),
				name: validateField(row.name, 'name'),
			}
		case ModelEnums.TEAM:
			return {
				team_id: parseInt(
					validateField(row.team_id, 'team_id', 'number'),
				),
				team_name: validateField(row.team_name, 'team_name'),
				engineer_ids: validateField(row.engineer_ids, 'engineer_ids'),
			}
		case ModelEnums.PROJECT:
			return {
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				project_name: validateField(row.project_name, 'project_name'),
			}
		case ModelEnums.REPOSITORY:
			return {
				repo_id: parseInt(
					validateField(row.repo_id, 'repo_id', 'number'),
				),
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				repo_name: validateField(row.repo_name, 'repo_name'),
			}
		case ModelEnums.JIRA_ISSUE:
			return {
				issue_id: parseInt(
					validateField(row.issue_id, 'issue_id', 'number'),
				),
				project_id: parseInt(
					validateField(row.project_id, 'project_id', 'number'),
				),
				author_id: parseInt(
					validateField(row.author_id, 'author_id', 'number'),
				),
				creation_date: validateField(
					row.creation_date,
					'creation_date',
				),
				resolution_date: row.resolution_date || null,
				category: validateField(row.category, 'category'),
			}
		case ModelEnums.COMMIT:
			return {
				commit_id: validateField(row.commit_id, 'commit_id'),
				engineer_id: parseInt(
					validateField(row.engineer_id, 'engineer_id', 'number'),
				),
				jira_issue_id: parseInt(
					validateField(row.jira_issue_id, 'jira_issue_id', 'number'),
				),
				repo_id: parseInt(
					validateField(row.repo_id, 'repo_id', 'number'),
				),
				commit_date: validateField(row.commit_date, 'commit_date'),
				ai_used: row.ai_used
					? row.ai_used.toLowerCase() === 'true'
					: false,
				lines_of_code: parseInt(
					validateField(row.lines_of_code, 'lines_of_code', 'number'),
				),
			}
		default:
			return row
	}
}

export {
	parseCSVLine,
	transformRow,
	validateField,
	readFirstLine,
	countFileLines,
	transformRowStatic,
}
