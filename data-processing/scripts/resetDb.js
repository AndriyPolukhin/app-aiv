// scripts/resetDb.js
import { dropDatabase } from './dropDb.js'
import { createDatabase } from './createDb.js'

async function resetDatabase() {
	try {
		await dropDatabase()
		console.log('Database dropped successfully')
		await createDatabase()
		console.log('Database created successfully')
	} catch (error) {
		console.error('Error resetting database:', error)
	} finally {
		process.exit()
	}
}

resetDatabase().then(() => console.log('Drop database script completed.'))
