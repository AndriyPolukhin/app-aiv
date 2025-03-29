-- Shared Memory Optimization Procedure
CREATE OR REPLACE PROCEDURE public.process_engineer_metrics(
    OUT p_total_processed INTEGER,
    IN p_max_batch_size INTEGER DEFAULT 100
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_offset INTEGER := 0;
    v_max_engineers INTEGER;
    v_batch_result RECORD;
BEGIN
    -- Total Engineer Count Determination
    SELECT COUNT(*) INTO v_max_engineers FROM engineers;
    p_total_processed := 0;

    -- Iterative Batch Processing
    WHILE v_current_offset < v_max_engineers LOOP
        -- Temporary Result Storage
        CREATE TEMPORARY TABLE IF NOT EXISTS temp_engineer_metrics (
            engineer_metrics JSONB
        ) ON COMMIT DROP;

        -- Batch Processing
        INSERT INTO temp_engineer_metrics
        SELECT engineer_metrics
        FROM get_engineer_metrics(p_max_batch_size, v_current_offset);

        -- Processing Batch Results (Example: Could log or further process)
        GET DIAGNOSTICS p_total_processed = ROW_COUNT;

        -- Offset Increment
        v_current_offset := v_current_offset + p_max_batch_size;

        -- Optional: Explicit Memory Release
        PERFORM pg_sleep(0.1);  -- Brief pause to allow memory release
    END LOOP;
END;
$$;