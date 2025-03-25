/**
 * Calculate the number of days between two dates
 *
 * @param {Date|String} startDate - The start date
 * @param {Date|String} endDate - The end date
 * @returns {number} - Number of days between the dates (rounded to whole days)
 */

export function daysBetween(startDate, endDate) {
	const start = startDate instanceof Date ? startDate : new Date(startDate)
	const end = endDate instanceof Date ? endDate : new Date(endDate)

	// Convert to days (milliseconds to days)
	const daysDiff = Math.round((end - start) / (1000 * 60 * 60 * 24))
	return Math.max(0, daysDiff)
}

/**
 * Format a date to YYYY-MM-DD format
 *
 * @param {Date} date - The date to format
 * @returns {string} - Formatted date string
 */
export function formatDate(date) {
	return date.toISOString().split('T')[0]
}
