#!/usr/bin/env bash
# Quick tester for vibex AI functions (demo)
set -euo pipefail
# NOTE: Some Edge Functions were used previously. Upload presign helpers are deprecated.
# This script targets AI demo functions; adjust PROJECT_HOST if you deploy functions elsewhere.
PROJECT_HOST="https://jnkzbfqrwkgfiyxvwrug.functions.supabase.co"
APIKEY="${1:-<your_api_key>}"

if [[ "$APIKEY" == "<your_api_key>" ]]; then
  echo "Usage: $0 <apikey>"
  exit 1
fi

echo "POST -> suggestCaptions"
curl -sS -X POST "$PROJECT_HOST/suggestCaptions" -H "Content-Type: application/json" -H "apikey: $APIKEY" -d '{"prompt":"Short funny caption","count":2}' | jq .

echo
echo "POST -> sixd (enqueue)"
ENQ=$(curl -sS -X POST "$PROJECT_HOST/sixd" -H "Content-Type: application/json" -H "apikey: $APIKEY" -d '{"preset":"funny"}')
echo "$ENQ" | jq .
JOBID=$(echo "$ENQ" | jq -r .jobId)

if [[ "$JOBID" == "null" || -z "$JOBID" ]]; then
  echo "No jobId returned; aborting."
  exit 1
fi

echo
sleep 1
echo "Polling status (demo: add ?ready=1 to get a completed result)"
for i in {1..6}; do
  STATUS=$(curl -sS "$PROJECT_HOST/sixd/status/$JOBID" -H "apikey: $APIKEY" )
  echo "$STATUS" | jq .
  sleep 1
done

echo
echo "Force-ready check (demo):"
curl -sS "$PROJECT_HOST/sixd/status/$JOBID?ready=1" -H "apikey: $APIKEY" | jq .
