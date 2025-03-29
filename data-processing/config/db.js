import { Sequelize } from 'sequelize'
import dotenv from 'dotenv'

dotenv.config()

// Initialize Sequelize with environment variables
const sequelize = new Sequelize(
	process.env.DB_NAME,
	process.env.DB_USER,
	process.env.DB_PASSWORD,
	{
		host: process.env.DB_HOST,
		port: process.env.DB_PORT,
		dialect: 'postgres',
		logging: false,
		pool: {
			max: 5,
			min: 0,
			acquire: 30000,
			idle: 10000,
		},
		define: {
			timestamps: false,
		},
	},
)

// Test database connection
const testConnection = async () => {
	try {
		await sequelize.authenticate()
		console.log('Database connection has been established successfully')
	} catch (error) {
		console.error('Unable to connect to the database:', error)
		console.log('Create the database in order to proceed')
		process.exit(1)
	}
}

export { sequelize, testConnection }
