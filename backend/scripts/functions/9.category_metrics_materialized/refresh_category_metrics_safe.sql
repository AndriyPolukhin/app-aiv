CREATE OR REPLACE FUNCTION refresh_category_metrics_safe(
    p_batch_size INTEGER DEFAULT 50,
    p_max_retries INTEGER DEFAULT 2
)
RETURNS VOID AS $$
DECLARE
    category_record RECORD;
    processed_count INTEGER := 0;
    total_categories INTEGER;
    retry_count INTEGER;
    success BOOLEAN;
    error_message TEXT;
    category_issue_count INTEGER;
BEGIN
    -- Get total number of categories for progress tracking
    SELECT COUNT(DISTINCT category) INTO total_categories FROM jira_issues;
    RAISE NOTICE 'Starting refresh for % categories in batches of %', total_categories, p_batch_size;

    -- Set conservative memory limits
    SET LOCAL work_mem = '16MB';
    SET LOCAL maintenance_work_mem = '32MB';
    SET LOCAL temp_buffers = '8MB';

    -- Process categories in batches
    FOR category_record IN
        SELECT DISTINCT category FROM jira_issues ORDER BY category
    LOOP
        retry_count := 0;
        success := FALSE;

        -- Get category issue count for memory allocation
        SELECT COUNT(*) INTO category_issue_count
        FROM jira_issues
        WHERE category = category_record.category
        AND resolution_date IS NOT NULL;

        -- Retry logic for each category
        WHILE retry_count <= p_max_retries AND NOT success LOOP
            BEGIN
                -- Adjust memory based on category size
                EXECUTE format('SET LOCAL work_mem = %L',
                    CASE
                        WHEN category_issue_count > 100 THEN '32MB'
                        ELSE '16MB'
                    END);

                -- Execute the refresh
                PERFORM refresh_category_metrics(category_record.category);
                success := TRUE;

                processed_count := processed_count + 1;

                -- Progress notification
                IF processed_count % p_batch_size = 0 THEN
                    RAISE NOTICE 'Processed % of % categories (%)%%',
                        processed_count,
                        total_categories,
                        ROUND((processed_count::numeric/total_categories::numeric)*100, 1);
                END IF;

                -- Small delay to prevent resource contention
                PERFORM pg_sleep(0.05);

            EXCEPTION WHEN OTHERS THEN
                retry_count := retry_count + 1;
                GET STACKED DIAGNOSTICS error_message = MESSAGE_TEXT;

                -- Reduce memory for retry
                SET LOCAL work_mem = '8MB';

                IF retry_count <= p_max_retries THEN
                    RAISE WARNING 'Retry %/% for category %: %',
                        retry_count, p_max_retries, category_record.category, error_message;
                ELSE
                    RAISE WARNING 'Failed to refresh category % after % attempts: %',
                        category_record.category, p_max_retries, error_message;
                END IF;
            END;
        END LOOP;
    END LOOP;

    -- Final cleanup
    RESET work_mem;
    RESET maintenance_work_mem;
    RESET temp_buffers;
    RAISE NOTICE 'Completed refresh for % categories', processed_count;

    -- Update statistics
    ANALYZE category_metrics_materialized;
END;
$$ LANGUAGE plpgsql;