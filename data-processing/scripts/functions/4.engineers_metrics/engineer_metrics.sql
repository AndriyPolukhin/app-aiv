-- Comprehensive JSON Type Conversion Function
CREATE OR REPLACE FUNCTION public.get_engineer_metrics(
    p_batch_size INTEGER DEFAULT 100,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    engineer_metrics JSONB
) AS $$
DECLARE
    v_max_engineers INTEGER;
BEGIN
    -- Dynamic Range Calculation
    SELECT COUNT(*) INTO v_max_engineers FROM engineers;

    -- Boundary Condition Validation
    IF p_offset >= v_max_engineers THEN
        RAISE NOTICE 'Offset exceeds total engineer count. Returning empty result set.';
        RETURN;
    END IF;

    RETURN QUERY
    WITH engineer_impact_data AS (
        SELECT
            e.id AS engineer_id,
            e.name AS engineer_name,
            -- Advanced Type-Safe JSON Transformation
            COALESCE(
                -- Explicit JSON Object Construction
                jsonb_build_object(
                    'summary', COALESCE(
                        -- Safe Conversion of Potentially Null Result
                        (
                            CASE
                                WHEN calculate_ai_impact(NULL, NULL, e.id, NULL) IS NOT NULL
                                THEN calculate_ai_impact(NULL, NULL, e.id, NULL)
                                ELSE jsonb_build_object()
                            END
                        )->'summary',
                        jsonb_build_object(
                            'totalIssuesAnalyzed', 0,
                            'issuesWithAi', 0,
                            'issuesWithoutAi', 0,
                            'avgCycleTimeWithAi', 0::numeric,
                            'avgCycleTimeWithoutAi', 0::numeric,
                            'cycleTimeImpactPercentage', 0::numeric,
                            'avgCommitsWithAi', 0::numeric,
                            'avgCommitsWithoutAi', 0::numeric
                        )
                    )
                ),
                -- Fallback Default Structure
                jsonb_build_object(
                    'summary', jsonb_build_object(
                        'totalIssuesAnalyzed', 0,
                        'issuesWithAi', 0,
                        'issuesWithoutAi', 0,
                        'avgCycleTimeWithAi', 0::numeric,
                        'avgCycleTimeWithoutAi', 0::numeric,
                        'cycleTimeImpactPercentage', 0::numeric,
                        'avgCommitsWithAi', 0::numeric,
                        'avgCommitsWithoutAi', 0::numeric
                    )
                )
            ) AS impact_result
        FROM engineers e
        ORDER BY e.id
        LIMIT p_batch_size OFFSET p_offset
    )
    SELECT
        jsonb_build_object(
            'engineerId', engineer_id,
            'engineerName', engineer_name,
            'metrics', jsonb_build_object(
                'totalIssuesAnalyzed',
                    COALESCE(
                        (impact_result->'summary'->>'totalIssuesAnalyzed')::INTEGER,
                        0
                    ),
                'issuesWithAi',
                    COALESCE(
                        (impact_result->'summary'->>'issuesWithAi')::INTEGER,
                        0
                    ),
                'issuesWithoutAi',
                    COALESCE(
                        (impact_result->'summary'->>'issuesWithoutAi')::INTEGER,
                        0
                    ),
                'avgCycleTimeWithAi',
                    COALESCE(
                        (impact_result->'summary'->>'avgCycleTimeWithAi')::NUMERIC,
                        0::NUMERIC
                    ),
                'avgCycleTimeWithoutAi',
                    COALESCE(
                        (impact_result->'summary'->>'avgCycleTimeWithoutAi')::NUMERIC,
                        0::NUMERIC
                    ),
                'cycleTimeImpactPercentage',
                    COALESCE(
                        (impact_result->'summary'->>'cycleTimeImpactPercentage')::NUMERIC,
                        0::NUMERIC
                    ),
                'avgCommitsWithAi',
                    COALESCE(
                        (impact_result->'summary'->>'avgCommitsWithAi')::NUMERIC,
                        0::NUMERIC
                    ),
                'avgCommitsWithoutAi',
                    COALESCE(
                        (impact_result->'summary'->>'avgCommitsWithoutAi')::NUMERIC,
                        0::NUMERIC
                    )
            )
        ) AS engineer_metrics
    FROM engineer_impact_data;
END;
$$ LANGUAGE plpgsql;

-- Comprehensive Validation Procedure
CREATE OR REPLACE PROCEDURE public.validate_engineer_metrics_conversion(
    OUT p_validation_status BOOLEAN,
    OUT p_error_message TEXT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_test_result JSONB;
    v_metric_count INTEGER;
BEGIN
    -- Initialize Validation Parameters
    p_validation_status := FALSE;
    p_error_message := '';

    -- Comprehensive Diagnostic Sequence
    BEGIN
        -- Metric Retrieval and Validation
        WITH metric_sample AS (
            SELECT engineer_metrics
            FROM get_engineer_metrics(1, 0)
        )
        SELECT
            COUNT(*),
            FIRST(engineer_metrics) INTO v_metric_count, v_test_result
        FROM metric_sample;

        -- Structural Integrity Checks
        IF v_metric_count = 0 THEN
            RAISE EXCEPTION 'No metrics retrieved';
        END IF;

        -- Type and Structure Validation
        IF jsonb_typeof(v_test_result) != 'object' THEN
            RAISE EXCEPTION 'Invalid JSON structure';
        END IF;

        -- Detailed Metric Validation
        IF NOT (
            v_test_result ? 'engineerId' AND
            v_test_result ? 'engineerName' AND
            v_test_result ? 'metrics'
        ) THEN
            RAISE EXCEPTION 'Missing required JSON keys';
        END IF;

        -- Successful Validation
        p_validation_status := TRUE;
        RAISE NOTICE 'JSON Conversion Validation Successful';

    EXCEPTION
        WHEN OTHERS THEN
            p_validation_status := FALSE;
            p_error_message := SQLERRM;
            RAISE NOTICE 'Validation Failed: %', p_error_message;
    END;
END;
$$;
