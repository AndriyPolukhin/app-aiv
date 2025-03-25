# Appendix A: CSV Table Details Schemas Description

## Tables

### 1. Engineers (`engineers.csv`)

-   `id` (Integer): Unique identifier for each engineer.
-   `name` (String): Name of the engineer.

### 2. Teams (`teams.csv`)

-   `team_id` (Integer): Unique identifier for each team.
-   `team_name` (String): Name of the team.
-   `engineer_ids` (String): Comma-separated list of engineer IDs belonging to the team.

### 3. Projects (`projects.csv`)

-   `project_id` (Integer): Unique identifier for each project.
-   `project_name` (String): Name of the project.

### 4. Repositories (`repositories.csv`)

-   `repo_id` (Integer): Unique identifier for each repository.
-   `project_id` (Integer): ID of the associated project.
-   `repo_name` (String): Name of the repository.

### 5. Jira Issues (`jira_issues.csv`)

-   `issue_id` (Integer): Unique identifier for each issue.
-   `project_id` (Integer): ID of the associated project.
-   `author_id` (Integer): ID of the engineer who created the issue.
-   `creation_date` (String, YYYY-MM-DD): Date the issue was created.
-   `resolution_date` (String, YYYY-MM-DD): Date the issue was resolved.
-   `category` (String): Category of the issue (e.g., "Bug Fix", "Feature Development").

### 6. Commits (`commits.csv`)

-   `commit_id` (String): Unique identifier for each commit (UUID).
-   `engineer_id` (Integer): ID of the engineer who made the commit.
-   `jira_issue_id` (Integer): ID of the associated Jira issue.
-   `repo_id` (Integer): ID of the repository where the commit was made.
-   `commit_date` (String, YYYY-MM-DD): Date the commit was made.
-   `ai_used` (Boolean): Indicates if AI was used (True or False).
-   `lines_of_code` (Integer): Number of lines of code changed.

## Basic Relationships Among Entities

Below are the key relationships between the different data entities:

1. **Teams to Engineers**: A team contains multiple engineers (`engineer_ids` in `teams.csv` references `id` in `engineers.csv`).

2. **Projects to Repositories**: A project can have multiple repositories (`project_id` in `repositories.csv` references `project_id` in `projects.csv`).

3. **Projects to Jira Issues**: A project can have multiple Jira issues (`project_id` in `jira_issues.csv` references `project_id` in `projects.csv`).

4. **Engineers to Jira Issues**: An engineer can create multiple Jira issues (`author_id` in `jira_issues.csv` references `id` in `engineers.csv`).

5. **Engineers to Commits**: An engineer can make multiple commits (`engineer_id` in `commits.csv` references `id` in `engineers.csv`).

6. **Jira Issues to Commits**: A Jira issue can be associated with multiple commits (`jira_issue_id` in `commits.csv` references `issue_id` in `jira_issues.csv`).

7. **Repositories to Commits**: A repository can contain multiple commits (`repo_id` in `commits.csv` references `repo_id` in `repositories.csv`).
