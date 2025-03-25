import express from 'express'
import MetricController from '../controllers/metric.controller.js'

const router = express.Router()

router.get('/teams/:teamId', MetricController.getTeamMetrics)
router.get('/projects/:projectId', MetricController.getProjectMetrics)
router.get('/engineers/:engineerId', MetricController.getEngineerMetrics)
router.get('/aiimpact/aggregated', MetricController.getAIImpactDashboard)
router.get('/categories/:category', MetricController.getCategoryMetrics)
router.get('/aiimpact/overall', MetricController.calculateAIImpact)
router.get('/refresh/all', MetricController.refreshAllMetrics)

export default router
