CREATE TABLE IF NOT EXISTS engineer_metrics_materialized (
    engineer_id INTEGER PRIMARY KEY,
    total_issues_analyzed INTEGER NOT NULL,
    issues_with_ai INTEGER NOT NULL,
    issues_without_ai INTEGER NOT NULL,
    avg_cycle_time_with_ai FLOAT NOT NULL,
    avg_cycle_time_without_ai FLOAT NOT NULL,
    cycle_time_impact_percentage FLOAT NOT NULL,
    avg_commits_with_ai FLOAT NOT NULL,
    avg_commits_without_ai FLOAT NOT NULL,
    efficiency_score FLOAT NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metrics_json JSON NOT NULL
) WITH (autovacuum_enabled = true, toast.autovacuum_enabled = true);

