import { Op } from 'sequelize'
import { JiraIssue, Commit } from '../models/index.js'
import { daysBetween } from '../utils/dateUtils.js'

/**
 * Calculate cycle time for a specific issue
 *
 * Cycle time = time from first commit to issue resolution
 *
 * @param {number} issueId - The Jira issue ID
 * @returns {Object} - Cycle time information
 */
export async function getIssueCycleTime(issueId) {
	try {
		// Get the issue and its resolution date
		const issue = await JiraIssue.findByPk(issueId)
		if (!issue || !issue.resolution_date) {
			return {
				issueId,
				cycleTime: null,
				message: 'Issue not found or has not been resolved',
			}
		}

		// Get all commits for this issue, ordered by date
		const commits = await Commit.findAll({
			where: { jira_issue_id: issueId },
			order: [['commit_date', 'ASC']],
		})

		if (!commits || commits.length === 0) {
			return {
				issueId,
				cycleTime: null,
				message: 'No commits found for this issue',
			}
		}

		// Get the first commit date
		const firstCommitDate = commits[0].commit_date

		// Calculate cycle time (days between first commit and resolution)
		const cycleTime = daysBetween(firstCommitDate, issue.resolution_date)

		// Calculate AI usage metrics
		const aiCommits = commits.filter((commit) => commit.ai_used).length
		const nonAiCommits = commits.length - aiCommits
		const aiUsageRatio = commits.length > 0 ? aiCommits / commits.length : 0

		return {
			issueId,
			cycleTime,
			firstCommitDate,
			resolutionDate: issue.resolution_date,
			totalCommits: commits.length,
			aiCommits,
			nonAiCommits,
			aiUsageRatio,
		}
	} catch (error) {
		console.error(
			`Error calculating cycle time for issue ${issueId}:`,
			error,
		)
		throw error
	}
}

/**
 * Get cycle times for all resolved issues
 *
 * @returns {Array} - Array of issue cycle time data
 */
export async function getAllIssueCycleTimes() {
	try {
		// Get all resolved issues
		const resolvedIssues = await JiraIssue.findAll({
			where: {
				resolution_date: {
					[Op.not]: null,
				},
			},
		})

		// Calculate cycle time for each issue
		const cycleTimes = await Promise.all(
			resolvedIssues.map((issue) => getIssueCycleTime(issue.issue_id)),
		)

		return cycleTimes.filter((ct) => ct.cycleTime !== null)
	} catch (error) {
		console.error('Error fetching all issue cycle times:', error)
		throw error
	}
}

/**
 * Calculate average cycle time for a set of issues
 *
 * @param {Array} cycleTimes - Array of cycle time objects
 * @returns {number} - Average cycle time in days
 */
export async function calculateAverageCycleTime(cycleTimes) {
	if (!cycleTimes || cycleTimes.length === 0) return 0

	const sum = cycleTimes.reduce((total, ct) => total + ct.cycleTime, 0)
	return sum / cycleTimes.length
}

const CycleTimeService = {}
CycleTimeService.getIssueCycleTime = getIssueCycleTime
CycleTimeService.getAllIssueCycleTimes = getAllIssueCycleTimes
CycleTimeService.calculateAverageCycleTime = calculateAverageCycleTime

export default CycleTimeService
