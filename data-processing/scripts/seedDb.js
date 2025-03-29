import fs from 'fs'
import path from 'path'
import { importCSV } from './utils/importCSV.js'
import { ModelEnums } from '../models/enums.js'
import {
	Team,
	Commit,
	Project,
	Engineer,
	JiraIssue,
	Repository,
} from '../models/index.js'

async function seedDatabase() {
	const modelOrder = [
		{
			model: Engineer,
			file: 'engineers.csv',
			modelName: ModelEnums.ENGINEER,
		},
		{ model: Team, file: 'teams.csv', modelName: ModelEnums.TEAM },
		{
			model: Project,
			file: 'projects.csv',
			modelName: ModelEnums.PROJECT,
		},
		{
			model: Repository,
			file: 'repositories.csv',
			modelName: ModelEnums.REPOSITORY,
		},
		{
			model: JiraIssue,
			file: 'jira_issues.csv',
			modelName: ModelEnums.JIRA_ISSUE,
		},
		{ model: Commit, file: 'commits.csv', modelName: ModelEnums.COMMIT },
	]

	for (const { model, file, modelName } of modelOrder) {
		const __dirname = path.dirname(new URL(import.meta.url).pathname)
		const filePath = path.join(__dirname, '..', 'data', file)

		if (!fs.existsSync(filePath)) {
			console.log(`Warning: File ${file} not found. Skipping.`)
			continue
		}

		console.log(`Processing ${file} for ${model.tableName}...`)

		try {
			// Import csv files into the database
			await importCSV(filePath, modelName)
		} catch (error) {
			console.error(`Error processing ${file}: ${error.message}`)
			process.exit(1)
		}
	}
}

seedDatabase()
	.then(() =>
		console.log('Finished processing all of the files into the database'),
	)
	.catch((error) => {
		console.error(`Unhandled error: ${error.message}`)
		process.exit(1)
	})
