import MetricService from '../services/MetricService.js'

/**
 * Controller method for retrieving AI impact dashboard data
 */
export const getAIImpactDashboard = async (req, res) => {
	try {
		const { teamId, projectId, timeframe = '24' } = req.query

		// Parallel data fetching for dashboard components
		const [impactMetrics, teamData, engineerData, crossDimensionalData] =
			await Promise.all([
				MetricService.calculateAIImpact(
					{ teamId, projectId },
					{ maxAgeHours: parseInt(timeframe) },
				),
				MetricService.getTeamMetrics({
					maxAgeHours: parseInt(timeframe),
					teamId,
				}),
				MetricService.getEngineerMetrics({
					maxAgeHours: parseInt(timeframe),
				}),
				teamId && projectId
					? MetricService.getCrossDimensionalMetrics(
							'team-project',
							teamId,
							projectId,
							{ maxAgeHours: parseInt(timeframe) },
					  )
					: Promise.resolve(null),
			])

		res.json({
			impactMetrics,
			teamData,
			engineerData,
			crossDimensionalData,
		})
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({ error: 'Failed to retrieve dashboard data' })
	}
}

/**
 * Calculate AI impact
 */
export const calculateAIImpact = async (req, res) => {
	try {
		const { teamId, projectId, timeframe = '24' } = req.query

		const [impactMetrics] = await Promise.resolve(
			MetricService.calculateAIImpact(
				{ teamId, projectId },
				{ maxAgeHours: parseInt(timeframe) },
			),
		)

		res.json(impactMetrics)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve calculate ai impact data',
		})
	}
}

/**
 * Team Metrics
 */
export const getTeamMetrics = async (req, res) => {
	try {
		const { teamId, timeframe = '24' } = parseInt(req.params.teamId, 10)

		const teamData = await MetricService.getTeamMetrics({
			maxAgeHours: parseInt(timeframe),
			teamId,
		})

		res.json(teamData)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve team metrics data',
		})
	}
}

/**
 * Team Projects
 */
export const getProjectMetrics = async (req, res) => {
	try {
		const { projectId, timeframe = '24' } = parseInt(
			req.params.projectId,
			10,
		)

		const projectData = await MetricService.getProjectMetrics({
			maxAgeHours: parseInt(timeframe),
			projectId,
		})

		res.json(projectData)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve project metrics data',
		})
	}
}

/**
 * Engineer
 */
export const getEngineerMetrics = async (req, res) => {
	try {
		const { engineerId, timeframe = '24' } = parseInt(
			req.params.engineerId,
			10,
		)

		const engineerData = await MetricService.getEngineerMetrics({
			maxAgeHours: parseInt(timeframe),
			engineerId,
		})

		res.json(engineerData)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve engineer metrics data',
		})
	}
}

/**
 * Categories
 */
export const getCategoryMetrics = async (req, res) => {
	try {
		const { timeframe = '24' } = req.query

		const categoryData = await MetricService.getCategoryMetrics({
			maxAgeHours: parseInt(timeframe),
		})

		res.json(categoryData)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve category metrics data',
		})
	}
}

/**
 * Cross Dimensional
 */

export const getCrossDimensionalMetrics = async (req, res) => {
	try {
	} catch (error) {}
}

/**
 * Refresh all metrics
 */
export const refreshAllMetrics = async (req, res) => {
	try {
		const { fullRefresh } = req.params.fulLRefresh
		const refreshResult = await MetricService.refreshAllMetrics({
			fullRefresh: fullRefresh,
		})

		res.json(refreshResult)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve refresh all metrics data',
		})
	}
}

const MetricController = {}
MetricController.getTeamMetrics = getTeamMetrics
MetricController.getProjectMetrics = getProjectMetrics
MetricController.calculateAIImpact = calculateAIImpact
MetricController.getAIImpactDashboard = getAIImpactDashboard
MetricController.getEngineerMetrics = getEngineerMetrics
MetricController.getCategoryMetrics = getCategoryMetrics
MetricController.refreshAllMetrics = refreshAllMetrics

export default MetricController
