import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

export const Repository = sequelize.define(
	ModelEnums.REPOSITORY,
	{
		repo_id: {
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
		repo_name: {
			type: DataTypes.STRING,
			allowNull: false,
		},
	},
	{
		timestamps: false,
		tableName: 'repositories',
	},
)
