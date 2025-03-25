import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

export const JiraIssue = sequelize.define(
	ModelEnums.JIRA_ISSUE,
	{
		issue_id: {
			type: DataTypes.INTEGER,
			primaryKey: true,
			autoIncrement: true,
			// allowNull: false,
		},
		project_id: {
			type: DataTypes.INTEGER,
			allowNull: false,
			references: {
				model: 'projects',
				key: 'project_id',
			},
		},
		author_id: {
			type: DataTypes.INTEGER,
			allowNull: false,
			references: {
				model: 'engineers',
				key: 'id',
			},
		},
		creation_date: {
			type: DataTypes.DATEONLY,
			allowNull: false,
		},
		resolution_date: {
			type: DataTypes.DATEONLY,
			allowNull: true,
		},
		category: {
			type: DataTypes.STRING,
			allowNull: false,
		},
	},
	{
		timestamps: false,
		tableName: 'jira_issues',
	},
)
