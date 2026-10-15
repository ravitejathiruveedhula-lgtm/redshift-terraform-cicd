-- 001: schema and table that track data pipeline runs.
-- Every statement is idempotent, so the deploy can safely rerun it each time.
create schema if not exists ops;

create table if not exists ops.pipeline_runs (
    run_id bigint identity(1, 1),
    pipeline_name varchar(100) not null,
    status varchar(20) not null,
    rows_loaded bigint,
    started_at timestamp not null,
    finished_at timestamp
)
diststyle auto
sortkey (started_at);
