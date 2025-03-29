BEGIN;

CREATE TABLE cross_dimensional_metrics (
    dimension_key TEXT PRIMARY KEY,  -- Composite key encoding the dimensions
    dimension_type TEXT NOT NULL,    -- 'team-project', 'engineer-category', etc.
    dimension_values JSON NOT NULL,  -- Stores the actual dimension values
    total_issues INTEGER NOT NULL,
    ai_metrics JSON NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);


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
        total_issues = EXCLUDED.total_issues,
        ai_metrics = EXCLUDED.ai_metrics,
        last_calculated = EXCLUDED.last_calculated;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION get_cross_dimensional_metrics(
    p_dimension_type TEXT,
    p_primary_id INTEGER,
    p_secondary_id INTEGER,
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
    dimension_key TEXT;
    refresh_cutoff TIMESTAMP;
    result_data JSON;
BEGIN
    dimension_key := p_dimension_type || ':' || p_primary_id || ':' || p_secondary_id;
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh data if stale or forced
    IF p_force_refresh OR (
        SELECT COUNT(*)
        FROM cross_dimensional_metrics
        WHERE dimension_key = dimension_key
        AND last_calculated >= refresh_cutoff
    ) = 0 THEN
        PERFORM refresh_cross_dimensional_metrics(p_dimension_type, p_primary_id, p_secondary_id);
    END IF;

    -- Retrieve and return materialized data
    SELECT ai_metrics INTO result_data
    FROM cross_dimensional_metrics
    WHERE dimension_key = dimension_key;

    RETURN result_data;
END;
$$ LANGUAGE plpgsql;


COMMIT;


CREATE INDEX idx_cross_dimensional_metrics_key ON cross_dimensional_metrics(dimension_key);
CREATE INDEX idx_cross_dimensional_metrics_last_calculated ON cross_dimensional_metrics(last_calculated);