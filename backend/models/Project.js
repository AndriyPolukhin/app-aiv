import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

export const Project = sequelize.define(
	ModelEnums.PROJECT,
	{
		project_id: {
			type: DataTypes.INTEGER,
			primaryKey: true,
			autoIncrement: true,
			// allowNull: false,
		},
		project_name: {
			type: DataTypes.STRING,
			allowNull: false,
		},
	},
	{
		timestamp: false,
		tableName: 'projects',
	},
)
