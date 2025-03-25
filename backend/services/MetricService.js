import { QueryTypes } from 'sequelize'
import { sequelize } from '../config/db.js'

/**
 * Calculate AI Impact using dynamic or materialized data
 *  @param {Object} filters - Filter parameters
 *  @param {Object} options - Query options
 *  @returns {Promise<Object>} - Impact metrics
 */
export const calculateAIImpact = async (filters = {}, options = {}) => {
	const { maxAgeHours = 24, forceRefresh = false } = options

	// Check if we can use cross-dimensional materialized data
	if (canUseCrossDimensionalData(filters)) {
		const dimensionMapping = mapFiltersDimension(filters)
		if (dimensionMapping) {
			const [result] = await sequelize.query(
				'SELECT get_cross_dimensional_metrics(:dimensionType, :primaryId, :secondaryId, :maxAgeHours, :forceRefresh)',
				{
					type: QueryTypes.SELECT,
					replacements: {
						dimensionType: dimensionMapping.dimensionType,
						primaryId: dimensionMapping.primaryId,
						secondaryId: dimensionMapping.secondaryId,
						maxAgeHours,
						forceRefresh,
					},
				},
			)
			return result
		}
	}

	// Fall back to dynamic calculation if no materialized data available
	const [result] = await sequelize.query(
		'SELECT calculate_ai_impact(:projectId, :authorId, :engineerId, :teamId)',
		{
			type: QueryTypes.SELECT,
			replacements: {
				projectId: filters.projectId || null,
				authorId: filters.authorId || null,
				engineerId: filters.engineerId || null,
				teamId: filters.teamId || null,
			},
		},
	)
	return result
}
/**
 * Get team-based AI impact metrics
 * @param {Object} options - Query options
 * @returns {Promise<Array>} - Team metrics array
 */
export const getTeamMetrics = async (options = {}) => {
	const { maxAgeHours = 24, forceRefresh = false, teamId = null } = options

	return sequelize.query(
		'SELECT get_team_metrics_optimized(:maxAgeHours, :forceRefresh, :teamId)',
		{
			type: QueryTypes.SELECT,
			replacements: { maxAgeHours, forceRefresh, teamId },
		},
	)
}

/**
 * Get engineer-based IA impact metrics
 * @param {Object} options - Query options
 * @returns {Promise<Array>} - Engineer metrics array
 */
export const getEngineerMetrics = async (options = {}) => {
	const {
		maxAgeHours = 24,
		forceRefresh = false,
		engineerId = null,
	} = options

	return sequelize.query(
		'SELECT get_engineer_metrics_optimized(:maxAgeHours, :forceRefresh, :engineerId)',
		{
			type: QueryTypes.SELECT,
			replacements: { maxAgeHours, forceRefresh, engineerId },
		},
	)
}

/**
 * Get project-based AI impact metrics
 * @param {Object} options - Query options
 * @returns {Promise<Array>} - Project metrics array
 */
export const getProjectMetrics = async (options = {}) => {
	const { maxAgeHours = 24, forceRefresh = false, projectId = null } = options

	return sequelize.query(
		'SELECT get_project_metrics_optimized(:maxAgeHours, :forceRefresh, :projectId)',
		{
			type: QueryTypes.SELECT,
			replacements: { maxAgeHours, forceRefresh, projectId },
		},
	)
}

/**
 * Get timeline data showing AI adoption and impact over time
 * @param {Object} timeOptions - Time period options
 * @param {Object} queryOptions - Query options
 * @returns {Promise<Array>} - Timeline metrics
 */
export const getTimelineMetrics = async (
	timeOptions = {},
	queryOptions = {},
) => {
	const { startDate = null, endDate = null, interval = 'month' } = timeOptions

	const { maxAgeHours = 24, forceRefresh = false } = queryOptions

	const [result] = await sequelize.query(
		'SELECT get_timeline_metrics(:startDate, :endDate, :interval, :maxAgeHours, :forceRefresh)',
		{
			type: QueryTypes.SELECT,
			replacements: {
				startDate,
				endDate,
				interval,
				maxAgeHours,
				forceRefresh,
			},
		},
	)
	return result
}

