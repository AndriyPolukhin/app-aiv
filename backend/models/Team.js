import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

/**
 * @swagger
 * components:
 * 	schemas:
 * 		Team:
 * 		  type: object
 * 		  required:
 * 			- team_name
 * 			- engineer_ids
 * 		  properties:
 * 			team_id:
 * 			  type: integer
 * 			  description: The auto-generated id of the team
 * 			  example: 1
 * 			team_name:
 * 			  type: string
 * 			  description: The name of the team
 * 			  example: "Backend development"
 * 			engineer_ids:
 * 			  type: array
 * 			  items:
 * 				type: integer
 * 			  description: Array of engineer IDs assigned to this team
 * 			  example: [101, 102, 103]
 */
export const Team = sequelize.define(
	ModelEnums.TEAM,
	{
		team_id: {
			type: DataTypes.INTEGER,
			primaryKey: true,
			autoIncrement: true,
			// allowNull: false,
		},
		team_name: {
			type: DataTypes.STRING,
			allowNull: false,
		},
		engineer_ids: {
			type: DataTypes.TEXT,
			allowNull: false,
			// Store as comma-separated list in DB, but parse as array when needed
			get() {
				const rawValue = this.getDataValue('engineer_ids')
				return rawValue
					? rawValue.split(',').map((id) => parseInt(id.trim()))
					: []
			},
			set(val) {
				if (Array.isArray(val)) {
					this.setDataValue('engineer_ids', val.join(','))
				} else {
					this.setDataValue('engineer_ids', val)
				}
			},
		},
	},
	{
		timestamps: false,
		tableName: 'teams',
	},
)
