CREATE OR REPLACE VIEW vw_ai_impact AS
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
    team_ids,
    last_updated
FROM
    ai_impact_summary;