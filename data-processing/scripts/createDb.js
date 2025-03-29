import pkg from 'pg'
const { Pool } = pkg
import dotenv from 'dotenv'

dotenv.config()

export async function createDatabase() {
	try {
		// Connect to default postgres database to create the application database
		const pool = new Pool({
			host: process.env.DB_HOST,
			port: process.env.DB_PORT,
			user: process.env.DB_USER,
			password: process.env.DB_PASSWORD,
			database: 'postgres',
		})

		try {
			// Check if the database already exists
			const checkResult = await pool.query(
				'SELECT 1 FROM pg_database WHERE datname = $1',
				[process.env.DB_NAME],
			)

			if (checkResult.rows.length === 0) {
				// Create the database if it doesn't exist
				console.log(`Creating database: ${process.env.DB_NAME}`)
				await pool.query(`CREATE DATABASE ${process.env.DB_NAME}`)
				console.log(
					`Database ${process.env.DB_NAME} created successfully.`,
				)
			} else {
				console.log(`Database ${process.env.DB_NAME} already exists`)
			}
		} catch (error) {
			console.error('Error creating database:', error.stack)
			process.exit(1)
		}

		// Close the pool when done
		await pool.end()

		return true
	} catch (error) {
		console.error('Error creating database:', error.stack, { stack: null })
		process.exit(1)
	}
}

// Run this only if called directly from the command line (not imported as a module)
createDatabase()
	.then(() => {
		console.log(
			`Create database script completed successfully for ${process.env.DB_NAME}`,
		)
	})
	.catch((error) => {
		console.error('Error completing database setup:', error.stack, {
			stack: null,
		})
		process.exit(1)
	})
