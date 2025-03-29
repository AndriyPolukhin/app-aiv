CREATE OR REPLACE FUNCTION refresh_cross_dimensional_metrics_safe(
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
    is_valid BOOLEAN;
    error_message TEXT;
BEGIN
    -- Validate dimension type
    IF p_dimension_type NOT IN ('team-project', 'engineer-project', 'author-project', 'team-engineer') THEN
        RAISE EXCEPTION 'Invalid dimension type: %', p_dimension_type;
    END IF;

    -- Validate IDs are positive integers
    IF p_primary_id IS NULL OR p_primary_id <= 0 OR p_secondary_id IS NULL OR p_secondary_id <= 0 THEN
        RAISE EXCEPTION 'Invalid IDs provided: primary_id=%, secondary_id=%', p_primary_id, p_secondary_id;
    END IF;

    -- Create dimension key and values based on dimension type
    dimension_key := p_dimension_type || ':' || p_primary_id || ':' || p_secondary_id;

    -- Check if the dimension combination exists in the database
    CASE p_dimension_type
        WHEN 'team-project' THEN
            -- Check if team and project exist
            SELECT EXISTS(SELECT 1 FROM teams WHERE id = p_primary_id) AND
                   EXISTS(SELECT 1 FROM projects WHERE id = p_secondary_id)
            INTO is_valid;

            IF NOT is_valid THEN
                RAISE EXCEPTION 'Team % or Project % does not exist', p_primary_id, p_secondary_id;
            END IF;

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
            -- Check if engineer and project exist
            SELECT EXISTS(SELECT 1 FROM engineers WHERE id = p_primary_id) AND
                   EXISTS(SELECT 1 FROM projects WHERE id = p_secondary_id)
            INTO is_valid;

            IF NOT is_valid THEN
                RAISE EXCEPTION 'Engineer % or Project % does not exist', p_primary_id, p_secondary_id;
            END IF;

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
            -- Check if author and project exist
            SELECT EXISTS(SELECT 1 FROM authors WHERE id = p_primary_id) AND
                   EXISTS(SELECT 1 FROM projects WHERE id = p_secondary_id)
            INTO is_valid;

            IF NOT is_valid THEN
                RAISE EXCEPTION 'Author % or Project % does not exist', p_primary_id, p_secondary_id;
            END IF;

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
            -- Check if team and engineer exist
            SELECT EXISTS(SELECT 1 FROM teams WHERE id = p_primary_id) AND
                   EXISTS(SELECT 1 FROM engineers WHERE id = p_secondary_id)
            INTO is_valid;

            IF NOT is_valid THEN
                RAISE EXCEPTION 'Team % or Engineer % does not exist', p_primary_id, p_secondary_id;
            END IF;

            dimension_values := json_build_object(
                'teamId', p_primary_id,
                'engineerId', p_secondary_id
            );
            filter_query := 'SELECT calculate_ai_impact(NULL, NULL, $1, $2)';
            filter_params := json_build_object(
                'p1', p_secondary_id,
                'p2', p_primary_id
            );
    END CASE;

    BEGIN
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

    EXCEPTION WHEN OTHERS THEN
        error_message := SQLERRM;
        RAISE WARNING 'Failed to refresh metrics for %: %', dimension_key, error_message;

        -- Record the error in the metrics table
        INSERT INTO cross_dimensional_metrics (
            dimension_key,
            dimension_type,
            dimension_values,
            total_issues,
            ai_metrics,
            last_calculated,
            error_message
        ) VALUES (
            dimension_key,
            p_dimension_type,
            dimension_values,
            0,
            NULL,
            CURRENT_TIMESTAMP,
            error_message
        )
        ON CONFLICT (dimension_key) DO UPDATE SET
            total_issues = 0,
            ai_metrics = NULL,
            last_calculated = CURRENT_TIMESTAMP,
            error_message = error_message;
    END;
END;
$$ LANGUAGE plpgsql;