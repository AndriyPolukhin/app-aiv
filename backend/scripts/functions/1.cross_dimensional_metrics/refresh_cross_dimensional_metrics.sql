CREATE OR REPLACE FUNCTION refresh_cross_dimensional_metrics(
    p_dimension_type TEXT,
    p_primary_id INTEGER,
    p_secondary_id INTEGER
)
RETURNS VOID AS $$
DECLARE
    dimension_key TEXT;
    dimension_values JSON;
    result_metrics JSON;
    filter_query TEXT;
    filter_params JSON;
BEGIN
    -- Create dimension key and values based on dimension type
    dimension_key := p_dimension_type || ':' || p_primary_id || ':' || p_secondary_id;

    CASE p_dimension_type
        WHEN 'team-project' THEN
            dimension_values := json_build_object(
                'teamId', p_primary_id,
                'projectId', p_secondary_id
            );
            filter_query := 'SELECT calculate_ai_impact($1, NULL, NULL, $2)';
            filter_params := json_build_object(
                'p1', p_secondary_id,
                'p2', p_primary_id
            );

        WHEN 'engineer-project' THEN
            dimension_values := json_build_object(
                'engineerId', p_primary_id,
                'projectId', p_secondary_id
            );
            filter_query := 'SELECT calculate_ai_impact($1, NULL, $2, NULL)';
            filter_params := json_build_object(
                'p1', p_secondary_id,
                'p2', p_primary_id
            );

        WHEN 'author-project' THEN
            dimension_values := json_build_object(
                'authorId', p_primary_id,
                'projectId', p_secondary_id
            );
            filter_query := 'SELECT calculate_ai_impact($1, $2, NULL, NULL)';
            filter_params := json_build_object(
                'p1', p_secondary_id,
                'p2', p_primary_id
            );

        WHEN 'team-engineer' THEN
            dimension_values := json_build_object(
                'teamId', p_primary_id,
                'engineerId', p_secondary_id
            );
            filter_query := 'SELECT calculate_ai_impact(NULL, NULL, $1, $2)';
            filter_params := json_build_object(
                'p1', p_secondary_id,
                'p2', p_primary_id
            );

        ELSE
            RAISE EXCEPTION 'Unsupported dimension type: %', p_dimension_type;
    END CASE;

    -- Execute dynamic query to get metrics
    EXECUTE filter_query
    USING filter_params->>'p1', filter_params->>'p2'
    INTO result_metrics;

    -- Insert or update cross-dimensional metrics
    INSERT INTO cross_dimensional_metrics (
        dimension_key,
        dimension_type,
        dimension_values,
        total_issues,
        ai_metrics,
        last_calculated
    ) VALUES (
        dimension_key,
        p_dimension_type,
        dimension_values,
        (result_metrics->'summary'->>'totalIssuesAnalyzed')::INTEGER,
        result_metrics,
        CURRENT_TIMESTAMP
    )
    ON CONFLICT (dimension_key) DO UPDATE SET
        total_issues = (result_metrics->'summary'->>'totalIssuesAnalyzed')::INTEGER,
        ai_metrics = result_metrics,
        last_calculated = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;