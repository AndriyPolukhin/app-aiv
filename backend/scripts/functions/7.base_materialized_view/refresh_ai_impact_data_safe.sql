CREATE OR REPLACE FUNCTION refresh_ai_impact_data_safe(
    p_batch_size INTEGER DEFAULT 100,
    p_max_retries INTEGER DEFAULT 2,
    p_incremental BOOLEAN DEFAULT TRUE
)
RETURNS VOID AS $$
DECLARE
    last_refresh TIMESTAMP;
    processed_count INTEGER := 0;
    total_issues INTEGER;
    retry_count INTEGER;
    success BOOLEAN;
    error_message TEXT;
    batch_start_time TIMESTAMP;
BEGIN
    -- Set conservative memory limits
    SET LOCAL work_mem = '32MB';
    SET LOCAL maintenance_work_mem = '64MB';
    SET LOCAL temp_buffers = '8MB';

    -- Get last refresh time for incremental mode
    IF p_incremental THEN
        SELECT MAX(last_updated) INTO last_refresh FROM ai_impact_summary;
    ELSE
        last_refresh := NULL;
    END IF;

    -- Full refresh if no existing data or forced
    IF last_refresh IS NULL THEN
        RAISE NOTICE 'Performing full refresh of AI impact data';

        -- Clear existing data in batches if large
        PERFORM batch_delete('ai_impact_summary', p_batch_size);

        -- Get total count for progress tracking
        SELECT COUNT(*) INTO total_issues
        FROM jira_issues
        WHERE resolution_date IS NOT NULL;

        RAISE NOTICE 'Processing % resolved issues', total_issues;

        -- Process in batches for large datasets
        FOR retry_count IN 0..p_max_retries LOOP
            BEGIN
                -- Full refresh in one transaction
                WITH commit_data AS (
                    SELECT
                        c.commit_id,
                        c.engineer_id,
                        c.jira_issue_id,
                        c.repo_id,
                        c.commit_date,
                        c.ai_used,
                        c.lines_of_code,
                        t.team_id
                    FROM
                        commits c
                    LEFT JOIN LATERAL (
                        SELECT team_id FROM teams
                        WHERE c.engineer_id = ANY(string_to_array(engineer_ids, ',')::int[])
                        LIMIT 1  -- Just need one team per engineer
                    ) t ON true
                ),
                issue_data AS MATERIALIZED (
                    SELECT
                        ji.issue_id,
                        ji.project_id,
                        ji.author_id,
                        ji.category,
                        COUNT(fc.commit_id) AS total_commits,
                        COUNT(fc.commit_id) FILTER (WHERE fc.ai_used) AS ai_commits,
                        COUNT(fc.commit_id) FILTER (WHERE NOT fc.ai_used) AS non_ai_commits,
                        BOOL_OR(fc.ai_used) AS has_ai_commits,
                        days_between(MIN(fc.commit_date), ji.resolution_date) AS cycle_time,
                        array_agg(DISTINCT fc.team_id) FILTER (WHERE fc.team_id IS NOT NULL) AS team_ids
                    FROM
                        jira_issues ji
                    JOIN commit_data fc ON ji.issue_id = fc.jira_issue_id
                    WHERE
                        ji.resolution_date IS NOT NULL
                    GROUP BY
                        ji.issue_id, ji.project_id, ji.author_id, ji.category, ji.resolution_date
                )
                INSERT INTO ai_impact_summary
                SELECT
                    issue_id,
                    project_id,
                    author_id,
                    category,
                    total_commits,
                    ai_commits,
                    non_ai_commits,
                    cycle_time,
                    has_ai_commits,
                    team_ids,
                    NOW()
                FROM issue_data;

                processed_count := total_issues;
                EXIT;  -- Success, exit retry loop

            EXCEPTION WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;
                IF retry_count < p_max_retries THEN
                    RAISE WARNING 'Retry %/% for full refresh: %',
                        retry_count+1, p_max_retries, error_message;
                    PERFORM pg_sleep(1);  -- Wait before retry
                ELSE
                    RAISE EXCEPTION 'Failed full refresh after % attempts: %',
                        p_max_retries, error_message;
                END IF;
            END;
        END LOOP;
    ELSE
        -- Incremental refresh
        RAISE NOTICE 'Performing incremental refresh of AI impact data since %', last_refresh;

        -- Process in batches for incremental updates
        FOR retry_count IN 0..p_max_retries LOOP
            BEGIN
                batch_start_time := clock_timestamp();

                -- Create temporary table with new/updated data
                CREATE TEMPORARY TABLE temp_new_impact ON COMMIT DROP AS
                WITH commit_data AS (
                    SELECT
                        c.commit_id,
                        c.engineer_id,
                        c.jira_issue_id,
                        c.repo_id,
                        c.commit_date,
                        c.ai_used,
                        c.lines_of_code,
                        t.team_id
                    FROM
                        commits c
                    LEFT JOIN LATERAL (
                        SELECT team_id FROM teams
                        WHERE c.engineer_id = ANY(string_to_array(engineer_ids, ',')::int[])
                        LIMIT 1
                    ) t ON true
                    WHERE c.commit_date > last_refresh
                ),
                issue_data AS MATERIALIZED (
                    SELECT
                        ji.issue_id,
                        ji.project_id,
                        ji.author_id,
                        ji.category,
                        COUNT(fc.commit_id) AS total_commits,
                        COUNT(fc.commit_id) FILTER (WHERE fc.ai_used) AS ai_commits,
                        COUNT(fc.commit_id) FILTER (WHERE NOT fc.ai_used) AS non_ai_commits,
                        BOOL_OR(fc.ai_used) AS has_ai_commits,
                        days_between(MIN(fc.commit_date), ji.resolution_date) AS cycle_time,
                        array_agg(DISTINCT fc.team_id) FILTER (WHERE fc.team_id IS NOT NULL) AS team_ids
                    FROM
                        jira_issues ji
                    JOIN commit_data fc ON ji.issue_id = fc.jira_issue_id
                    WHERE
                        ji.resolution_date IS NOT NULL
                    GROUP BY
                        ji.issue_id, ji.project_id, ji.author_id, ji.category, ji.resolution_date
                )
                SELECT
                    issue_id,
                    project_id,
                    author_id,
                    category,
                    total_commits,
                    ai_commits,
                    non_ai_commits,
                    cycle_time,
                    has_ai_commits,
                    team_ids
                FROM issue_data;

                -- Get count of records to process
                SELECT COUNT(*) INTO processed_count FROM temp_new_impact;
                RAISE NOTICE 'Found % updated issues to process', processed_count;

                -- Delete existing records that will be updated
                DELETE FROM ai_impact_summary
                WHERE issue_id IN (SELECT issue_id FROM temp_new_impact);

                -- Insert the new/updated records
                INSERT INTO ai_impact_summary
                SELECT
                    issue_id,
                    project_id,
                    author_id,
                    category,
                    total_commits,
                    ai_commits,
                    non_ai_commits,
                    cycle_time,
                    has_ai_commits,
                    team_ids,
                    NOW()
                FROM temp_new_impact;

                RAISE NOTICE 'Processed % issues in % ms',
                    processed_count,
                    EXTRACT(MILLISECONDS FROM (clock_timestamp() - batch_start_time));

                EXIT;  -- Success, exit retry loop

            EXCEPTION WHEN OTHERS THEN
                GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;
                IF retry_count < p_max_retries THEN
                    RAISE WARNING 'Retry %/% for incremental refresh: %',
                        retry_count+1, p_max_retries, error_message;
                    PERFORM pg_sleep(1);  -- Wait before retry
                ELSE
                    RAISE EXCEPTION 'Failed incremental refresh after % attempts: %',
                        p_max_retries, error_message;
                END IF;
            END;
        END LOOP;
    END IF;

    -- Cleanup memory settings
    RESET work_mem;
    RESET maintenance_work_mem;
    RESET temp_buffers;
END;
$$ LANGUAGE plpgsql;

-- Helper function for batch deletes
CREATE OR REPLACE FUNCTION batch_delete(p_table_name TEXT, p_batch_size INTEGER)
RETURNS VOID AS $$
DECLARE
    rows_deleted INTEGER;
BEGIN
    LOOP
        EXECUTE format('DELETE FROM %I WHERE ctid IN (SELECT ctid FROM %I LIMIT %s)',
                      p_table_name, p_table_name, p_batch_size);
        GET DIAGNOSTICS rows_deleted = ROW_COUNT;
        EXIT WHEN rows_deleted = 0;
        RAISE NOTICE 'Deleted % rows from %', rows_deleted, p_table_name;
        COMMIT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;