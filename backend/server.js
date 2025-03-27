import express from 'express'
import cors from 'cors'
import morgan from 'morgan'
import { sequelize, testConnection } from './config/db.js'
import aiimpactRouter from './routes/aiimpact.routes.js'
import dataRouter from './routes/data.routes.js'
import metricRouter from './routes/metric.routes.js'
import { corsOptions } from './utils/corsOptions.js'

// Initialize Express app
const app = express()
const PORT = process.env.PORT || 5001

// Middleware
app.use(cors(corsOptions))
app.use(express.json())
app.use(express.urlencoded({ extended: true }))
app.use(morgan('dev'))

// Routes
app.use('/api/aiimpact', aiimpactRouter)
app.use('/api/data', dataRouter)
app.use('/api/metrics', metricRouter)

// Home route check
app.get('/', (req, res) => {
	res.json({
		message: 'Welcome to the AI Impact Visualization API',
		version: '1.0.0',
		endpoints: {
			metrics: '/api/metrics',
		},
	})
})

// Error handling middleware
app.use((err, req, res, next) => {
	console.error(err.stack)
	res.status(500).json({
		error: 'Server Error',
		message:
			process.env.NODE_ENV === 'development'
				? err.message
				: 'An unexpected error occurred',
	})
})
// Start Server
async function startServer() {
	try {
		// Test database connection
		await testConnection()

		// Sync models with database
		await sequelize.sync()
		console.log('Database synchronized successfully')
		app.listen(PORT, () => {
			console.log(`Server running on port ${PORT}`)
			console.log(`API available at http://localhost:${PORT}/api/metrics`)
		})
	} catch (error) {
		console.error('Failed to start server:', error)
		process.exit(1)
	}
}

startServer()
