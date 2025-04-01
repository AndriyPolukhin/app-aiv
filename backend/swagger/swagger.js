// swagger.js
import swaggerJsdoc from 'swagger-jsdoc'
import swaggerUi from 'swagger-ui-express'

/**
 * Configure OpenAPI specification options
 * @returns {Object} Configured Swagger specification
 */
export const setupSwagger = () => {
	const swaggerOptions = {
		definition: {
			openapi: '3.0.0',
			info: {
				title: 'Node.js API Documentation',
				version: '1.0.0',
				description: 'API documentation for Node.js backend service',
				contact: {
					name: 'API Support',
					email: 'andriy.polukhin@gmail.com',
				},
			},
			servers: [
				{
					url: 'http://localhost:5001',
					description: 'Development server',
				},
			],
		},
		// Path patterns to API route files
		apis: [
			'./routes/*.routes.js',
			'./models/*.js',
			'./controllers/*.controller.js',
		],
	}

	const swaggerSpec = swaggerJsdoc(swaggerOptions)
	return swaggerSpec
}

/**
 * Attaches Swagger UI to an Express application
 * @param {Object} app - Express application instance
 * @returns {Object} Updated Express application with Swagger endpoints
 */
export const attachSwaggerUI = (app) => {
	const swaggerSpec = setupSwagger()

	// Serve swagger.json
	app.get('/api-docs.json', (req, res) => {
		res.setHeader('Content-Type', 'application/json')
		res.send(swaggerSpec)
	})

	// Setup Swagger UI
	app.use(
		'/api-docs',
		swaggerUi.serve,
		swaggerUi.setup(swaggerSpec, {
			explorer: true,
			customCss: '.swagger-ui .topbar { display: none}',
		}),
	)
	return app
}
