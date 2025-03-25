import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

export const Commit = sequelize.define(
	ModelEnums.COMMIT,
	{
		commit_id: {
			type: DataTypes.STRING,
			primaryKey: true,
		},
		engineer_id: {
			type: DataTypes.INTEGER,
			allowNull: false,
			references: {
				model: 'engineers',
				key: 'id',
			},
		},
		jira_issue_id: {
			type: DataTypes.INTEGER,
			allowNull: false,
			references: {
				model: 'jira_issues',
				key: 'issue_id',
			},
		},
		repo_id: {
			type: DataTypes.INTEGER,
			allowNull: false,
			references: {
				model: 'repositories',
				key: 'repo_id',
			},
		},
		commit_date: {
			type: DataTypes.DATEONLY,
			allowNull: false,
		},
		ai_used: {
			type: DataTypes.BOOLEAN,
			allowNull: false,
		},
		lines_of_code: {
			type: DataTypes.INTEGER,
			allowNull: false,
		},
	},
	{ timestamps: false, tableName: 'commits' },
)
