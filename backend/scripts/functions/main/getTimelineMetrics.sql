-- Function to get timeline metrics showing AI adoption over time
CREATE OR REPLACE FUNCTION get_timeline_metrics()
RETURNS SETOF json AS $$
DECLARE
    month_record RECORD;
    monthly_metrics JSON;
BEGIN
    FOR month_record IN
        WITH monthly_data AS (
            SELECT
                TO_CHAR(commit_date, 'YYYY-MM') AS month,
                COUNT(*) AS total_commits,
                SUM(CASE WHEN ai_used THEN 1 ELSE 0 END) AS ai_commits
            FROM
                commits
            GROUP BY
                TO_CHAR(commit_date, 'YYYY-MM')
        ),

        monthly_issues AS (
            SELECT
                TO_CHAR(ji.resolution_date, 'YYYY-MM') AS month,
                COUNT(*) AS resolved_issues,
                SUM(days_between(
                    (SELECT MIN(c.commit_date) FROM commits c WHERE c.jira_issue_id = ji.issue_id),
                    ji.resolution_date
                )) AS total_cycle_time,
                COUNT(*) AS issue_count
            FROM
                jira_issues ji
            WHERE
                ji.resolution_date IS NOT NULL
                AND EXISTS (SELECT 1 FROM commits c WHERE c.jira_issue_id = ji.issue_id)
            GROUP BY
                TO_CHAR(ji.resolution_date, 'YYYY-MM')
        )

        SELECT
            md.month,
            md.total_commits,
            md.ai_commits,
            COALESCE(mi.resolved_issues, 0) AS resolved_issues,
            CASE
                WHEN COALESCE(mi.issue_count, 0) > 0
                THEN COALESCE(mi.total_cycle_time, 0) / COALESCE(mi.issue_count, 1)
                ELSE 0
            END AS avg_cycle_time,
            CASE
                WHEN md.total_commits > 0
                THEN (md.ai_commits::float / md.total_commits) * 100
                ELSE 0
            END AS ai_adoption_rate
        FROM
            monthly_data md
        LEFT JOIN
            monthly_issues mi ON md.month = mi.month
        ORDER BY
            md.month
    LOOP
        SELECT json_build_object(
            'month', month_record.month,
            'totalCommits', month_record.total_commits,
            'aiCommits', month_record.ai_commits,
            'resolvedIssues', month_record.resolved_issues,
            'avgCycleTime', month_record.avg_cycle_time,
            'aiAdoptionRate', month_record.ai_adoption_rate
        ) INTO monthly_metrics;

        RETURN NEXT monthly_metrics;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;