-- Function to get project-based AI impact metrics
CREATE OR REPLACE FUNCTION get_project_metrics()
RETURNS SETOF json AS $$
DECLARE
    project_record RECORD;
    project_metrics JSON;
    impact_data JSON;
BEGIN
    FOR project_record IN SELECT project_id, project_name FROM projects
    LOOP
        -- Call calculate_ai_impact for each project
        SELECT calculate_ai_impact(project_record.project_id, NULL, NULL, NULL) INTO impact_data;

        SELECT json_build_object(
            'projectId', project_record.project_id,
            'projectName', project_record.project_name,
            'totalIssuesAnalyzed', impact_data->'summary'->>'totalIssuesAnalyzed',
            'issuesWithAi', impact_data->'summary'->>'issuesWithAi',
            'issuesWithoutAi', impact_data->'summary'->>'issuesWithoutAi',
            'avgCycleTimeWithAi', impact_data->'summary'->>'avgCycleTimeWithAi',
            'avgCycleTimeWithoutAi', impact_data->'summary'->>'avgCycleTimeWithoutAi',
            'cycleTimeImpactPercentage', impact_data->'summary'->>'cycleTimeImpactPercentage',
            'avgCommitsWithAi', impact_data->'summary'->>'avgCommitsWithAi',
            'avgCommitsWithoutAi', impact_data->'summary'->>'avgCommitsWithoutAi'
        ) INTO project_metrics;

        RETURN NEXT project_metrics;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;