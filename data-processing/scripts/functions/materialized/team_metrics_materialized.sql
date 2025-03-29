BEGIN;

CREATE TABLE team_metrics_materialized (
    team_id INTEGER PRIMARY KEY,
    total_issues INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    ai_adoption_rate FLOAT NOT NULL,
    top_categories JSON NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
);

CREATE OR REPLACE FUNCTION refresh_team_metrics(p_team_id INTEGER DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    team_record RECORD;
    impact_data JSON;
BEGIN
    -- Process all teams or just one specific team
    FOR team_record IN
        SELECT team_id
        FROM teams
        WHERE (p_team_id IS NULL OR team_id = p_team_id)
    LOOP
        -- Create temporary tables for team-specific data
        CREATE TEMPORARY TABLE team_commits AS
        SELECT
            c.commit_id,
            c.jira_issue_id,
            c.commit_date,
            c.ai_used,
            c.lines_of_code
        FROM
            commits c
        WHERE
            c.engineer_id::TEXT = ANY(string_to_array((SELECT engineer_ids FROM teams WHERE team_id = team_record.team_id), ','));

        CREATE TEMPORARY TABLE team_issues AS
        WITH issue_data AS (
            SELECT
                ji.issue_id,
                ji.creation_date,
                ji.resolution_date,
                (SELECT MIN(tc.commit_date) FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id) AS first_commit_date,
                (SELECT COUNT(*) FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id) AS total_commits,
                (SELECT COUNT(*) FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id AND tc.ai_used = true) AS ai_commits,
                (SELECT COUNT(*) FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id AND tc.ai_used = false) AS non_ai_commits,
                (SELECT EXISTS(SELECT 1 FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id AND tc.ai_used = true)) AS has_ai_commits
            FROM
                jira_issues ji
            WHERE
                ji.resolution_date IS NOT NULL
                AND EXISTS (SELECT 1 FROM team_commits tc WHERE tc.jira_issue_id = ji.issue_id)
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
                team_issues
            WHERE
                has_ai_commits = true
        ),
        non_ai_issues AS (
            SELECT
                COUNT(*) AS issue_count,
                AVG(cycle_time) AS avg_cycle_time,
                AVG(total_commits) AS avg_commits
            FROM
                team_issues
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
                'categories', (
                    SELECT json_agg(json_build_object(
                        'category', category,
                        'issueCount', issue_count,
                        'aiPercentage', (ai_count::FLOAT / issue_count) * 100
                    ))
                    FROM (
                        SELECT
                            ji.category,
                            COUNT(*) AS issue_count,
                            SUM(CASE WHEN ti.has_ai_commits THEN 1 ELSE 0 END) AS ai_count
                        FROM
                            team_issues ti
                            JOIN jira_issues ji ON ti.issue_id = ji.issue_id
                        GROUP BY
                            ji.category
                        ORDER BY
                            issue_count DESC
                        LIMIT 5
                    ) top_cats
                )
            ) INTO impact_data;

        -- Insert or update materialized metrics
        INSERT INTO team_metrics_materialized (
            team_id,
            total_issues,
            issues_with_ai,
            issues_without_ai,
            avg_cycle_time_with_ai,
            avg_cycle_time_without_ai,
            cycle_time_impact_percentage,
            ai_adoption_rate,
            top_categories,
            last_calculated,
            metrics_json
        ) VALUES (
            team_record.team_id,
            (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER,
            (impact_data->'summary'->>'issuesWithAi')::INTEGER,
            (impact_data->'summary'->>'issuesWithoutAi')::INTEGER,
            (impact_data->'summary'->>'avgCycleTimeWithAi')::FLOAT,
            (impact_data->'summary'->>'avgCycleTimeWithoutAi')::FLOAT,
            (impact_data->'summary'->>'cycleTimeImpactPercentage')::FLOAT,
            CASE
                WHEN (impact_data->'summary'->>'totalIssuesAnalyzed')::INTEGER > 0
                THEN (impact_data->'summary'->>'issuesWithAi')::FLOAT / (impact_data->'summary'->>'totalIssuesAnalyzed')::FLOAT
                ELSE 0
            END,
            COALESCE(impact_data->'categories', '[]'::JSON),
            CURRENT_TIMESTAMP,
            impact_data
        )
        ON CONFLICT (team_id) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
            issues_with_ai = EXCLUDED.issues_with_ai,
            issues_without_ai = EXCLUDED.issues_without_ai,
            avg_cycle_time_with_ai = EXCLUDED.avg_cycle_time_with_ai,
            avg_cycle_time_without_ai = EXCLUDED.avg_cycle_time_without_ai,
            cycle_time_impact_percentage = EXCLUDED.cycle_time_impact_percentage,
            ai_adoption_rate = EXCLUDED.ai_adoption_rate,
            top_categories = EXCLUDED.top_categories,
            last_calculated = EXCLUDED.last_calculated,
            metrics_json = EXCLUDED.metrics_json;

        -- Cleanup temporary tables
        DROP TABLE team_commits;
        DROP TABLE team_issues;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_team_metrics_optimized(
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
RETURNS SETOF JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    team_record RECORD;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh metrics if stale or forced
    IF p_force_refresh THEN
        PERFORM refresh_team_metrics();
    ELSE
        -- Selectively refresh stale team metrics
        FOR team_record IN
            SELECT team_id
            FROM teams t
            LEFT JOIN team_metrics_materialized tm ON t.team_id = tm.team_id
            WHERE tm.team_id IS NULL OR tm.last_calculated < refresh_cutoff
        LOOP
            PERFORM refresh_team_metrics(team_record.team_id);
        END LOOP;
    END IF;

    -- Return materialized metrics joined with team info
    FOR team_record IN
        SELECT
            json_build_object(
                'teamId', tm.team_id,
                'teamName', t.team_name,
                'engineerCount', array_length(string_to_array(t.engineer_ids, ','), 1),
                'totalIssuesAnalyzed', tm.total_issues,
                'issuesWithAi', tm.issues_with_ai,
                'issuesWithoutAi', tm.issues_without_ai,
                'avgCycleTimeWithAi', tm.avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', tm.avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', tm.cycle_time_impact_percentage,
                'aiAdoptionRate', tm.ai_adoption_rate,
                'topCategories', tm.top_categories,
                'lastUpdated', tm.last_calculated
            ) AS team_metrics_json
        FROM
            team_metrics_materialized tm
            JOIN teams t ON tm.team_id = t.team_id
        ORDER BY
            tm.team_id
    LOOP
        RETURN NEXT team_record.team_metrics_json;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;


SELECT refresh_team_metrics();
COMMIT;


CREATE INDEX idx_team_metrics_team_id ON team_metrics_materialized(team_id);
CREATE INDEX idx_team_metrics_last_calculated ON team_metrics_materialized(last_calculated);