import { Engineer } from './Engineer.js'
import { Team } from './Team.js'
import { Project } from './Project.js'
import { Repository } from './Repository.js'
import { JiraIssue } from './JiraIssue.js'
import { Commit } from './Commit.js'

// Define relationships between models
// Projects and Repositories (One-to-Many)
Project.hasMany(Repository, { foreignKey: 'project_id' })
Repository.belongsTo(Project, { foreignKey: 'project_id' })

// Engineers and JiraIssues (One-to-Many)
Engineer.hasMany(JiraIssue, { foreignKey: 'author_id' })
JiraIssue.belongsTo(Engineer, { foreignKey: 'author_id' })

// Projects and JiraIssues (One-to-Many)
Project.hasMany(JiraIssue, { foreignKey: 'project_id' })
JiraIssue.belongsTo(Project, { foreignKey: 'project_id' })

// Repositories and Commits (One-to-Many)
Repository.hasMany(Commit, { foreignKey: 'repo_id' })
Commit.belongsTo(Repository, { foreignKey: 'repo_id' })

// Engineers and Commits (One-to-Many)
Engineer.hasMany(Commit, { foreignKey: 'engineer_id' })
Commit.belongsTo(Engineer, { foreignKey: 'engineer_id' })

// JiraIssues and Commits (One-to-Many)
JiraIssue.hasMany(Commit, { foreignKey: 'jira_issue_id' })
Commit.belongsTo(JiraIssue, { foreignKey: 'jira_issue_id' })

export { Engineer, Team, Project, Repository, JiraIssue, Commit }
