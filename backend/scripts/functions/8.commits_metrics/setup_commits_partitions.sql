CREATE OR REPLACE FUNCTION setup_commits_partitions()
RETURNS void AS $$
BEGIN
    -- Create the parent table if it doesn't exist
    CREATE TABLE IF NOT EXISTS commits (
        commit_id varchar(255) NOT NULL,
        engineer_id integer NOT NULL,
        jira_issue_id integer NOT NULL,
        repo_id integer NOT NULL,
        commit_date date NOT NULL,
        ai_used boolean NOT NULL,
        lines_of_code integer NOT NULL,
        PRIMARY KEY(commit_id, commit_date),
        CONSTRAINT commits_engineer_id_fkey FOREIGN KEY (engineer_id)
            REFERENCES engineers(id),
        CONSTRAINT commits_jira_issue_id_fkey FOREIGN KEY (jira_issue_id)
            REFERENCES jira_issues(issue_id),
        CONSTRAINT commits_repo_id_fkey FOREIGN KEY (repo_id)
            REFERENCES repositories(repo_id)
    ) PARTITION BY RANGE (commit_date);

    -- Create indexes on parent table (will propagate to partitions)
    CREATE INDEX IF NOT EXISTS idx_commits_jira_issue_id ON commits (jira_issue_id);
    CREATE INDEX IF NOT EXISTS idx_commits_ai_used ON commits (ai_used);
    CREATE INDEX IF NOT EXISTS idx_commits_dates ON commits (commit_date);

    RAISE NOTICE 'Commits parent table and indexes created/verified';
END;
$$ LANGUAGE plpgsql;