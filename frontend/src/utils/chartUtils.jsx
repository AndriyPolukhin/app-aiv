// src/utils/chartUtils.js

/**
 * Group cycle time data by project and AI usage
 * @param {Array} data - Raw cycle time data array
 * @returns {Object} - Object containing grouped data
 */
export const groupCycleTimeData = (data) => {
	const categories = [...new Set(data.map((item) => item.category))]

	// Extract AI and non-AI data points
	const aiData = data.filter((item) => item.has_ai_commits)
	const nonAiData = data.filter((item) => !item.has_ai_commits)

	return {
		categories,
		aiData,
		nonAiData,
	}
}

/**
 * Format cycle time data for Chart.js bar chart
 * @param {Array} data - Raw cycle time data
 * @returns {Object} - Chart.js compatible dataset
 */
export const formatCycleTimeChartData = (data, filters = {}) => {
	const filteredData = data.filter((item) => {
		// If no filters are provided, include all data
		if (Object.keys(filters).length === 0) return true

		// Check each filter condition
		const teamMatch =
			!filters.teamId ||
			(item.team_ids && item.team_ids.includes(filters.teamId))
		const projectMatch =
			!filters.projectId || item.project_id === filters.projectId
		const engineerMatch =
			!filters.engineerId || item.author_id === filters.engineerId

		return teamMatch && projectMatch && engineerMatch
	})
	const { categories, aiData, nonAiData } = groupCycleTimeData(filteredData)

	// Map projects to average cycle times
	const getProjectCycleTimes = (dataset) => {
		return categories.map((category) => {
			const categoryData = dataset.find(
				(item) => item.category === category,
			)
			return categoryData ? categoryData.cycle_time : 0
		})
	}

	const aiCycleTimes = getProjectCycleTimes(aiData)
	const nonAiCycleTimes = getProjectCycleTimes(nonAiData)

	return {
		labels: categories,
		datasets: [
			{
				label: 'AI-Assisted',
				data: aiCycleTimes,
				backgroundColor: 'rgba(54, 162, 235, 0.6)',
				borderColor: 'rgba(54, 162, 235, 1)',
				borderWidth: 1,
			},
			{
				label: 'Non-AI',
				data: nonAiCycleTimes,
				backgroundColor: 'rgba(255, 99, 132, 0.6)',
				borderColor: 'rgba(255, 99, 132, 1)',
				borderWidth: 1,
			},
		],
	}
}

/**
 * Calculate improvement percentage between AI and non-AI cycle times
 * @param {Array} data - Raw cycle time data
 * @returns {Array} - Array of improvement metrics by project
 */
export const calculateImprovements = (data) => {
	const { projects, aiData, nonAiData } = groupCycleTimeData(data)

	return projects
		.map((project) => {
			const aiProject = aiData.find(
				(item) => item.project_name === project,
			)
			const nonAiProject = nonAiData.find(
				(item) => item.project_name === project,
			)

			if (aiProject && nonAiProject) {
				const aiTime = aiProject.avg_cycle_time_days
				const nonAiTime = nonAiProject.avg_cycle_time_days
				const improvement = ((nonAiTime - aiTime) / nonAiTime) * 100

				return {
					project,
					aiTime,
					nonAiTime,
					improvement: improvement.toFixed(2),
					aiIssueCount: aiProject.issue_count,
					nonAiIssueCount: nonAiProject.issue_count,
				}
			}

			return null
		})
		.filter(Boolean)
}

/**
 * Get color based on improvement percentage
 * @param {number} improvement - Percentage improvement
 * @returns {string} - CSS color value
 */
export const getImprovementColor = (improvement) => {
	// Red for negative, green for positive
	if (improvement < 0) {
		const intensity = Math.min(Math.abs(improvement) / 50, 1)
		return `rgba(255, 99, 132, ${intensity})`
	} else {
		const intensity = Math.min(improvement / 50, 1)
		return `rgba(75, 192, 192, ${intensity})`
	}
}
