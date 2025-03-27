import express from 'express'
import MetricController from '../controllers/metric.controller.js'

const router = express.Router()

router.get('/teams/:teamId', MetricController.getTeamMetrics)
router.get('/projects/:projectId', MetricController.getProjectMetrics)
router.get('/engineers/:engineerId', MetricController.getEngineerMetrics)
router.get('/categories/all', MetricController.getCategoriesMetrics)
router.get('/categories/:category', MetricController.getCategoryMetrics)
router.get('/aiimpact/summary', MetricController.getAIImpactSummary)
router.get(
	'/aiimpact/aggregated/:teamId/:projectId',
	MetricController.getAIImpactDashboard,
)
router.get('/aiimpact/overall', MetricController.calculateAIImpact)
router.get('/refresh/all', MetricController.refreshAllMetrics)
router.get('/filters/options', MetricController.getFilterOptions)

export default router
