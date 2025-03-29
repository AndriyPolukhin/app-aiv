BEGIN;

-- **1. Architectural Domain: Performance Metrics Schema Design**
-- Purpose: Create high-performance, adaptive metrics storage mechanism
CREATE TABLE IF NOT EXISTS author_metrics_materialized (
    author_id INTEGER PRIMARY KEY,
    total_issues INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    efficiency_score FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSONB NOT NULL
) WITH (
    autovacuum_enabled = true,
    toast.autovacuum_enabled = true
);

-- **2. Advanced Metrics Calculation Function**
-- Architectural Goal: Comprehensive performance metric derivation with robust error handling


-- **3. Performance Optimization Indexing**
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_author_metrics_author_id
    ON author_metrics_materialized(author_id);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_author_metrics_last_calculated
    ON author_metrics_materialized(last_calculated);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_author_metrics_efficiency
    ON author_metrics_materialized(efficiency_score);

-- **4. Query Optimization Statistics Gathering**
ANALYZE author_metrics_materialized;

COMMIT;