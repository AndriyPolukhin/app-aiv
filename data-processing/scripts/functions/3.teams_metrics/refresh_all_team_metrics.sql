CREATE OR REPLACE FUNCTION refresh_all_team_metrics_safe()
RETURNS VOID AS $$
DECLARE
    team_record RECORD;
BEGIN
    -- Set conservative memory limits
    SET LOCAL work_mem = '16MB';
    SET LOCAL maintenance_work_mem = '32MB';

    FOR team_record IN
        SELECT team_id FROM teams ORDER BY team_id
    LOOP
        BEGIN
            -- Execute with team-specific memory settings
            EXECUTE format('SET LOCAL work_mem = %L',
                CASE
                    WHEN team_record.team_id % 10 = 0 THEN '32MB' -- Extra memory every 10th team
                    ELSE '16MB'
                END);

            PERFORM refresh_team_metrics(p_team_id => team_record.team_id);

            -- Release memory between teams
            PERFORM pg_sleep(0.05);
            RESET work_mem;
        EXCEPTION WHEN OTHERS THEN
            RAISE WARNING 'Team % refresh failed (retrying with reduced memory): %',
                team_record.team_id, SQLERRM;

            -- Retry with minimal memory
            BEGIN
                SET LOCAL work_mem = '8MB';
                PERFORM refresh_team_metrics(p_team_id => team_record.team_id);
            EXCEPTION WHEN OTHERS THEN
                RAISE WARNING 'Team % refresh failed again: %',
                    team_record.team_id, SQLERRM;
            END;
        END;
    END LOOP;
END;
$$ LANGUAGE plpgsql;