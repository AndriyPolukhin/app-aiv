import { QueryTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { Team, Project, Engineer } from '../models/index.js'

/**
 * Calculate the impact of AI on cycle time
 *
 * @param {Object} filters - Optional filters (team, engineer, project)
 * @returns {Object} - AI impact metrics
 */
export async function calculateAIImpact(filters = {}) {
	const results = await sequelize.query(
		'SELECT * FROM calculate_ai_impact(:projectId, :authorId, :engineerId, :teamId);',
		{
			replacements: {
				projectId: filters.projectId || null,
				authorId: filters.authorId || null,
				engineerId: filters.engineerId || null,
				teamId: filters.teamId || null,
			},
			type: QueryTypes.SELECT,
		},
	)
	return results[0] // Return the first row of results
}

//  Calculation based level of Impact: Team, Engineer, Project
/**
 * Get team-based AI impact metrics
 *
 * @returns {Array} - Team metrics array
 */
export async function getTeamMetrics() {
	const results = await sequelize.query('SELECT * FROM get_team_metrics();', {
		type: QueryTypes.SELECT,
	})
	return results
}

/**
 * Get engineer-based AI impact metrics
 *
 * @returns {Array} - Engineer metrics array
 */
export async function getEngineerMetrics() {
	const results = await sequelize.query(
		'SELECT * FROM get_engineer_metrics();',
		{
			type: QueryTypes.SELECT,
		},
	)
	return results
}

/**
 * Get project-based AI impact metrics
 *
 * @returns {Array} - Project metrics array
 */
export async function getProjectMetrics() {
	const results = await sequelize.query(
		'SELECT * FROM get_project_metrics();',
		{
			type: QueryTypes.SELECT,
		},
	)
	return results
}

/**
 * Get timeline data showing AI adoption and impact over time
 *
 * @returns {Object} - Timeline metrics
 */
export async function getTimelineMetrics() {
	const results = await sequelize.query(
		'SELECT * FROM timeline_metrics_materialized;',
		{
			type: QueryTypes.SELECT,
		},
	)
	return results
}

const AIImpactService = {}
AIImpactService.calculateAIImpact = calculateAIImpact
AIImpactService.getTeamMetrics = getTeamMetrics
AIImpactService.getEngineerMetrics = getEngineerMetrics
AIImpactService.getProjectMetrics = getProjectMetrics
AIImpactService.getTimelineMetrics = getTimelineMetrics

export default AIImpactService
