CREATE OR REPLACE FUNCTION calculate_ai_impact(
    p_project_id INTEGER DEFAULT NULL,
    p_author_id INTEGER DEFAULT NULL,
    p_engineer_id INTEGER DEFAULT NULL,
    p_team_id INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    result_json JSON;
    avg_cycle_time_with_ai FLOAT := 0;
    avg_cycle_time_without_ai FLOAT := 0;
    impact_percentage FLOAT := 0;
    avg_commits_with_ai FLOAT := 0;
    avg_commits_without_ai FLOAT := 0;
    total_ai_issues INTEGER := 0;
    total_non_ai_issues INTEGER := 0;
BEGIN
    -- Create a temporary table for all applicable commits based on filters
    CREATE TEMPORARY TABLE filtered_commits AS
    SELECT
        c.commit_id,
        c.engineer_id,
        c.jira_issue_id,
        c.repo_id,
        c.commit_date,
        c.ai_used,
        c.lines_of_code
    FROM
        commits c
    WHERE
        (p_engineer_id IS NULL OR c.engineer_id = p_engineer_id)
        AND (p_team_id IS NULL OR c.engineer_id IN (
            SELECT unnest(string_to_array(engineer_ids, ',')::int[])
            FROM teams
            WHERE team_id = p_team_id
        ));

    -- Create a single temporary table for all issues with AI flag
    CREATE TEMPORARY TABLE temp_all_issues AS
    WITH issue_data AS (
        SELECT
            ji.issue_id,
            ji.project_id,
            ji.author_id,
            ji.creation_date,
            ji.resolution_date,
            ji.category,
            (SELECT MIN(fc.commit_date) FROM filtered_commits fc WHERE fc.jira_issue_id = ji.issue_id) AS first_commit_date,
            (SELECT COUNT(*) FROM filtered_commits fc WHERE fc.jira_issue_id = ji.issue_id) AS total_commits,
            (SELECT COUNT(*) FROM filtered_commits fc WHERE fc.jira_issue_id = ji.issue_id AND fc.ai_used = true) AS ai_commits,
            (SELECT EXISTS(SELECT 1 FROM filtered_commits fc WHERE fc.jira_issue_id = ji.issue_id AND fc.ai_used = true)) AS has_ai_commits
        FROM
            jira_issues ji
        WHERE
            ji.resolution_date IS NOT NULL
            AND (p_project_id IS NULL OR ji.project_id = p_project_id)
            AND (p_author_id IS NULL OR ji.author_id = p_author_id)
            AND EXISTS (SELECT 1 FROM filtered_commits fc WHERE fc.jira_issue_id = ji.issue_id)
    )
    SELECT
        issue_id,
        category,
        total_commits,
        ai_commits,
        (total_commits - ai_commits) AS non_ai_commits,
        days_between(first_commit_date, resolution_date) AS cycle_time,
        has_ai_commits
    FROM
        issue_data;

    -- Calculate all metrics in a single pass
    SELECT
        COALESCE(AVG(CASE WHEN has_ai_commits THEN cycle_time END), 0),
        COALESCE(AVG(CASE WHEN NOT has_ai_commits THEN cycle_time END), 0),
        COUNT(CASE WHEN has_ai_commits THEN 1 END),
        COUNT(CASE WHEN NOT has_ai_commits THEN 1 END),
        COALESCE(AVG(CASE WHEN has_ai_commits THEN total_commits END), 0),
        COALESCE(AVG(CASE WHEN NOT has_ai_commits THEN total_commits END), 0)
    INTO
        avg_cycle_time_with_ai,
        avg_cycle_time_without_ai,
        total_ai_issues,
        total_non_ai_issues,
        avg_commits_with_ai,
        avg_commits_without_ai
    FROM
        temp_all_issues;

    -- Calculate impact percentage
    IF avg_cycle_time_without_ai > 0 THEN
        impact_percentage := ((avg_cycle_time_without_ai - avg_cycle_time_with_ai) / avg_cycle_time_without_ai) * 100;
    END IF;

    -- Build the final result with all JSON structures in a single query
    WITH
    ai_category_stats AS (
        SELECT
            category,
            COUNT(*) AS count,
            SUM(cycle_time) AS total_cycle_time,
            AVG(cycle_time) AS avg_cycle_time,
            json_agg(json_build_object(
                'issueId', issue_id,
                'cycleTime', cycle_time,
                'totalCommits', total_commits,
                'aiCommits', ai_commits,
                'nonAiCommits', non_ai_commits,
                'category', category
            )) AS issues
        FROM
            temp_all_issues
        WHERE
            has_ai_commits = true
        GROUP BY
            category
    ),
    non_ai_category_stats AS (
        SELECT
            category,
            COUNT(*) AS count,
            SUM(cycle_time) AS total_cycle_time,
            AVG(cycle_time) AS avg_cycle_time,
            json_agg(json_build_object(
                'issueId', issue_id,
                'cycleTime', cycle_time,
                'totalCommits', total_commits,
                'aiCommits', ai_commits,
                'nonAiCommits', non_ai_commits,
                'category', category
            )) AS issues
        FROM
            temp_all_issues
        WHERE
            has_ai_commits = false
        GROUP BY
            category
    )
    SELECT
        json_build_object(
            'summary', json_build_object(
                'totalIssuesAnalyzed', total_ai_issues + total_non_ai_issues,
                'issuesWithAi', total_ai_issues,
                'issuesWithoutAi', total_non_ai_issues,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', impact_percentage,
                'avgCommitsWithAi', avg_commits_with_ai,
                'avgCommitsWithoutAi', avg_commits_without_ai
            ),
            'detailedStats', json_build_object(
                'issuesWithAi', COALESCE(
                    (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits,
                        'category', category
                    )) FROM temp_all_issues WHERE has_ai_commits = true),
                    '[]'::json
                ),
                'issuesWithoutAi', COALESCE(
                    (SELECT json_agg(json_build_object(
                        'issueId', issue_id,
                        'cycleTime', cycle_time,
                        'totalCommits', total_commits,
                        'aiCommits', ai_commits,
                        'nonAiCommits', non_ai_commits,
                        'category', category
                    )) FROM temp_all_issues WHERE has_ai_commits = false),
                    '[]'::json
                ),
                'categoriesWithAi', COALESCE(
                    (SELECT json_object_agg(
                        category,
                        json_build_object(
                            'count', count,
                            'totalCycleTime', total_cycle_time,
                            'avgCycleTime', avg_cycle_time,
                            'issues', issues
                        )
                    ) FROM ai_category_stats),
                    '{}'::json
                ),
                'categoriesWithoutAi', COALESCE(
                    (SELECT json_object_agg(
                        category,
                        json_build_object(
                            'count', count,
                            'totalCycleTime', total_cycle_time,
                            'avgCycleTime', avg_cycle_time,
                            'issues', issues
                        )
                    ) FROM non_ai_category_stats),
                    '{}'::json
                )
            )
        )
    INTO result_json;

    -- Clean up temporary tables (only 2 now instead of 5)
    DROP TABLE filtered_commits;
    DROP TABLE temp_all_issues;

    RETURN result_json;
END;
$$ LANGUAGE plpgsql;