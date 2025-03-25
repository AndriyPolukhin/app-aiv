import { DataTypes } from 'sequelize'
import { sequelize } from '../config/db.js'
import { ModelEnums } from './enums.js'

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
