import UtilsServices from '../services/UtilsServices.js'

/**
 * Controller for handling  data-related API endpoints
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 */

/**
 * Get Team Data
 */
export async function getTeamsData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)

		const teamData = await UtilsServices.getTeamsData(filters)
		res.json(teamData)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch team data' })
	}
}

/**
 * Get Team Count of teams
 */
export async function getTeamsCount(req, res) {
	try {
		const teamCount = await UtilsServices.getTeamsCount()
		res.json(teamCount)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch team count' })
	}
}

/**
 * Get Jira Issues
 */
export async function getJiraIssuesData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)

		const jiraIssuesData = await UtilsServices.getJiraIssuesData(filters)
		res.json(jiraIssuesData)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch jira issues data' })
	}
}

/**
 * Get Jira Issues Count
 */
export async function getJiraIssuesCount(req, res) {
	try {
		const jiraIssuesCount = await UtilsServices.getJiraIssuesCount()
		res.json(jiraIssuesCount)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch jira issues count' })
	}
}

/**
 * Get Commits Data
 */
export async function getCommitsData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)
		const commitsData = await UtilsServices.getCommitsData(filters)
		res.json(commitsData)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch commits data' })
	}
}

/**
 * Get Commits Data Count
 */
export async function getCommitsCount(req, res) {
	try {
		const commitsCount = await UtilsServices.getCommitsCount()
		res.json(commitsCount)
	} catch (error) {
		console.error('Error in getTeamsData', error)
		res.status(500).json({ error: 'Failed to fetch commits count' })
	}
}

/**
 * Get Engineers Data
 */
export async function getEngineersData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)

		const engineersData = await UtilsServices.getEngineersData(filters)
		res.json(engineersData)
	} catch (error) {
		console.error('Error in getEngineersData', error)
		res.status(500).json({ error: 'Failed to fetch engineers data' })
	}
}
/**
 * Get Engineers Data Count
 */
export async function getEngineersCount(req, res) {
	try {
		const engineersCount = await UtilsServices.getEngineersCount()
		res.json(engineersCount)
	} catch (error) {
		console.error('Error in getEngineersCount', error)
		res.status(500).json({ error: 'Failed to fetch engineers count' })
	}
}

/**
 * Get Repositories Data
 *
 */
export async function getRepositoriesData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)

		const repositoriesData = await UtilsServices.getRepositoriesData(
			filters,
		)
		res.json(repositoriesData)
	} catch (error) {
		console.error('Error in getEngineersData', error)
		res.status(500).json({ error: 'Failed to fetch repositories data' })
	}
}

/**
 * Get Repositories Data Count
 *
 */
export async function getRepositoriesCount(req, res) {
	try {
		const repositoriesCount = await UtilsServices.getRepositoriesCount()
		res.json(repositoriesCount)
	} catch (error) {
		console.error('Error in getEngineersCount', error)
		res.status(500).json({ error: 'Failed to fetch repositories count' })
	}
}

/**
 * Get Projects Data
 */
export async function getProjectsData(req, res) {
	try {
		const filters = {}

		if (req.query.limit) filters.limit = parseInt(req.query.limit, 10)

		const projectsData = await UtilsServices.getProjectsData(filters)
		res.json(projectsData)
	} catch (error) {
		console.error('Error in getEngineersData', error)
		res.status(500).json({ error: 'Failed to fetch projects data' })
	}
}

/**
 * Get Projects Data Count
 */
export async function getProjectsCount(req, res) {
	try {
		const projectsCount = await UtilsServices.getProjectsCount()
		res.json(projectsCount)
	} catch (error) {
		console.error('Error in getEngineersCount', error)
		res.status(500).json({ error: 'Failed to fetch projects count' })
	}
}

const UtilsController = {
	/**
	 * @swagger
	 * tags:
	 * 	 name: Teams
	 * 	 description: Team management endpoints
	 */
}
UtilsController.getTeamsData = getTeamsData
UtilsController.getTeamsCount = getTeamsCount
UtilsController.getJiraIssuesData = getJiraIssuesData
UtilsController.getJiraIssuesCount = getJiraIssuesCount
UtilsController.getCommitsData = getCommitsData
UtilsController.getCommitsCount = getCommitsCount
UtilsController.getEngineersData = getEngineersData
UtilsController.getEngineersCount = getEngineersCount
UtilsController.getRepositoriesData = getRepositoriesData
UtilsController.getRepositoriesCount = getRepositoriesCount
UtilsController.getProjectsData = getProjectsData
UtilsController.getProjectsCount = getProjectsCount

export default UtilsController
