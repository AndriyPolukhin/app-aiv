import express from 'express'
import UtilsController from '../controllers/data.controller.js'

const router = express.Router()

/**
 * @swagger
 * /api/data/teams:
 *   get:
 *     summary: Retrieve all teams
 *     description: Returns a list of all teams with their associated engineers
 *     tags: [Teams]
 *     responses:
 *       200:
 *         description: A list of teams
 *         content:
 *           application/json:
 *             schema:
 *               type: array
 *               items:
 *                 $ref: '@/schemas/Team'
 *       500:
 *         description: Server error
 */
router.get('/teams', UtilsController.getTeamsData)
/**
 * @swagger
 * /api/data/teams/count:
 *   get:
 *     summary: Get team count
 *     description: Returns the total number of teams in the system
 *     tags: [Teams]
 *     responses:
 *       200:
 *         description: Team count
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 count:
 *                   type: integer
 *                   example: 5
 *       500:
 *         description: Server error
 */
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
