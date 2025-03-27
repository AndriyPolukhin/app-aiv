import React from 'react'
import FilterPanel from './FilterPanel'
import CycleTimeChart from './CycleTimeChart'
import ImprovementCard from './ImprovementCard'

const Dashboard = () => {
	return (
		<div className='dashboard'>
			<div className='dashboard-header'>
				<h2>AI Impact on Development Cycle Time</h2>
				<p className='dashboard-description'>
					This dashboard visualizes the impact of AI-assisted
					development on issue cycle time, defined as the time from
					first commit to issue resolution.
				</p>
			</div>

			<div className='dashboard-content'>
				<div className='dashboard-sidebar'>
					<FilterPanel />
					<ImprovementCard />
				</div>

				<div className='dashboard-main'>
					<CycleTimeChart />

					<div className='dashboard-insights'>
						<h3>Key Insights</h3>
						<ul>
							<li>
								<strong>Cycle Time Comparison:</strong> Compare
								the average time to complete issues with and
								without AI assistance across different projects.
							</li>
							<li>
								<strong>Productivity Metrics:</strong> Analyze
								the percentage improvement in cycle time when AI
								tools are utilized during development.
							</li>
							<li>
								<strong>Team Performance:</strong> Evaluate how
								different teams leverage AI to improve their
								development efficiency.
							</li>
							<li>
								<strong>Engineer Impact:</strong> Identify
								individual engineers who show the greatest
								improvements when utilizing AI assistance.
							</li>
						</ul>
					</div>

					<div className='methodology-section'>
						<h3>Methodology</h3>
						<p>
							This analysis compares the cycle time for issues
							where AI assistance was used (determined by commit
							metadata) versus issues completed without AI
							assistance. Cycle time is measured from the first
							commit associated with an issue to the issue's
							resolution date in Jira.
						</p>
					</div>
				</div>
			</div>
		</div>
	)
}

export default Dashboard
