-- Schema SQLite cục bộ (ADR-0001), phiên bản 2 (PRAGMA user_version).
-- Mọi bảng chỉ chứa số, mã băm và tên thư mục project; không chứa prompt, lệnh hay code.
-- Dữ liệu đều suy ra từ log nên khi đổi phiên bản có thể xóa và quét lại.

CREATE TABLE IF NOT EXISTS source_files (
  path_hash       TEXT PRIMARY KEY,
  provider        TEXT NOT NULL,
  size            INTEGER NOT NULL,
  mtime           INTEGER NOT NULL,
  read_offset     INTEGER NOT NULL DEFAULT 0,
  completed       INTEGER NOT NULL DEFAULT 0,
  parser_version  TEXT NOT NULL,
  ctx_json        TEXT,
  last_ok_at      TEXT
);

CREATE TABLE IF NOT EXISTS projects (
  project_key   TEXT PRIMARY KEY,
  display_name  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS usage_events (
  provider         TEXT NOT NULL,
  source_event_id  TEXT NOT NULL,
  session_id       TEXT NOT NULL,
  turn_id          TEXT,
  model            TEXT NOT NULL,
  effort           TEXT,
  occurred_at      TEXT NOT NULL,   -- UTC, định dạng yyyy-MM-ddTHH:mm:ss.fffZ để so sánh chuỗi được
  input            INTEGER NOT NULL,
  cached           INTEGER NOT NULL,
  cache_write      INTEGER NOT NULL,
  output           INTEGER NOT NULL,
  thinking         INTEGER,
  duration_ms      INTEGER,
  status           TEXT NOT NULL DEFAULT 'ok',
  is_side          INTEGER NOT NULL DEFAULT 0,
  project_key      TEXT,
  parser_version   TEXT NOT NULL,
  PRIMARY KEY (provider, source_event_id),
  CHECK (cached + cache_write <= input),
  CHECK (thinking IS NULL OR thinking <= output)
);
CREATE INDEX IF NOT EXISTS ix_events_time    ON usage_events (occurred_at);
CREATE INDEX IF NOT EXISTS ix_events_turn    ON usage_events (provider, session_id, turn_id);

CREATE TABLE IF NOT EXISTS turns (
  provider                 TEXT NOT NULL,
  session_id               TEXT NOT NULL,
  turn_id                  TEXT NOT NULL,
  started_at               TEXT NOT NULL,
  last_seen_at             TEXT NOT NULL,
  ended_at                 TEXT,
  commands_total           INTEGER NOT NULL,
  commands_failed          INTEGER NOT NULL,
  max_consecutive_failures INTEGER NOT NULL,
  test_runs                INTEGER NOT NULL,
  last_test_passed         INTEGER,
  files_changed            INTEGER NOT NULL,
  turn_error               INTEGER NOT NULL,
  aborted                  INTEGER NOT NULL,
  duration_ms              INTEGER,
  is_side                  INTEGER NOT NULL,
  project_key              TEXT,
  PRIMARY KEY (provider, session_id, turn_id)
);
CREATE INDEX IF NOT EXISTS ix_turns_time ON turns (started_at);

CREATE TABLE IF NOT EXISTS task_outcomes (
  task_id                  TEXT PRIMARY KEY,
  provider                 TEXT NOT NULL,
  session_id               TEXT NOT NULL,
  model                    TEXT NOT NULL,
  effort                   TEXT,
  project_key              TEXT,
  task_group               TEXT NOT NULL,
  started_at               TEXT NOT NULL,
  ended_at                 TEXT NOT NULL,
  turns                    INTEGER NOT NULL,
  requests                 INTEGER NOT NULL,
  redo_turns               INTEGER NOT NULL,
  commands_total           INTEGER NOT NULL,
  commands_failed          INTEGER NOT NULL,
  max_consecutive_failures INTEGER NOT NULL,
  test_runs                INTEGER NOT NULL,
  last_test_passed         INTEGER,
  files_changed            INTEGER NOT NULL,
  turn_error               INTEGER NOT NULL,
  aborted                  INTEGER NOT NULL,
  outcome_state            TEXT NOT NULL,
  cost_micro               INTEGER,
  total_tokens             INTEGER NOT NULL,
  context_growth           REAL,
  state                    TEXT NOT NULL
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
