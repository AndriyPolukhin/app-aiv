CREATE OR REPLACE FUNCTION refresh_author_metrics_safe(
    p_batch_size INTEGER DEFAULT 50,
    p_max_retries INTEGER DEFAULT 2
)
RETURNS VOID AS $$
DECLARE
    author_record RECORD;
    processed_count INTEGER := 0;
    total_authors INTEGER;
    retry_count INTEGER;
    success BOOLEAN;
    error_message TEXT;
    author_issue_count INTEGER;
BEGIN
    -- Get total number of authors for progress tracking
    SELECT COUNT(DISTINCT author_id) INTO total_authors FROM jira_issues;
    RAISE NOTICE 'Starting refresh for % authors in batches of %', total_authors, p_batch_size;

    -- Set conservative memory limits
    SET LOCAL work_mem = '64MB';
    SET LOCAL maintenance_work_mem = '128MB';
    SET LOCAL temp_buffers = '8MB';

    -- Process authors in batches
    FOR author_record IN
        SELECT DISTINCT author_id FROM jira_issues ORDER BY author_id
    LOOP
        retry_count := 0;
        success := FALSE;

        -- Get author's issue count for memory allocation
        SELECT COUNT(*) INTO author_issue_count
        FROM jira_issues
        WHERE author_id = author_record.author_id;

        -- Retry logic for each author
        WHILE retry_count <= p_max_retries AND NOT success LOOP
            BEGIN
                -- Adjust memory based on author activity
                EXECUTE format('SET LOCAL work_mem = %L',
                    CASE
                        WHEN author_issue_count > 100 THEN '64MB'
                        ELSE '32MB'
                    END);

                -- Execute the refresh
                PERFORM refresh_author_metrics(p_author_id => author_record.author_id);
                success := TRUE;

                processed_count := processed_count + 1;

                -- Progress notification (simplified RAISE)
                IF processed_count % p_batch_size = 0 THEN
                    RAISE NOTICE 'Processed % of % authors (%)%%',
                        processed_count,
                        total_authors,
                        ROUND((processed_count::numeric/total_authors::numeric)*100, 1);
                END IF;

                -- Small delay to prevent resource contention
                PERFORM pg_sleep(0.05);

            EXCEPTION WHEN OTHERS THEN
                retry_count := retry_count + 1;
                GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;

                -- Reduce memory for retry
                SET LOCAL work_mem = '8MB';

                IF retry_count <= p_max_retries THEN
                    RAISE WARNING 'Retry % of % for author %: %',
                        retry_count, p_max_retries, author_record.author_id, error_message;
                ELSE
                    RAISE WARNING 'Failed to refresh author % after % attempts: %',
                        author_record.author_id, p_max_retries, error_message;
                END IF;
            END;
        END LOOP;
    END LOOP;

    -- Final cleanup
    RESET work_mem;
    RESET maintenance_work_mem;
    RESET temp_buffers;
    RAISE NOTICE 'Completed refresh for % authors', processed_count;

    -- Update statistics
    ANALYZE author_metrics_materialized;
END;
$$ LANGUAGE plpgsql;