// src/components/ImprovementCard.js
import React, { useEffect, useState } from 'react'
import { useFilters } from '../contexts/FilterContext'
import { apiService } from '../services/api'
import { getImprovementColor } from '../utils/chartUtils'

const ImprovementCard = () => {
	// Get filters from context
	const { selectedFilters } = useFilters()

	// Component state
	const [improvements, setImprovements] = useState([])
	const [loading, setLoading] = useState(true)
	const [error, setError] = useState(null)
	const [overallImprovement, setOverallImprovement] = useState({
		percentage: 0,
		totalAiIssues: 0,
		totalNonAiIssues: 0,
	})

	// Fetch improvement data when filters change. To be implemented.
	// useEffect(() => {
	// 	const fetchImprovements = async () => {
	// 		try {
	// 			setLoading(true)

	// 			// Convert filters to API format
	// 			const apiFilters = {
	// 				teamId: selectedFilters.teamId,
	// 				projectId: selectedFilters.projectId,
	// 				engineerId: selectedFilters.engineerId,
	// 			}

	// 			// Fetch improvement metrics, to be calculated.
	// 			const data = await apiService.getImprovementMetrics(apiFilters)
	// 			setImprovements(data)

	// 			// Calculate overall improvement
	// 			if (data.length > 0) {
	// 				// Weighted average of improvement percentages
	// 				let totalWeight = 0
	// 				let weightedSum = 0
	// 				let totalAiIssues = 0
	// 				let totalNonAiIssues = 0

	// 				data.forEach((item) => {
	// 					const weight =
	// 						item.ai_issue_count + item.non_ai_issue_count
	// 					weightedSum += item.improvement_percentage * weight
	// 					totalWeight += weight
	// 					totalAiIssues += item.ai_issue_count
	// 					totalNonAiIssues += item.non_ai_issue_count
	// 				})

	// 				const avgImprovement =
	// 					totalWeight > 0 ? weightedSum / totalWeight : 0

	// 				setOverallImprovement({
	// 					percentage: avgImprovement.toFixed(2),
	// 					totalAiIssues,
	// 					totalNonAiIssues,
	// 				})
	// 			} else {
	// 				setOverallImprovement({
	// 					percentage: 0,
	// 					totalAiIssues: 0,
	// 					totalNonAiIssues: 0,
	// 				})
	// 			}

	// 			setError(null)
	// 		} catch (err) {
	// 			setError(
	// 				'Failed to load improvement data. Please try again later.',
	// 			)
	// 			console.error('Error loading improvement data:', err)
	// 		} finally {
	// 			setLoading(false)
	// 		}
	// 	}

	// 	fetchImprovements()
	// }, [selectedFilters])

	if (loading) {
		return (
			<div className='improvement-card loading'>
				Loading improvement data...
			</div>
		)
	}

	if (error) {
		return <div className='improvement-card error'>{error}</div>
	}

	if (improvements.length === 0) {
		return (
			<div className='improvement-card empty'>
				No improvement data available for the selected filters.
			</div>
		)
	}

	// Determine improvement status message
	const getImprovementStatus = (percentage) => {
		if (percentage > 20) return 'Significant Improvement'
		if (percentage > 0) return 'Moderate Improvement'
		if (percentage === 0) return 'No Impact'
		return 'Negative Impact'
	}

	return (
		<div className='improvement-card'>
			<div className='overall-improvement'>
				<h3>Overall AI Impact</h3>
				<div
					className='improvement-value'
					style={{
						color: getImprovementColor(
							parseFloat(overallImprovement.percentage),
						),
					}}
				>
					{overallImprovement.percentage > 0 ? '+' : ''}
					{overallImprovement.percentage}%
				</div>
				<div className='improvement-status'>
					{getImprovementStatus(
						parseFloat(overallImprovement.percentage),
					)}
				</div>
				<div className='issue-counts'>
					<div>
						AI-Assisted Issues: {overallImprovement.totalAiIssues}
					</div>
					<div>
						Non-AI Issues: {overallImprovement.totalNonAiIssues}
					</div>
				</div>
			</div>

			<div className='project-improvements'>
				<h4>Project Breakdown</h4>
				{improvements.map((item, index) => (
					<div key={index} className='project-improvement-item'>
						<div className='project-name'>{item.project_name}</div>
						<div
							className='project-improvement-value'
							style={{
								color: getImprovementColor(
									item.improvement_percentage,
								),
							}}
						>
							{item.improvement_percentage > 0 ? '+' : ''}
							{item.improvement_percentage}%
						</div>
						<div className='project-cycle-times'>
							<span>
								AI: {item.ai_cycle_time.toFixed(1)} days
							</span>
							<span>
								Non-AI: {item.non_ai_cycle_time.toFixed(1)} days
							</span>
						</div>
					</div>
				))}
			</div>
		</div>
	)
}

export default ImprovementCard
