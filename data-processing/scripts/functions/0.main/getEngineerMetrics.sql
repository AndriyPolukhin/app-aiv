-- Function to get engineer-based AI impact metrics
CREATE OR REPLACE FUNCTION get_engineer_metrics()
RETURNS SETOF json AS $$
DECLARE
    engineer_record RECORD;
    engineer_metrics JSON;
    impact_data JSON;
BEGIN
    FOR engineer_record IN SELECT id, name FROM engineers
    LOOP
        -- Call calculate_ai_impact for each engineer
        SELECT calculate_ai_impact(NULL, NULL, engineer_record.id, NULL) INTO impact_data;

        SELECT json_build_object(
            'engineerId', engineer_record.id,
            'engineerName', engineer_record.name,
            'totalIssuesAnalyzed', impact_data->'summary'->>'totalIssuesAnalyzed',
            'issuesWithAi', impact_data->'summary'->>'issuesWithAi',
            'issuesWithoutAi', impact_data->'summary'->>'issuesWithoutAi',
            'avgCycleTimeWithAi', impact_data->'summary'->>'avgCycleTimeWithAi',
            'avgCycleTimeWithoutAi', impact_data->'summary'->>'avgCycleTimeWithoutAi',
            'cycleTimeImpactPercentage', impact_data->'summary'->>'cycleTimeImpactPercentage',
            'avgCommitsWithAi', impact_data->'summary'->>'avgCommitsWithAi',
            'avgCommitsWithoutAi', impact_data->'summary'->>'avgCommitsWithoutAi'
        ) INTO engineer_metrics;

        RETURN NEXT engineer_metrics;
    END LOOP;

    RETURN;
END;
$$ LANGUAGE plpgsql;