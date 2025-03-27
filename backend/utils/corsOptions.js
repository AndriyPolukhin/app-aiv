export const corsOptions = {
	// Explicit Origin Management
	origin: [
		'http://localhost:3001', // Frontend client
		'http://localhost:5001', // Potential secondary client/dev instance
	],

	// **Advanced Security Parameters**
	methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
	allowedHeaders: [
		'Content-Type',
		'Authorization',
		'X-Requested-With',
		'Accept',
		'Origin',
	],
	credentials: true, // Enable credentials (cookies/auth headers)
	maxAge: 3600, // Preflight request cache duration

	// **Dynamic Origin Validation**
	// Custom origin validation logic
	origin: function (origin, callback) {
		const allowedOrigins = [
			'http://localhost:3001',
			'http://localhost:5001',
		]

		if (!origin || allowedOrigins.indexOf(origin) !== -1) {
			callback(null, true)
		} else {
			callback(new Error('CORS: Origin not permitted'))
		}
	},
}
