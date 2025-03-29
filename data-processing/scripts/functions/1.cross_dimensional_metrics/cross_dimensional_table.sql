CREATE TABLE cross_dimensional_metrics (
    dimension_key TEXT PRIMARY KEY,
    dimension_type TEXT NOT NULL,
    dimension_values JSON NOT NULL,
    total_issues INTEGER NOT NULL,
    ai_metrics JSON NOT NULL,
    last_calculated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);