/**
 * Get metrics for a specific category
 * @param {String} category - Category name
 * @param {Object} options - Query options
 * @returns {Promise<Array>} - Category metrics
 */
export const getCategoryMetrics = async (category, options = {}) => {
	const { maxAgeHours = 24, forceRefresh = false } = options

	return sequelize.query(
		'SELECT get_category_metrics(:maxAgeHours, :forceRefresh, :category)',
		{
			type: QueryTypes.SELECT,
			replacements: { maxAgeHours, forceRefresh, category },
		},
	)
}

/**
 * Get cross-dimensional metrics (team-project, engineer-category etc.)
 * @param {String} dimensionType - Type of dimensional relationship
 * @param {Number} primaryId - Primary dimension ID
 * @param {Number} secondaryId - Secondary dimension ID
 * @param {Object} options - Query options
 * @returns {Promise<Object>} - Cross-dimensional metrics
 */
export const getCrossDimensionalMetrics = async (
	dimensionType,
	primaryId,
	secondaryId,
	options = {},
) => {
	const { maxAgeHours = 24, forceRefresh = false } = options

	const [result] = await sequelize.query(
		'SELECT get_cross_dimensional_metrics(:dimensionType, :primaryId, :secondaryId, :maxAgeHours, :forceRefresh)',
		{
			type: QueryTypes.SELECT,
			replacements: {
				dimensionType,
				primaryId,
				secondaryId,
				maxAgeHours,
				forceRefresh,
			},
		},
	)

	return result
}

/**
 * Force refresh of all materialized metrics
 * @param {Boolean} fullRefresh - Whether to perform a complete refresh
 * @returns {Promise<void>}
 */
export const refreshAllMetrics = async (fullRefresh = false) => {
	await sequelize.query('SELECT refresh_all_metrics(:fullRefresh)', {
		type: QueryTypes.SELECT,
		replacements: { fullRefresh },
	})
}

/**
 * Check if we can use cross-dimensional data for the provided filters
 * @param {Object} filters - Filter parameters
 * @returns {Boolean} - Whether cross-dimensional data can be used
 */
export const canUseCrossDimensionalData = (filters) => {
	// Count defined filters
	const definedFilters = Object.entries(filters)
		.filter(([_, value]) => value !== null && value !== undefined)
		.map(([key, _]) => key)

	// We can use cross-dimensional data if exactly two dimensions are specified
	return definedFilters.length === 2
}

/**
 * Map filters to dimension type and IDs
 * @param {Object} filters - Filter parameters
 * @returns {Object|null} - Dimension mapping or null if not mappable
 */
export const mapFiltersDimension = (filters) => {
	if (filters.teamId && filters.projectId) {
		return {
			dimensionType: 'team-project',
			primaryId: filters.teamId,
			secondaryId: filters.projectId,
		}
	} else if (filters.engineerId && filters.projectId) {
		return {
			dimensionType: 'engineer-project',
			primaryId: filters.engineerId,
			secondaryId: filters.projectId,
		}
	} else if (filters.authorId && filters.projectId) {
		return {
			dimensionType: 'author-project',
			primaryId: filters.authorId,
			secondaryId: filters.projectId,
		}
	} else if (filters.teamId && filters.engineerId) {
		return {
			dimensionType: 'team-engineer',
			primaryId: filters.teamId,
			secondaryId: filters.engineerId,
		}
	}
	// No valid mapping found
	return null
}

const MetricService = {}
MetricService.calculateAIImpact = calculateAIImpact
MetricService.getTeamMetrics = getTeamMetrics
MetricService.getEngineerMetrics = getEngineerMetrics
MetricService.getProjectMetrics = getProjectMetrics
MetricService.getTimelineMetrics = getTimelineMetrics
MetricService.getCategoryMetrics = getCategoryMetrics
MetricService.refreshAllMetrics = refreshAllMetrics
MetricService.getCrossDimensionalMetrics = getCrossDimensionalMetrics

export default MetricService
