-- Function to get team-based AI impact metrics
CREATE OR REPLACE FUNCTION get_team_metrics()
RETURNS SETOF json AS $$
DECLARE
    team_record RECORD;
    team_metrics JSON;
    impact_data JSON;
BEGIN
    FOR team_record IN SELECT team_id, team_name, engineer_ids FROM teams
    LOOP
        -- Call calculate_ai_impact for each team
        SELECT calculate_ai_impact(NULL, NULL, NULL, team_record.team_id) INTO impact_data;

        -- Count engineers on team
        SELECT json_build_object(
            'teamId', team_record.team_id,
            'teamName', team_record.team_name,
            'engineerCount', array_length(string_to_array(team_record.engineer_ids, ','), 1),
            'totalIssuesAnalyzed', impact_data->'summary'->>'totalIssuesAnalyzed',
            'issuesWithAi', impact_data->'summary'->>'issuesWithAi',
            'issuesWithoutAi', impact_data->'summary'->>'issuesWithoutAi',
            'avgCycleTimeWithAi', impact_data->'summary'->>'avgCycleTimeWithAi',
            'avgCycleTimeWithoutAi', impact_data->'summary'->>'avgCycleTimeWithoutAi',
            'cycleTimeImpactPercentage', impact_data->'summary'->>'cycleTimeImpactPercentage',
            'avgCommitsWithAi', impact_data->'summary'->>'avgCommitsWithAi',
            'avgCommitsWithoutAi', impact_data->'summary'->>'avgCommitsWithoutAi'
        ) INTO team_metrics;

        RETURN NEXT team_metrics;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;