CREATE OR REPLACE FUNCTION refresh_project_metrics_safe()
RETURNS VOID AS $$
DECLARE
    project_record RECORD;
BEGIN
    -- Set conservative memory limits
    SET LOCAL work_mem = '128MB';
    SET LOCAL maintenance_work_mem = '256MB';

    FOR project_record IN
        SELECT project_id FROM projects ORDER BY project_id
    LOOP
        BEGIN
            -- Execute with team-specific memory settings
            EXECUTE format('SET LOCAL work_mem = %L',
                CASE
                    WHEN project_record.project_id % 10 = 0 THEN '256MB' -- Extra memory every 10th engineer
                    ELSE '128MB'
                END);

            PERFORM refresh_project_metrics(p_project_id => project_record.project_id);

            -- Release memory between Engineers
            PERFORM pg_sleep(0.05);
            RESET work_mem;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Project % refresh failed (retrying with reduced memory): %',
                project_record.project_id, SQLERRM;

            -- Retry with minimal memory
            BEGIN
                SET LOCAL work_mem = '64MB';
                PERFORM refresh_project_metrics(p_project_id => project_record.project_id);
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Project % refresh failed again: %',
                    project_record.project_id, SQLERRM;
            END;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;