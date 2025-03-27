CREATE MATERIALIZED VIEW mv_ai_impact_base AS
WITH commit_data AS (
    SELECT
        c.commit_id,
        c.engineer_id,
        c.jira_issue_id,
        c.repo_id,
        c.commit_date,
        c.ai_used,
        c.lines_of_code,
        t.team_id
    FROM
        commits c
    LEFT JOIN teams t ON c.engineer_id = ANY(string_to_array(t.engineer_ids, ',')::int[])
),
issue_data AS (
    SELECT
        ji.issue_id,
        ji.project_id,
        ji.author_id,
        ji.creation_date,
        ji.resolution_date,
        ji.category,
        MIN(fc.commit_date) AS first_commit_date,
        COUNT(fc.commit_id) AS total_commits,
        COUNT(fc.commit_id) FILTER (WHERE fc.ai_used = true) AS ai_commits,
        (COUNT(fc.commit_id) - COUNT(fc.commit_id) FILTER (WHERE fc.ai_used = true)) AS non_ai_commits,
        BOOL_OR(fc.ai_used) AS has_ai_commits,
        days_between(MIN(fc.commit_date), ji.resolution_date) AS cycle_time,
        array_agg(DISTINCT fc.team_id) AS team_ids
    FROM
        jira_issues ji
    JOIN commit_data fc ON ji.issue_id = fc.jira_issue_id
    WHERE
        ji.resolution_date IS NOT NULL
    GROUP BY
        ji.issue_id, ji.project_id, ji.author_id, ji.creation_date, ji.resolution_date, ji.category
)
SELECT
    issue_id,
    project_id,
    author_id,
    category,
    total_commits,
    ai_commits,
    non_ai_commits,
    cycle_time,
    has_ai_commits,
    team_ids
FROM
    issue_data;

-- Create supporting indexes
CREATE INDEX idx_mv_ai_impact_project ON mv_ai_impact_base(project_id);
CREATE INDEX idx_mv_ai_impact_author ON mv_ai_impact_base(author_id);
CREATE INDEX idx_mv_ai_impact_teams ON mv_ai_impact_base USING gin(team_ids);


CREATE OR REPLACE FUNCTION refresh_ai_impact_data()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ai_impact_base;
END;
$$ LANGUAGE plpgsql;




