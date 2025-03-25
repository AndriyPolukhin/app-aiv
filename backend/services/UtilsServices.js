import { QueryTypes } from 'sequelize'
import { sequelize } from '../config/db.js'

/**
 * Get the total count of rows in a table
 *
 * @param {string} tableName - Name of the table
 * @returns {number} - Total count of rows
 */
export async function getTotalCount(tableName) {
	const query = `SELECT COUNT(*) FROM ${tableName};`
	const results = await sequelize.query(query, { type: QueryTypes.SELECT })
	return results[0].count
}

/**
 * Get the entries from a table
 *
 * @param {string} tableName - Name of the table
 * @returns {Array} -  rows
 */
export async function getEntries(tableName, limit = 5) {
	if (typeof limit !== 'number' || limit <= 0) {
		throw new Error('Limit must be a positive number')
	}
	const query = `SELECT * FROM ${tableName} LIMIT :limit;`
	const results = await sequelize.query(query, {
		replacements: { limit },
		type: QueryTypes.SELECT,
	})
	return results
}

/**
 * Get the total count of commits
 *
 * @returns {number} - Total count of commits
 */
export async function getCommitsCount() {
	return await getTotalCount('commits')
}

/**
 * Get the  commits
 *
 * @param {number} limit - Number of rows to retrieve
 * @returns {Array} - commits
 */
export async function getCommitsData({ limit = 5 }) {
	return await getEntries('commits', limit)
}

/**
 * Get the total count of jira_issues
 *
 * @returns {number} - Total count of jira_issues
 */
export async function getJiraIssuesCount() {
	return await getTotalCount('jira_issues')
}

/**
 * Get the  jira_issues
 *
 * @param {number} limit - Number of rows to retrieve
 * @returns {Array} -  jira_issues
 */
export async function getJiraIssuesData({ limit = 5 }) {
	return await getEntries('jira_issues', limit)
}

/**
 * Get the total count of teams
 *
 * @returns {number} - Total count of teams
 */
export async function getTeamsCount() {
	return await getTotalCount('teams')
}

/**
 * Get the  teams
 *
 * @param {number} limit - Number of rows to retrieve
 * @returns {Array} -  teams
 */
export async function getTeamsData({ limit = 5 }) {
	return await getEntries('teams', limit)
}

/**
 * Get the projects count
 *
 * @returns {number} - Total count of projects
 */
export async function getProjectsCount() {
	return await getTotalCount('projects')
}

/**
 * Get the projects
 *
 * @param {number} limit - Number of rows to retrieve
 * @returns {Array} - projects
 */
export async function getProjectsData({ limit = 5 }) {
	return await getEntries('projects', limit)
}

/**
 * Get the projects count
 *
 * @returns {number} - Total count of repositories
 */
export async function getRepositoriesCount() {
	return await getTotalCount('repositories')
}

/**
 * Get the repositories
 *
 * @param {number} limit - Number of rows to repositories
 * @returns {Array} - repositories
 */
export async function getRepositoriesData({ limit = 5 }) {
	return await getEntries('repositories', limit)
}

/**
 * Get the Engineers count
 *
 * @returns {number} - Total count of engineers
 */
export async function getEngineersCount() {
	return await getTotalCount('engineers')
}

/**
 * Get the engineers
 *
 * @param {number} limit - Number of rows to engineers
 * @returns {Array} - engineers
 */
export async function getEngineersData({ limit = 5 }) {
	return await getEntries('engineers', limit)
}

const UtilsServices = {}
UtilsServices.getCommitsCount = getCommitsCount
UtilsServices.getCommitsData = getCommitsData
UtilsServices.getJiraIssuesCount = getJiraIssuesCount
UtilsServices.getJiraIssuesData = getJiraIssuesData
UtilsServices.getTeamsCount = getTeamsCount
UtilsServices.getTeamsData = getTeamsData
UtilsServices.getProjectsCount = getProjectsCount
UtilsServices.getProjectsData = getProjectsData
UtilsServices.getRepositoriesCount = getRepositoriesCount
UtilsServices.getRepositoriesData = getRepositoriesData
UtilsServices.getEngineersCount = getEngineersCount
UtilsServices.getEngineersData = getEngineersData

export default UtilsServices
