#!/usr/bin/env bash
# Runs a SQL file against Redshift Serverless through the Redshift Data API.
# The Data API is an AWS API call, so the workgroup needs no inbound network access.
#
# Usage:  scripts/run_sql.sh <file.sql> [--expect-rows]
# Env:    WORKGROUP, DATABASE, SECRET_ARN (from terraform outputs) and AWS credentials
#
# --expect-rows  fail unless the query's first value is greater than zero
#                (used for the post-deploy smoke test).
#
# Statements are split on semicolons and full-line "--" comments are skipped,
# so keep comments on their own lines and avoid semicolons inside strings.
set -euo pipefail

sql_file="${1:?usage: run_sql.sh <file.sql> [--expect-rows]}"
expect_rows="${2:-}"

: "${WORKGROUP:?set WORKGROUP}" "${DATABASE:?set DATABASE}" "${SECRET_ARN:?set SECRET_ARN}"

mapfile -t statements < <(
  grep -v '^[[:space:]]*--' "$sql_file" | tr '\n' ' ' | tr ';' '\n' |
    sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' || true
)

if [[ ${#statements[@]} -eq 0 ]]; then
  echo "No statements found in $sql_file - skipping."
  exit 0
fi

echo "Running ${#statements[@]} statement(s) from $sql_file"

target=(--workgroup-name "$WORKGROUP" --database "$DATABASE" --secret-arn "$SECRET_ARN")

if [[ ${#statements[@]} -eq 1 ]]; then
  id=$(aws redshift-data execute-statement "${target[@]}" \
    --sql "${statements[0]}" --query Id --output text)
else
  # A batch runs its statements in order, as a single transaction.
  id=$(aws redshift-data batch-execute-statement "${target[@]}" \
    --sqls "${statements[@]}" --query Id --output text)
fi

while true; do
  status=$(aws redshift-data describe-statement --id "$id" --query Status --output text)
  case "$status" in
    FINISHED)
      break
      ;;
    FAILED | ABORTED)
      echo "::error::$sql_file $status"
      aws redshift-data describe-statement --id "$id" \
        --query '{Error: Error, SubStatements: SubStatements[].{Status: Status, Error: Error}}' \
        --output json
      exit 1
      ;;
    *)
      sleep 2
      ;;
  esac
done

echo "$sql_file finished."

if [[ "$expect_rows" == "--expect-rows" ]]; then
  value=$(aws redshift-data get-statement-result --id "$id" \
    --query 'Records[0][0].longValue' --output text)
  echo "Smoke test returned: $value"
  if [[ ! "$value" =~ ^[0-9]+$ ]] || ((value == 0)); then
    echo "::error::Smoke test failed: expected a count greater than zero."
    exit 1
  fi
fi
