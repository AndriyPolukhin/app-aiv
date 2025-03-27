// src/contexts/FilterContext.js
import React, { createContext, useContext, useState, useEffect } from 'react'
import { apiService } from '../services/api'

// Create context
const FilterContext = createContext()

/**
 * Provider component for filter state management
 * Handles loading filter options and maintaining selected filter state
 */
export const FilterProvider = ({ children }) => {
	// State for filter options and selections
	const [filterOptions, setFilterOptions] = useState({
		teams: [],
		projects: [],
		engineers: [],
	})
	const [selectedFilters, setSelectedFilters] = useState({
		teamId: null,
		projectId: null,
		engineerId: null,
	})
	const [loading, setLoading] = useState(true)
	const [error, setError] = useState(null)

	// Load filter options on component mount
	useEffect(() => {
		const loadFilterOptions = async () => {
			try {
				setLoading(true)
				const options = await apiService.getFilterOptions()
				setFilterOptions(options)
				setError(null)
			} catch (err) {
				setError(
					'Failed to load filter options. Please try again later.',
				)
				console.error('Error loading filter options:', err)
			} finally {
				setLoading(false)
			}
		}

		loadFilterOptions()
	}, [])

	/**
	 * Update a specific filter
	 * @param {string} filterName - Name of the filter to update (teamId, projectId, engineerId)
	 * @param {number|null} value - New filter value
	 */
	const updateFilter = (filterName, value) => {
		setSelectedFilters((prev) => ({
			...prev,
			[filterName]: value,
		}))
	}

	/**
	 * Reset all filters to null
	 */
	const resetFilters = () => {
		setSelectedFilters({
			teamId: null,
			projectId: null,
			engineerId: null,
		})
	}

	// Context value to be provided
	const contextValue = {
		filterOptions,
		selectedFilters,
		loading,
		error,
		updateFilter,
		resetFilters,
	}

	return (
		<FilterContext.Provider value={contextValue}>
			{children}
		</FilterContext.Provider>
	)
}

// Custom hook for using filter context
export const useFilters = () => {
	const context = useContext(FilterContext)
	if (!context) {
		throw new Error('useFilters must be used within a FilterProvider')
	}
	return context
}

export default FilterContext
