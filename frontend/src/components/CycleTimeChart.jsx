// src/components/CycleTimeChart.js
import React, { useEffect, useState } from 'react'
import { Bar } from 'react-chartjs-2'
import {
	Chart as ChartJS,
	CategoryScale,
	LinearScale,
	BarElement,
	Title,
	Tooltip,
	Legend,
} from 'chart.js'
import { useFilters } from '../contexts/FilterContext'
import { apiService } from '../services/api'
import { formatCycleTimeChartData } from '../utils/chartUtils'

// Register Chart.js components
ChartJS.register(CategoryScale, LinearScale, BarElement, Title, Tooltip, Legend)

const CycleTimeChart = () => {
	// Get filters from context
	const { selectedFilters } = useFilters()

	// Component state
	const [chartData, setChartData] = useState(null)
	const [loading, setLoading] = useState(true)
	const [error, setError] = useState(null)

	// Chart options configuration
	const options = {
		responsive: true,
		maintainAspectRatio: false,
		plugins: {
			legend: {
				position: 'top',
			},
			title: {
				display: true,
				text: 'Average Cycle Time by Category (Days)',
				font: {
					size: 16,
				},
			},
			tooltip: {
				callbacks: {
					label: function (context) {
						return `${context.dataset.label}: ${context.raw.toFixed(
							1,
						)} days`
					},
				},
			},
		},
		scales: {
			x: {
				title: {
					display: true,
					text: 'Projects',
				},
			},
			y: {
				title: {
					display: true,
					text: 'Average Cycle Time (Days)',
				},
				beginAtZero: true,
			},
		},
	}

	// Fetch data whenever filters change
	useEffect(() => {
		const fetchData = async () => {
			try {
				setLoading(true)

				// Convert filters to API format
				const apiFilters = {
					teamId: selectedFilters.teamId,
					projectId: selectedFilters.projectId,
					engineerId: selectedFilters.engineerId,
				}

				// Fetch cycle time metrics
				const response = await apiService.getAIImpactSummary(apiFilters)

				// Format data for chart, filters the data here for now
				const formattedData = formatCycleTimeChartData(
					response,
					apiFilters,
				)
				setChartData(formattedData)
				setError(null)
			} catch (err) {
				setError('Failed to load chart data. Please try again later.')
				console.error('Error loading chart data:', err)
			} finally {
				setLoading(false)
			}
		}

		fetchData()
	}, [selectedFilters])

	if (loading) {
		return (
			<div className='chart-container loading'>Loading chart data...</div>
		)
	}

	if (error) {
		return <div className='chart-container error'>{error}</div>
	}

	if (!chartData || chartData.labels.length === 0) {
		return (
			<div className='chart-container empty'>
				No data available for the selected filters.
			</div>
		)
	}

	return (
		<div className='chart-container'>
			<Bar data={chartData} options={options} height={300} />
		</div>
	)
}

export default CycleTimeChart
