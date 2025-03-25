import express from 'express'
import AIImpactController from '../controllers/aiimpact.controller.js'

const router = express.Router()

router.get('/overall', AIImpactController.getOverallMetrics)
router.get('/teams', AIImpactController.getTeamMetrics)
router.get('/engineers', AIImpactController.getEngineerMetrics)
router.get('/projects', AIImpactController.getProjectMetrics)
router.get('/timeline', AIImpactController.getTimelineMetrics)
router.get('/issues/:issueId/cycle-time', AIImpactController.getIssueCycleTime)
router.get('/issues/cycle-times', AIImpactController.getAllIssueCycleTimes)

export default router
