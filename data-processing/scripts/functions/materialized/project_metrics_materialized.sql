BEGIN;

CREATE TABLE project_metrics_materialized (
    project_id INTEGER PRIMARY KEY,
    total_issues_analyzed INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    avg_commits_with_ai FLOAT NOT NULL,
    avg_commits_without_ai FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
);


CREATE OR REPLACE FUNCTION refresh_project_metrics(p_project_id INTEGER DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    project_record RECORD;
    impact_data JSON;
BEGIN
    -- Process all projects or just one specific project
    FOR project_record IN
        SELECT DISTINCT project_id
        FROM jira_issues
        WHERE (p_project_id IS NULL OR project_id = p_project_id)
    LOOP
        -- Create temporary tables for project-specific data
        CREATE TEMPORARY TABLE project_commits AS
        SELECT
            c.commit_id,
            c.jira_issue_id,
            c.commit_date,
            c.ai_used,
            c.lines_of_code
        FROM
            commits c
        WHERE
            EXISTS (
                SELECT 1
                FROM jira_issues ji
                WHERE ji.issue_id = c.jira_issue_id
                AND ji.project_id = project_record.project_id
            );

        CREATE TEMPORARY TABLE project_issues AS
        WITH issue_data AS (
            SELECT
                ji.issue_id,
                ji.creation_date,
                ji.resolution_date,
                (SELECT MIN(pc.commit_date) FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id) AS first_commit_date,
                (SELECT COUNT(*) FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id) AS total_commits,
                (SELECT COUNT(*) FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id AND pc.ai_used = true) AS ai_commits,
                (SELECT COUNT(*) FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id AND pc.ai_used = false) AS non_ai_commits,
                (SELECT EXISTS(SELECT 1 FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id AND pc.ai_used = true)) AS has_ai_commits
            FROM
                jira_issues ji
            WHERE
                ji.project_id = project_record.project_id
                AND ji.resolution_date IS NOT NULL
                AND EXISTS (SELECT 1 FROM project_commits pc WHERE pc.jira_issue_id = ji.issue_id)
        )
        SELECT
            issue_id,
            total_commits,
            ai_commits,
            non_ai_commits,
            days_between(first_commit_date, resolution_date) AS cycle_time,
            has_ai_commits
        FROM
            issue_data;

        -- Calculate metrics
        WITH ai_issues AS (
            SELECT
                COUNT(*) AS issue_count,
                AVG(cycle_time) AS avg_cycle_time,
                AVG(total_commits) AS avg_commits
            FROM
                project_issues
            WHERE
                has_ai_commits = true
        ),
        non_ai_issues AS (
            SELECT
                COUNT(*) AS issue_count,
                AVG(cycle_time) AS avg_cycle_time,
                AVG(total_commits) AS avg_commits
            FROM
                project_issues
            WHERE
                has_ai_commits = false
        )
        SELECT
            json_build_object(
                'summary', json_build_object(
                    'totalIssuesAnalyzed', (SELECT issue_count FROM ai_issues) + (SELECT issue_count FROM non_ai_issues),
                    'issuesWithAi', (SELECT issue_count FROM ai_issues),
                    'issuesWithoutAi', (SELECT issue_count FROM non_ai_issues),
                    'avgCycleTimeWithAi', (SELECT avg_cycle_time FROM ai_issues),
                    'avgCycleTimeWithoutAi', (SELECT avg_cycle_time FROM non_ai_issues),
                    'cycleTimeImpactPercentage', CASE
                        WHEN (SELECT avg_cycle_time FROM non_ai_issues) > 0
                        THEN ((SELECT avg_cycle_time FROM non_ai_issues) - (SELECT avg_cycle_time FROM ai_issues)) / (SELECT avg_cycle_time FROM non_ai_issues) * 100
                        ELSE 0
                    END,
                    'avgCommitsWithAi', (SELECT avg_commits FROM ai_issues),
                    'avgCommitsWithoutAi', (SELECT avg_commits FROM non_ai_issues)
                ),
                'detailedStats', json_build_object(
                    'withAiIssues', (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits
                    )) FROM project_issues WHERE has_ai_commits = true),
                    'withoutAiIssues', (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits
                    )) FROM project_issues WHERE has_ai_commits = false)
                )
            ) INTO impact_data;

        -- Insert or update materialized metrics
        INSERT INTO project_metrics_materialized (
            project_id,
            total_issues_analyzed,
            issues_with_ai,
            issues_without_ai,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            cycle_time_impact_percentage,
            avg_commits_with_ai,
            avg_commits_without_ai,
            last_calculated,
            metrics_json
        ) VALUES (
            project_record.project_id,
            (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER,
            (impact_data->'summary'->>'issuesWithAi')::INTEGER,
            (impact_data->'summary'->>'issuesWithoutAi')::INTEGER,
            (impact_data->'summary'->>'avgCycleTimeWithAi')::FLOAT,
            (impact_data->'summary'->>'avgCycleTimeWithoutAi')::FLOAT,
            (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT,
            (impact_data->'summary'->>'avgCommitsWithAi')::FLOAT,
            (impact_data->'summary'->>'avgCommitsWithoutAi')::FLOAT,
            CURRENT_TIMESTAMP,
            impact_data
        )
        ON CONFLICT (project_id) DO UPDATE SET
            total_issues_analyzed = EXCLUDED.total_issues_analyzed,
            issues_with_ai = EXCLUDED.issues_with_ai,
            issues_without_ai = EXCLUDED.issues_without_ai,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            avg_commits_with_ai = EXCLUDED.avg_commits_with_ai,
            avg_commits_without_ai = EXCLUDED.avg_commits_without_ai,
            last_calculated = EXCLUDED.last_calculated,
            metrics_json = EXCLUDED.metrics_json;

        -- Cleanup temporary tables
        DROP TABLE project_commits;
        DROP TABLE project_issues;
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_project_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE,
    p_project_id INTEGER DEFAULT NULL
)
RETURNS SETOF JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    project_record RECORD;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        PERFORM refresh_project_metrics(p_project_id);
    ELSE
        -- Selectively refresh stale project metrics
        FOR project_record IN
            SELECT DISTINCT j.project_id
            FROM jira_issues j
            LEFT JOIN project_metrics_materialized pm ON j.project_id = pm.project_id
            WHERE (p_project_id IS NULL OR j.project_id = p_project_id)
            AND (pm.project_id IS NULL OR pm.last_calculated < refresh_cutoff)
        LOOP
            PERFORM refresh_project_metrics(project_record.project_id);
        END LOOP;
    END IF;

    -- Return materialized metrics
    FOR project_record IN
        SELECT
            json_build_object(
                'projectId', project_id,
                'totalIssuesAnalyzed', total_issues_analyzed,
                'issuesWithAi', issues_with_ai,
                'issuesWithoutAi', issues_without_ai,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cycle_time_impact_percentage,
                'avgCommitsWithAi', avg_commits_with_ai,
                'avgCommitsWithoutAi', avg_commits_without_ai,
                'lastUpdated', last_calculated,
                'detailedStats', metrics_json->'detailedStats'
            ) AS project_metrics_json
        FROM
            project_metrics_materialized
        WHERE
            (p_project_id IS NULL OR project_id = p_project_id)
        ORDER BY
            project_id
    LOOP
        RETURN NEXT project_record.project_metrics_json;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;


-- Populate project metrics
SELECT refresh_project_metrics();


COMMIT;


CREATE INDEX idx_project_metrics_project_id ON project_metrics_materialized(project_id);
CREATE INDEX idx_project_metrics_last_calculated ON project_metrics_materialized(last_calculated);