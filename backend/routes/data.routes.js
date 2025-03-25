import express from 'express'
import UtilsController from '../controllers/data.controller.js'

const router = express.Router()

router.get('/teams', UtilsController.getTeamsData)
router.get('/teams/count', UtilsController.getTeamsCount)
router.get('/issues', UtilsController.getJiraIssuesData)
router.get('/issues/count', UtilsController.getJiraIssuesCount)
router.get('/commits', UtilsController.getCommitsData)
router.get('/commits/count', UtilsController.getCommitsCount)
router.get('/projects', UtilsController.getProjectsData)
router.get('/projects/count', UtilsController.getProjectsCount)
router.get('/engineers', UtilsController.getEngineersData)
router.get('/engineers/count', UtilsController.getEngineersCount)
router.get('/repositories', UtilsController.getRepositoriesData)
router.get('/repositories/count', UtilsController.getRepositoriesCount)

export default router
