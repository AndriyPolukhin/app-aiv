CREATE OR REPLACE FUNCTION refresh_category_metrics(p_category TEXT DEFAULT NULL)
RETURNS VOID AS $$
DECLARE
    category_record RECORD;
    ai_issues_data RECORD;
    non_ai_issues_data RECORD;
    impact_percentage FLOAT := 0;
    metrics_json JSON;
BEGIN
    -- Process all categories or just one specific category
    FOR category_record IN
        SELECT DISTINCT category
        FROM jira_issues
        WHERE (p_category IS NULL OR category = p_category)
    LOOP
        -- Create filtered views for this category
        CREATE TEMPORARY TABLE category_ai_issues AS
        WITH issue_data AS (
            SELECT
                ji.issue_id,
                ji.creation_date,
                ji.resolution_date,
                (SELECT MIN(c.commit_date) FROM commits c WHERE c.jira_issue_id = ji.issue_id) AS first_commit_date,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id) AS total_commits,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id AND c.ai_used = true) AS ai_commits,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id AND c.ai_used = false) AS non_ai_commits
            FROM
                jira_issues ji
            WHERE
                ji.category = category_record.category
                AND ji.resolution_date IS NOT NULL
                AND EXISTS (SELECT 1 FROM commits c WHERE c.jira_issue_id = ji.issue_id)
        )
        SELECT
            issue_id,
            total_commits,
            ai_commits,
            non_ai_commits,
            days_between(first_commit_date, resolution_date) AS cycle_time
        FROM
            issue_data
        WHERE
            (SELECT EXISTS(SELECT 1 FROM commits c WHERE c.jira_issue_id = issue_id AND c.ai_used = true));

        CREATE TEMPORARY TABLE category_non_ai_issues AS
        WITH issue_data AS (
            SELECT
                ji.issue_id,
                ji.creation_date,
                ji.resolution_date,
                (SELECT MIN(c.commit_date) FROM commits c WHERE c.jira_issue_id = ji.issue_id) AS first_commit_date,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id) AS total_commits,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id AND c.ai_used = true) AS ai_commits,
                (SELECT COUNT(*) FROM commits c WHERE c.jira_issue_id = ji.issue_id AND c.ai_used = false) AS non_ai_commits
            FROM
                jira_issues ji
            WHERE
                ji.category = category_record.category
                AND ji.resolution_date IS NOT NULL
                AND EXISTS (SELECT 1 FROM commits c WHERE c.jira_issue_id = ji.issue_id)
        )
        SELECT
            issue_id,
            total_commits,
            ai_commits,
            non_ai_commits,
            days_between(first_commit_date, resolution_date) AS cycle_time
        FROM
            issue_data
        WHERE
            NOT (SELECT EXISTS(SELECT 1 FROM commits c WHERE c.jira_issue_id = issue_id AND c.ai_used = true));

        -- Calculate metrics
        SELECT
            COUNT(*) AS issue_count,
            COALESCE(AVG(cycle_time), 0) AS avg_cycle_time,
            COALESCE(AVG(total_commits), 0) AS avg_commits
        INTO ai_issues_data
        FROM
            category_ai_issues;

        SELECT
            COUNT(*) AS issue_count,
            COALESCE(AVG(cycle_time), 0) AS avg_cycle_time,
            COALESCE(AVG(total_commits), 0) AS avg_commits
        INTO non_ai_issues_data
        FROM
            category_non_ai_issues;

        -- Calculate impact percentage
        IF non_ai_issues_data.avg_cycle_time > 0 THEN
            impact_percentage := ((non_ai_issues_data.avg_cycle_time - ai_issues_data.avg_cycle_time) / non_ai_issues_data.avg_cycle_time) * 100;
        END IF;

        -- Build detailed JSON
        SELECT
            json_build_object(
                'summary', json_build_object(
                    'totalIssues', ai_issues_data.issue_count + non_ai_issues_data.issue_count,
                    'issuesWithAi', ai_issues_data.issue_count,
                    'issuesWithoutAi', non_ai_issues_data.issue_count,
                    'avgCycleTimeWithAi', ai_issues_data.avg_cycle_time,
                    'avgCycleTimeWithoutAi', non_ai_issues_data.avg_cycle_time,
                    'cycleTimeImpactPercentage', impact_percentage,
                    'avgCommitsWithAi', ai_issues_data.avg_commits,
                    'avgCommitsWithoutAi', non_ai_issues_data.avg_commits
                ),
                'detailedStats', json_build_object(
                    'withAiIssues', (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits
                    )) FROM category_ai_issues),
                    'withoutAiIssues', (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits
                    )) FROM category_non_ai_issues)
                )
            ) INTO metrics_json;

        -- Insert or update materialized metrics
        INSERT INTO category_metrics_materialized (
            category,
            total_issues,
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
            category_record.category,
            ai_issues_data.issue_count + non_ai_issues_data.issue_count,
            ai_issues_data.issue_count,
            non_ai_issues_data.issue_count,
            ai_issues_data.avg_cycle_time,
            non_ai_issues_data.avg_cycle_time,
            impact_percentage,
            ai_issues_data.avg_commits,
            non_ai_issues_data.avg_commits,
            CURRENT_TIMESTAMP,
            metrics_json
        )
        ON CONFLICT (category) DO UPDATE SET
            total_issues = EXCLUDED.total_issues,
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
        DROP TABLE category_ai_issues;
        DROP TABLE category_non_ai_issues;
    END LOOP;
END;
$$ LANGUAGE plpgsql;
