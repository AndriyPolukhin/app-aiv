// src/components/FilterPanel.js
import React from 'react'
import { useFilters } from '../contexts/FilterContext'

const FilterPanel = () => {
	const {
		filterOptions,
		selectedFilters,
		updateFilter,
		resetFilters,
		loading,
	} = useFilters()

	const handleFilterChange = (e) => {
		const { name, value } = e.target
		// Convert value to number or null
		const numValue = value ? parseInt(value, 10) : null
		updateFilter(name, numValue)
	}

	// If still loading filter options, show loading state
	if (loading) {
		return (
			<div className='filter-panel loading'>
				<h3>Filters</h3>
				<p>Loading filters...</p>
			</div>
		)
	}

	return (
		<div className='filter-panel'>
			<h3>Filters</h3>

			<div className='filter-group'>
				<label htmlFor='teamId'>Team:</label>
				<select
					id='teamId'
					name='teamId'
					value={selectedFilters.teamId || ''}
					onChange={handleFilterChange}
				>
					<option value=''>All Teams</option>
					{filterOptions.teams.map((team) => (
						<option key={team.id} value={team.id}>
							{team.name}
						</option>
					))}
				</select>
			</div>

			<div className='filter-group'>
				<label htmlFor='projectId'>Project:</label>
				<select
					id='projectId'
					name='projectId'
					value={selectedFilters.projectId || ''}
					onChange={handleFilterChange}
				>
					<option value=''>All Projects</option>
					{filterOptions.projects.map((project) => (
						<option key={project.id} value={project.id}>
							{project.name}
						</option>
					))}
				</select>
			</div>

			<div className='filter-group'>
				<label htmlFor='engineerId'>Engineer:</label>
				<select
					id='engineerId'
					name='engineerId'
					value={selectedFilters.engineerId || ''}
					onChange={handleFilterChange}
				>
					<option value=''>All Engineers</option>
					{filterOptions.engineers.map((engineer) => (
						<option key={engineer.id} value={engineer.id}>
							{engineer.name}
						</option>
					))}
				</select>
			</div>

			<button className='reset-button' onClick={resetFilters}>
				Reset Filters
			</button>
		</div>
	)
}

export default FilterPanel
