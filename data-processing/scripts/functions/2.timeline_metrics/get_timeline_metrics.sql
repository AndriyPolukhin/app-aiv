CREATE OR REPLACE FUNCTION get_timeline_metrics(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_interval TEXT DEFAULT 'month',
    p_max_age_hours INTEGER DEFAULT 24,
    p_force_refresh BOOLEAN DEFAULT FALSE
)
RETURNS JSON AS $$
DECLARE
    refresh_cutoff TIMESTAMP;
    result_data JSON;
BEGIN
    refresh_cutoff := CURRENT_TIMESTAMP - (p_max_age_hours || ' hours')::INTERVAL;

    -- Refresh data if needed
    IF p_force_refresh OR (
        SELECT COUNT(*)
        FROM timeline_metrics_materialized
        WHERE time_period BETWEEN COALESCE(p_start_date, '1900-01-01'::DATE) AND COALESCE(p_end_date, CURRENT_DATE)
        AND last_calculated >= refresh_cutoff
    ) = 0 THEN
        PERFORM refresh_timeline_metrics(p_start_date, p_end_date, p_interval);
    END IF;

    -- Retrieve and return materialized data
    SELECT json_build_object(
        'interval', p_interval,
        'data', json_agg(
            json_build_object(
                'period', time_period,
                'totalIssues', total_issues,
                'aiAssistedIssues', ai_assisted_issues,
                'nonAiAssistedIssues', non_ai_assisted_issues,
                'avgCycleTimeWithAi', avg_cycle_time_with_ai,
                'avgCycleTimeWithoutAi', avg_cycle_time_without_ai,
                'cycleTimeImpactPercentage', cycle_time_impact_percentage,
                'aiAdoptionPercentage', ai_adoption_percentage,
                'details', metrics_json
            ) ORDER BY time_period
        )
    ) INTO result_data
    FROM timeline_metrics_materialized
    WHERE time_period BETWEEN COALESCE(p_start_date, '1900-01-01'::DATE) AND COALESCE(p_end_date, CURRENT_DATE);

    RETURN result_data;
END;
$$ LANGUAGE plpgsql;