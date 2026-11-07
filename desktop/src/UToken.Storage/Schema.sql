-- Schema SQLite cục bộ (ADR-0001). Mọi bảng chỉ chứa số và mã băm, không chứa nội dung.
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS schema_info (version INTEGER NOT NULL);

CREATE TABLE IF NOT EXISTS source_files (
  path_hash       TEXT PRIMARY KEY,
  provider        TEXT NOT NULL,
  size            INTEGER NOT NULL,
  mtime           INTEGER NOT NULL,
  read_offset     INTEGER NOT NULL DEFAULT 0,
  completed       INTEGER NOT NULL DEFAULT 0,
  parser_version  TEXT NOT NULL,
  last_ok_at      TEXT
);

CREATE TABLE IF NOT EXISTS sessions (
  provider          TEXT NOT NULL,
  session_id        TEXT NOT NULL,
  project_key       TEXT,
  is_side           INTEGER NOT NULL DEFAULT 0,
  parent_session_id TEXT,
  started_at        TEXT,
  last_event_at     TEXT,
  PRIMARY KEY (provider, session_id)
);

CREATE TABLE IF NOT EXISTS usage_events (
  provider         TEXT NOT NULL,
  source_event_id  TEXT NOT NULL,
  session_id       TEXT NOT NULL,
  turn_id          TEXT,
  task_id          TEXT,
  model            TEXT NOT NULL,
  effort           TEXT,
  occurred_at      TEXT NOT NULL,
  input            INTEGER NOT NULL,
  cached           INTEGER NOT NULL,
  cache_write      INTEGER NOT NULL,
  cache_write_1h   INTEGER,
  output           INTEGER NOT NULL,
  thinking         INTEGER,
  duration_ms      INTEGER,
  status           TEXT NOT NULL DEFAULT 'ok',
  is_side          INTEGER NOT NULL DEFAULT 0,
  project_key      TEXT,
  cost_micro       INTEGER,
  pricing_version  TEXT,
  parser_version   TEXT NOT NULL,
  PRIMARY KEY (provider, source_event_id),
  CHECK (cached + cache_write <= input),
  CHECK (thinking IS NULL OR thinking <= output)
);
CREATE INDEX IF NOT EXISTS ix_events_time    ON usage_events (occurred_at);
CREATE INDEX IF NOT EXISTS ix_events_session ON usage_events (session_id);
CREATE INDEX IF NOT EXISTS ix_events_model   ON usage_events (provider, model, occurred_at);

CREATE TABLE IF NOT EXISTS task_outcomes (
  task_id                  TEXT PRIMARY KEY,
  provider                 TEXT NOT NULL,
  session_id               TEXT NOT NULL,
  model                    TEXT NOT NULL,
  effort                   TEXT,
  project_key              TEXT,
  task_group               TEXT NOT NULL,
  started_at               TEXT NOT NULL,
  ended_at                 TEXT,
  turns                    INTEGER NOT NULL,
  redo_turns               INTEGER NOT NULL DEFAULT 0,
  commands_total           INTEGER,
  commands_failed          INTEGER,
  max_consecutive_failures INTEGER,
  test_runs                INTEGER,
  last_test_passed         INTEGER,
  files_changed            INTEGER,
  turn_error               INTEGER NOT NULL DEFAULT 0,
  aborted                  INTEGER NOT NULL DEFAULT 0,
  outcome_state            TEXT NOT NULL,
  cost_micro               INTEGER,
  total_tokens             INTEGER NOT NULL,
  context_growth           REAL,
  state                    TEXT NOT NULL DEFAULT 'open'
);
CREATE INDEX IF NOT EXISTS ix_tasks_setup ON task_outcomes (provider, model, effort, task_group, ended_at);

CREATE TABLE IF NOT EXISTS daily_local (
  date        TEXT PRIMARY KEY,
  json        TEXT NOT NULL,
  dirty       INTEGER NOT NULL DEFAULT 1,
  updated_at  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_queue (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  doc_path       TEXT NOT NULL,
  payload_json   TEXT NOT NULL,
  attempts       INTEGER NOT NULL DEFAULT 0,
  next_retry_at  TEXT,
  created_at     TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pricing (
  pricing_version         TEXT NOT NULL,
  provider                TEXT NOT NULL,
  model                   TEXT NOT NULL,
  input_per_mtok          TEXT NOT NULL,
  cached_input_per_mtok   TEXT NOT NULL,
  cache_write_per_mtok    TEXT,
  cache_write_1h_per_mtok TEXT,
  output_per_mtok         TEXT NOT NULL,
  effective_from          TEXT NOT NULL,
  PRIMARY KEY (pricing_version, provider, model)
);

CREATE TABLE IF NOT EXISTS pricing_tier (
  pricing_version       TEXT NOT NULL,
  provider              TEXT NOT NULL,
  model                 TEXT NOT NULL,
  context_above         INTEGER NOT NULL,
  input_per_mtok        TEXT NOT NULL,
  cached_input_per_mtok TEXT NOT NULL,
  cache_write_per_mtok  TEXT,
  output_per_mtok       TEXT NOT NULL,
  PRIMARY KEY (pricing_version, provider, model, context_above)
);
