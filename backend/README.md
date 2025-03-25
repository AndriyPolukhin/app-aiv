# AI Impact Visualization Backend

This backend service provides APIs for analyzing and visualizing the impact of AI tools on software engineering productivity metrics, particularly cycle time.

## Core Features

-   **Cycle Time Analysis**: Calculate and compare development cycle times
-   **AI Impact Metrics**: Analyze how AI tool usage affects development efficiency
-   **Team & Engineer Analytics**: Break down metrics by teams and individual engineers
-   **Timeline Visualization Data**: Track AI adoption and impact over time
-   **Project-based Insights**: Compare AI impact across different projects

## Technical Architecture

The system is built with a clean, modular architecture:

-   **API Layer**: Express.js RESTful API
-   **Service Layer**: Business logic for metrics calculations
-   **Data Access Layer**: Sequelize ORM with SQLite/PostgreSQL support
-   **Models**: Domain entities representing engineering workflow components

## Data Model

The system works with the following key entities:

-   Engineers
-   Teams
-   Projects
-   Repositories
-   Jira Issues
-   Commits

## Getting Started

### Prerequisites

-   Node.js
-   npm or yarn

### Installation

1. Install dependencies

    ```bash
    npm install
    ```

2. Create `.env` file with your configuration

    ```
    Database configuration:
    DB_HOST=localhost
    DB_PORT=5432
    DB_NAME=ai_impact
    DB_USER=postgres
    DB_PASSWORD=postgres

    Server configuration:
    PORT=5001
    NODE_ENV='development'
    ```

3. Download the [data.zip](https://drive.google.com/file/d/1U1VekbA1sYG-58HLD-K8NJx3omM5lyf_/view?usp=sharing) file and unzip it into backend/data folder

4. Run the script to create the database, tables, view and procedures and populate the database with entries from the folders of a data folder.

    ```
    npm run setup

    npm run create-db
    npm run create-fns
    npm run seed-db

    npm run drop-db
    npm run reset-db
    ```

5. Start the developers server
    ```bash
    npm run dev
    ```

## API Endpoints

### Overall Metrics

-   `GET /api/metrics/overall` - Get overall AI impact metrics
-   Query parameters:
    -   `teamId` - Filter by team ID
    -   `engineerId` - Filter by engineer ID
    -   `projectId` - Filter by project ID

### Team Info

-   `GET /api/data/teams?limit=10` - Get team-based info

### Engineer Info

-   `GET /api/data/engineers?limit=10` - Get engineer-based info

### Project Info

-   `GET /api/data/projects?limit=10` - Get project-based info

### Issue Cycle Times

-   `GET /api/metrics/issues/:issueId/cycle-time` - Get cycle time for a specific issue
-   `GET /api/metrics/issues/cycle-times` - Get cycle times for all issues

## Data Model Diagrams (Refer to Appendix A)

```

Engineers (1) --< Commits (N) | +--< JiraIssues (N) | Projects (1)-+ | +--< Repositories (1) --< Commits (N)

```
