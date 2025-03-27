import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import FilterPanel from '../FilterPanel'
import { FilterProvider } from '../../contexts/FilterContext'

describe('FilterPanel Component', () => {
	test('renders filter options and handles selection', () => {
		// Mock the filter options context
		const mockFilterOptions = {
			teams: [
				{ id: 1, name: 'Team A' },
				{ id: 2, name: 'Team B' },
			],
			projects: [
				{ id: 1, name: 'Project X' },
				{ id: 2, name: 'Project Y' },
			],
			engineers: [
				{ id: 1, name: 'Engineer 1' },
				{ id: 2, name: 'Engineer 2' },
			],
		}

		// Mock the context value
		jest.mock('../../contexts/FilterContext', () => ({
			useFilters: () => ({
				filterOptions: mockFilterOptions,
				selectedFilters: {
					teamId: null,
					projectId: null,
					engineerId: null,
				},
				updateFilter: jest.fn(),
				resetFilters: jest.fn(),
				loading: false,
			}),
		}))

		render(
			<FilterProvider>
				<FilterPanel />
			</FilterProvider>,
		)

		// Verify filter labels
		expect(screen.getByText(/Team:/i)).toBeInTheDocument()
		expect(screen.getByText(/Project:/i)).toBeInTheDocument()
		expect(screen.getByText(/Engineer:/i)).toBeInTheDocument()

		// Verify reset button exists
		expect(screen.getByText(/Reset Filters/i)).toBeInTheDocument()
	})
})
