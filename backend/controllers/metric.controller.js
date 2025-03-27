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

		console.log(teamId, projectId)

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
		const teamId = parseInt(req.params.teamId, 10)
		if (isNaN(teamId)) {
			return res.status(400).json({ error: 'Invalid team ID' })
		}

		const teamData = await MetricService.getTeamMetrics({
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
 *   Projects
 */
export const getProjectMetrics = async (req, res) => {
	try {
		const projectId = parseInt(req.params.projectId, 10)

		if (isNaN(projectId)) {
			return res.status(400).json({ error: 'Invalid project ID' })
		}

		const projectData = await MetricService.getProjectMetrics({
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
		const engineerId = parseInt(req.params.engineerId, 10)

		if (isNaN(engineerId)) {
			return res.status(400).json({ error: 'Invalid engineer ID' })
		}

		const engineerData = await MetricService.getEngineerMetrics({
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
		const category = req.params.category

		if (typeof category !== 'string' || category.length === 0) {
			return res.status(400).json({ error: 'Invalid category' })
		}

		const categoryData = await MetricService.getCategoryMetrics({
			category,
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
 * Categories
 */
export const getCategoriesMetrics = async (req, res) => {
	try {
		const { timeframe = '24' } = req.query

		const categoriesData = await MetricService.getCategoriesMetrics({
			maxAgeHours: parseInt(timeframe),
		})

		res.json(categoriesData)
	} catch (error) {
		console.error('Dashboard data fetch error:', error)
		res.status(500).json({
			error: 'Failed to retrieve category metrics data',
		})
	}
}

//  AI Impact Summary
export const getAIImpactSummary = async (req, res) => {
	try {
		const aiimpactSummary = await MetricService.getAIImpactSummary({})

		res.json(aiimpactSummary)
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

/**
 * Get filter options
 */
export async function getFilterOptions(req, res) {
	try {
		const filterOptions = await MetricService.getFilterOptions()
		res.json(filterOptions)
	} catch (error) {
		console.error('Error in getFilterOptions:', error)
		res.status(500).json({ error: 'Failed to fetch all filter options' })
	}
}

const MetricController = {}
MetricController.getTeamMetrics = getTeamMetrics
MetricController.getProjectMetrics = getProjectMetrics
MetricController.calculateAIImpact = calculateAIImpact
MetricController.getAIImpactDashboard = getAIImpactDashboard
MetricController.getEngineerMetrics = getEngineerMetrics
MetricController.getCategoryMetrics = getCategoryMetrics
MetricController.getCategoriesMetrics = getCategoriesMetrics
MetricController.refreshAllMetrics = refreshAllMetrics
MetricController.getAIImpactSummary = getAIImpactSummary
MetricController.getFilterOptions = getFilterOptions

export default MetricController
