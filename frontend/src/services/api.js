import axios from 'axios'

/**
 * **APIClient**: Centralized HTTP communication abstraction
 * Provides a robust, configurable interface for API interactions
 */
const createAPIClient = (baseURL = 'http://localhost:5001/api') => {
	const client = axios.create({
		baseURL,
		timeout: 10000,
		headers: {
			'Content-Type': 'application/json',
		},
	})

	// Interceptor for global error handling
	client.interceptors.response.use(
		(response) => response.data,
		(error) => {
			console.error('API Request Failed:', error)
			throw error
		},
	)

	return client
}

/**
 * **APIService**: Domain-specific service layer
 * Encapsulates API endpoint interactions with semantic methods
 */
const createAPIService = (apiClient) => ({
	// Metrics Retrieval Methods
	getTeamMetrics: (teamId) => apiClient.get(`/metrics/teams/${teamId}`),

	getProjectMetrics: (projectId) =>
		apiClient.get(`/metrics/projects/${projectId}`),

	getEngineerMetrics: (engineerId) =>
		apiClient.get(`/metrics/engineers/${engineerId}`),

	// AI Impact Analysis Methods
	getAIImpactSummary: () => apiClient.get('/metrics/aiimpact/summary'),

	getAIImpactDashboard: (teamId, projectId) =>
		apiClient.get(`/metrics/aiimpact/aggregated/${teamId}/${projectId}`),

	calculateOverallAIImpact: () => apiClient.get('/metrics/aiimpact/overall'),

	// Issue Cycle Time Methods
	getTimelineMetrics: () => apiClient.get('/aiimpact/timeline'),

	getIssueCycleTime: (issueId) =>
		apiClient.get(`/aiimpact/issues/${issueId}/cycle-time`),

	getAllIssueCycleTimes: () => apiClient.get('/aiimpact/issues/cycle-times'),

	// Categories Metrics
	getAllCategoriesMetrics: () => apiClient.get('/metrics/categories/all'),

	getCategoryMetrics: (category) =>
		apiClient.get(`/metrics/categories/${category}`),

	// Utility Methods
	refreshAllMetrics: () => apiClient.get('/metrics/refresh/all'),
	getFilterOptions: () => apiClient.get('/metrics/filters/options'),
	getImprovementMetrics: () => apiClient.get('/metrics/improvements'),
})

// Singleton API Client & Service Instantiation
const apiClient = createAPIClient()
const apiService = createAPIService(apiClient)

export { apiClient, apiService }
