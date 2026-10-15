-- 002: sample rows for the smoke test and for practice queries.
-- Delete-then-insert keeps it idempotent: rerunning never duplicates rows.
delete from ops.pipeline_runs
where pipeline_name in ('customer_daily_load', 'claims_hourly_load');

insert into ops.pipeline_runs (pipeline_name, status, rows_loaded, started_at, finished_at)
values
    ('customer_daily_load', 'SUCCESS', 125000, dateadd(hour, -26, getdate()), dateadd(hour, -25, getdate())),
    ('claims_hourly_load', 'FAILED', 0, dateadd(hour, -2, getdate()), dateadd(hour, -2, getdate()));
