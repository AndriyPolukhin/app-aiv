import AIImpactService from '../services/AIImpactService.js'
import CycleTimeService from '../services/CycleTimeService.js'

/**
 * Controller for handling metrics-related API endpoints
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */

/**
 * Get overall AI impact metrics
 *
 */
export async function getOverallMetrics(req, res) {
	try {
		const filters = {}

		// Apply optional filters from query params
		if (req.query.teamId) filters.teamId = parseInt(req.query.teamId, 10)
		if (req.query.engineerId)
			filters.engineerId = parseInt(req.query.engineerId, 10)
		if (req.query.projectId)
			filters.projectId = parseInt(req.query.projectId, 10)

		const metrics = await AIImpactService.calculateAIImpact(filters)
		res.json(metrics)
	} catch (error) {
		console.error('Error in getOverallMetrics:', error)
		res.status(500).json({ error: 'Failed to fetch overall metrics' })
	}
}

/**
 * Get team-based metrics
 *
 */
export async function getTeamMetrics(req, res) {
	try {
		const teamMetrics = await AIImpactService.getTeamMetrics()
		res.json(teamMetrics)
	} catch (error) {
		console.error('Error in getTeamMetrics:', error)
		res.status(500).json({ error: 'Failed to fetch team metrics' })
	}
}

/**
 * Get engineer-based metrics
 *
 */
export async function getEngineerMetrics(req, res) {
	try {
		const engineerMetrics = await AIImpactService.getEngineerMetrics()
		res.json(engineerMetrics)
	} catch (error) {
		console.error('Error in getEngineerMetrics:', error)
		res.status(500).json({ error: 'Failed to fetch engineer metrics' })
	}
}

/**
 * Get project-based metrics
 *
 */
export async function getProjectMetrics(req, res) {
	try {
		const projectMetrics = await AIImpactService.getProjectMetrics()
		res.json(projectMetrics)
	} catch (error) {
		console.error('Error in getProjectMetrics:', error)
		res.status(500).json({ error: 'Failed to fetch project metrics' })
	}
}

/**
 * Get timeline metrics for AI adoption and impact
 *
 */
export async function getTimelineMetrics(req, res) {
	try {
		const timelineData = await AIImpact.getTimelineMetrics()
		res.json(timelineData)
	} catch (error) {
		console.error('Error in getTimelineMetrics:', error)
		res.status(500).json({ error: 'Failed to fetch timeline metrics' })
	}
}

/**
 * Get cycle time for a specific issue
 *
 */
export async function getIssueCycleTime(req, res) {
	try {
		const issueId = parseInt(req.params.issueId, 10)
		if (isNaN(issueId)) {
			return res.status(400).json({ error: 'Invalid issue ID' })
		}

		const cycleTimeData = await CycleTimeService.getIssueCycleTime(issueId)
		res.json(cycleTimeData)
	} catch (error) {
		console.error(
			`Error in getIssueCycleTime for issue ${req.params.issueId}:`,
			error,
		)
		res.status(500).json({ error: 'Failed to fetch issue cycle time' })
	}
}

/**
 * Get cycle times for all issues
 *
 */
export async function getAllIssueCycleTimes(req, res) {
	try {
		const cycleTimeData = await CycleTimeService.getAllIssueCycleTimes()
		res.json(cycleTimeData)
	} catch (error) {
		console.error('Error in getAllIssueCycleTimes:', error)
		res.status(500).json({ error: 'Failed to fetch all issue cycle times' })
	}
}

const AIImpactController = {}
AIImpactController.getOverallMetrics = getOverallMetrics
AIImpactController.getTeamMetrics = getTeamMetrics
AIImpactController.getEngineerMetrics = getEngineerMetrics
AIImpactController.getProjectMetrics = getProjectMetrics
AIImpactController.getTimelineMetrics = getTimelineMetrics
AIImpactController.getIssueCycleTime = getIssueCycleTime
AIImpactController.getAllIssueCycleTimes = getAllIssueCycleTimes

export default AIImpactController
