import React from 'react'
import { render, screen } from '@testing-library/react'
import Dashboard from '../Dashboard'
import { FilterProvider } from '../../contexts/FilterContext'

// Mock the child components
jest.mock('../FilterPanel', () => () => (
	<div data-testid='filter-panel'>Filter Panel</div>
))
jest.mock('../CycleTimeChart', () => () => (
	<div data-testid='cycle-time-chart'>Chart</div>
))
jest.mock('../ImprovementCard', () => () => (
	<div data-testid='improvement-card'>Improvement</div>
))

describe('Dashboard Component', () => {
	test('renders dashboard with all sub-components', () => {
		render(
			<FilterProvider>
				<Dashboard />
			</FilterProvider>,
		)

		// Header content
		expect(
			screen.getByText(/AI Impact on Development Cycle Time/i),
		).toBeInTheDocument()

		// Child components
		expect(screen.getByTestId('filter-panel')).toBeInTheDocument()
		expect(screen.getByTestId('cycle-time-chart')).toBeInTheDocument()
		expect(screen.getByTestId('improvement-card')).toBeInTheDocument()

		// Insights section
		expect(screen.getByText(/Key Insights/i)).toBeInTheDocument()
		expect(screen.getByText(/Cycle Time Comparison/i)).toBeInTheDocument()

		// Methodology section
		expect(screen.getByText(/Methodology/i)).toBeInTheDocument()
	})
})
