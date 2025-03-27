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

    -- Refresh data if needed
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