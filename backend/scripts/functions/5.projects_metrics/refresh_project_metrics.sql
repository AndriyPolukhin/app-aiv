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
        -- Calculate metrics using existing function
        SELECT calculate_ai_impact(project_record.project_id, NULL, NULL, NULL) INTO impact_data;

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
    END LOOP;
END;
$$ LANGUAGE plpgsql;
