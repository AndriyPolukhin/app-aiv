import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

export const Engineer = sequelize.define(
	ModelEnums.ENGINEER,
	{
		id: {
			type: DataTypes.INTEGER,
			primaryKey: true,
			autoIncrement: true,
			// allowNull: false,
		},
		name: {
			type: DataTypes.STRING,
			allowNull: false,
		},
	},
	{
		timestamps: false,
		tableName: 'engineers',
	},
)
