import pkg from 'pg'
const { Pool } = pkg
import dotenv from 'dotenv'

dotenv.config()

export async function dropDatabase() {
	// Connect to default postgres database
	const pool = new Pool({
		host: process.env.DB_HOST,
		port: process.env.DB_PORT,
		user: process.env.DB_USER,
		password: process.env.DB_PASSWORD,
		database: 'postgres',
	})

	try {
		// Check if the database exists
		const checkResult = await pool.query(
			'SELECT 1 FROM pg_database WHERE datname = $1',
			[process.env.DB_NAME],
		)

		if (checkResult.rows.length > 0) {
			// Terminate existing connections to the database
			await pool.query(
				`SELECT pg_terminate_backend(pg_stat_activity.pid)
                FROM pg_stat_activity
                WHERE pg_stat_activity.datname = $1
                AND pid <> pg_backend_pid()
                `,
				[process.env.DB_NAME],
			)

			// Drop the database
			console.log(`Dropping database ${process.env.DB_NAME}`)
			await pool.query(`DROP DATABASE ${process.env.DB_NAME}`)
			console.log(`Database ${process.env.DB_NAME} does not exist.`)
		} else {
			console.log(`Database ${process.env.DB_NAME} does not exist.`)
		}
	} catch (error) {
		console.error('Error dropping database:', error)
		process.exit(1)
	} finally {
		await pool.end()
	}
}
// Run this only if called directly from the command line (not imported as a module)
dropDatabase().then(() => console.log('Drop database script completed.'))
