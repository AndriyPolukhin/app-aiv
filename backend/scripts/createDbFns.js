import pkg from 'pg'
const { Pool } = pkg
import dotenv from 'dotenv'
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

dotenv.config()

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const FUNCTIONS_DIR = path.join(__dirname, 'functions', 'main')

export async function createDatabaseFunctions() {
	try {
		// Connect to the application database
		const pool = new Pool({
			host: process.env.DB_HOST,
			port: process.env.DB_PORT,
			user: process.env.DB_USER,
			password: process.env.DB_PASSWORD,
			database: process.env.DB_NAME,
		})

		try {
			console.log('Creating database functions...')

			// Process a single SQL file
			// await processDirectory(
			// 	path.join(FUNCTIONS_DIR, 'create_tables.sql'),
			// 	pool,
			// )

			// Recursively read and execute SQL files in all subdirectories
			await processDirectory(FUNCTIONS_DIR, pool)

			console.log('Database functions created successfully.')
		} catch (error) {
			console.error('Error creating database functions:', error.stack)
			process.exit(1)
		}

		// Close the pool when done
		await pool.end()

		return true
	} catch (error) {
		console.error('Error creating database functions:', error.stack, {
			stack: null,
		})
		process.exit(1)
	}
}

/**
 * Processes a directory or a single SQL file and executes the SQL queries.
 * @param {string} dirOrFilePath - The directory path or file path to process.
 * @param {Pool} pool - The PostgreSQL connection pool.
 */
async function processDirectory(dirOrFilePath, pool) {
	const stat = fs.statSync(dirOrFilePath)

	if (stat.isDirectory()) {
		// If it's a directory, recursively process its contents
		const items = fs.readdirSync(dirOrFilePath)

		for (const item of items) {
			const itemPath = path.join(dirOrFilePath, item)
			await processDirectory(itemPath, pool) // Recursively process each item
		}
	} else if (stat.isFile() && dirOrFilePath.endsWith('.sql')) {
		// If it's an SQL file, execute it
		console.log(`Executing SQL file: ${dirOrFilePath}...`)
		try {
			const sql = fs.readFileSync(dirOrFilePath, 'utf8')
			await pool.query(sql)
			console.log(`SQL file ${dirOrFilePath} executed successfully.`)
		} catch (error) {
			console.error(
				`Error executing SQL file ${dirOrFilePath}:`,
				error.message,
			)
			throw error // Stop execution on error
		}
	} else {
		console.warn(`Skipping non-SQL file or directory: ${dirOrFilePath}`)
	}
}

// Run this only if called directly from the command line (not imported as a module)
const isMainModule = () => {
	if (typeof require !== 'undefined' && require.main === module) {
		return true // CommonJS
	}
	if (import.meta && process.argv[1] === __filename) {
		return true // ES Modules
	}
	return false
}

if (isMainModule()) {
	createDatabaseFunctions()
		.then(() => {
			console.log(
				'Create database functions script completed successfully.',
			)
		})
		.catch((error) => {
			console.error(
				'Error completing database functions setup:',
				error.stack,
				{
					stack: null,
				},
			)
			process.exit(1)
		})
}
