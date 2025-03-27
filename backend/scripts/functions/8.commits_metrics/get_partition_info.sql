CREATE OR REPLACE FUNCTION get_partition_info()
RETURNS TABLE (
    partition_name text,
    schema_name text,
    from_date date,
    to_date date,
    row_count bigint,
    size text
) AS $$
BEGIN
    RETURN QUERY
    WITH partition_info AS (
        SELECT
            child.relname AS partition_name,
            nmsp_child.nspname AS schema_name,
            pg_get_expr(c.conbin, c.conrelid) AS constraint_def
        FROM pg_inherits
        JOIN pg_class parent ON pg_inherits.inhparent = parent.oid
        JOIN pg_class child ON pg_inherits.inhrelid = child.oid
        JOIN pg_namespace nmsp_parent ON nmsp_parent.oid = parent.relnamespace
        JOIN pg_namespace nmsp_child ON nmsp_child.oid = child.relnamespace
        JOIN pg_constraint c ON c.conrelid = child.oid AND c.contype = 'c'
        WHERE parent.relname = 'commits'
    )
    SELECT
        pi.partition_name,
        pi.schema_name,
        (regexp_matches(pi.constraint_def, 'FROM \(\''([0-9-]+)\''\)'))[1]::date AS from_date,
        (regexp_matches(pi.constraint_def, 'TO \(\''([0-9-]+)\''\)'))[1]::date AS to_date,
        (xpath('/row/cnt/text()', query_to_xml(format('SELECT count(*) as cnt FROM %I.%I',pi.schema_name, pi.partition_name),
        false, false, '')))[1]::text::bigint AS row_count,
        pg_size_pretty(pg_total_relation_size(format('%I.%I', pi.schema_name, pi.partition_name))) AS size
    FROM partition_info pi
    ORDER BY from_date;
END;
$$ LANGUAGE plpgsql;