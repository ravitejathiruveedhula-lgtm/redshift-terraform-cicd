-- Smoke test: the table exists and holds rows.
-- run_sql.sh --expect-rows fails the deploy if this returns 0.
select count(*) from ops.pipeline_runs;
