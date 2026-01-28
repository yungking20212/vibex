#!/usr/bin/env python3
"""
Fix Missing Videos

This script checks recent rows in the `videos` table for video URLs that return
non-200 responses, tries to locate the underlying storage object, and optionally
updates the DB row to use the public storage URL.

Usage:
  SUPABASE_URL=https://<project>.supabase.co \
  SUPABASE_ANON_KEY=<anon_key> \
  SUPABASE_SERVICE_ROLE=<service_role_key> \
  python3 scripts/fix_missing_videos.py --limit 200

- If `SUPABASE_SERVICE_ROLE` is provided the script will perform a PATCH
  update to the `videos` row to set `video_url` to the public URL found.
- If `SUPABASE_SERVICE_ROLE` is omitted the script will only print candidates
  and suggested actions.

Output: CSV lines with: id,http_code,video_url,list_count,list_preview,action
"""

import os
import sys
import json
import shlex
import subprocess
import argparse
from urllib.parse import urlparse, unquote


def run(cmd):
    proc = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


def http_status(url):
    # Use curl for a reliable status probe
    code, out, err = run(f"curl -s -o /dev/null -w '%{{http_code}}' '{url}'")
    if code != 0:
        return f"err:{err.strip()}"
    return out.strip()


def storage_list(supabase_url, key, prefix):
    # Call the storage list endpoint for bucket `videos`
    api = f"{supabase_url}/storage/v1/object/list/videos?prefix={shlex.quote(prefix)}"
    cmd = f"curl -s -H 'apikey: {key}' -H 'Authorization: Bearer {key}' '{api}'"
    code, out, err = run(cmd)
    if code != 0:
        return None
    try:
        return json.loads(out)
    except Exception:
        return None


def fetch_videos(supabase_url, key, limit):
    api = f"{supabase_url}/rest/v1/videos?select=id,video_url&order=created_at.desc&limit={limit}"
    cmd = f"curl -s -H 'apikey: {key}' -H 'Authorization: Bearer {key}' '{api}'"
    code, out, err = run(cmd)
    if code != 0:
        print(f"Failed to fetch videos: {err}", file=sys.stderr)
        sys.exit(1)
    # The REST response should be a JSON array, but some environments wrap
    # the array as a JSON-encoded string. Handle both cases gracefully.
    try:
        parsed = json.loads(out)
        # Normalize parsed result into a list of dicts.
        if isinstance(parsed, str):
            try:
                parsed = json.loads(parsed)
            except Exception:
                pass

        if isinstance(parsed, list):
            normalized = []
            for item in parsed:
                if isinstance(item, str):
                    try:
                        normalized.append(json.loads(item))
                    except Exception:
                        # keep original string if it cannot be parsed
                        normalized.append(item)
                else:
                    normalized.append(item)
            return normalized
        return parsed
    except Exception as e:
        # Try a best-effort cleanup: sometimes the API returns a quoted JSON string
        s = out.strip()
        if s.startswith('"') and s.endswith('"'):
            try:
                inner = json.loads(s)
                return json.loads(inner) if isinstance(inner, str) else inner
            except Exception:
                pass
        print(f"Failed to parse videos response: {e}", file=sys.stderr)
        sys.exit(1)


def infer_prefix_from_url(url):
    # Try to infer the storage object prefix (directory without filename)
    # Accept patterns like /object/public/videos/<path>/<file> or /object/videos/<path>/<file>
    try:
        p = urlparse(url)
        path = unquote(p.path)
    except Exception:
        path = url
    if "/object/public/videos/" in path:
        rest = path.split("/object/public/videos/", 1)[1]
        parts = rest.split("/")
        if len(parts) >= 2:
            return "/".join(parts[:-1])
    if "/object/videos/" in path:
        rest = path.split("/object/videos/", 1)[1]
        parts = rest.split("/")
        if len(parts) >= 2:
            return "/".join(parts[:-1])
    # fallback: find 'videos/' and take the rest
    if "videos/" in path:
        rest = path.split("videos/", 1)[1].split("?", 1)[0]
        parts = rest.split("/")
        if len(parts) >= 2:
            return "/".join(parts[:-1])
    return None


def update_video_url(supabase_url, service_key, video_id, new_url):
    api = f"{supabase_url}/rest/v1/videos?id=eq.{video_id}"
    data = json.dumps({"video_url": new_url})
    # Use service role for the update
    cmd = (
        f"curl -s -X PATCH -H 'apikey: {service_key}' -H 'Authorization: Bearer {service_key}' "
        f"-H 'Content-Type: application/json' -d '{data}' '{api}' -w '%{{http_code}}' -o /dev/null"
    )
    code, out, err = run(cmd)
    if code != 0:
        return False, err.strip()
    # out contains the HTTP status
    return out.strip().startswith("2"), ""


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=200)
    args = parser.parse_args()

    SUPABASE_URL = os.environ.get("SUPABASE_URL")
    ANON_KEY = os.environ.get("SUPABASE_ANON_KEY")
    SERVICE_ROLE = os.environ.get("SUPABASE_SERVICE_ROLE")

    if not SUPABASE_URL or not ANON_KEY:
        print("Please set SUPABASE_URL and SUPABASE_ANON_KEY environment variables.")
        sys.exit(1)

    videos = fetch_videos(SUPABASE_URL, ANON_KEY, args.limit)

    print("id,http_code,video_url,list_count,list_preview,action")

    for row in videos:
        # Normalize row in case it's a JSON-encoded string
        if isinstance(row, str):
            try:
                parsed_row = json.loads(row)
                # double-encoded string
                if isinstance(parsed_row, str):
                    parsed_row = json.loads(parsed_row)
                row = parsed_row
            except Exception:
                # leave as-is; downstream will handle missing fields
                pass

        vid = None
        url = None
        if isinstance(row, dict):
            vid = row.get("id")
            url = row.get("video_url")
        else:
            # fallback: try to parse if possible
            try:
                rr = json.loads(row)
                vid = rr.get("id")
                url = rr.get("video_url")
            except Exception:
                vid = str(row)
                url = None
        if not url:
            print(f"{vid},no_url,,0,,no_url")
            continue
        code = http_status(url)
        if code == '200':
            print(f"{vid},200,{url},0,,ok")
            continue
        prefix = infer_prefix_from_url(url)
        if not prefix:
            print(f"{vid},{code},{url},0,,no_prefix_found")
            continue
        listed = storage_list(SUPABASE_URL, ANON_KEY, prefix)
        if listed is None:
            print(f"{vid},{code},{url},err,list_failed")
            continue
        count = len(listed)
        preview = ";".join([o.get('name','') for o in listed[:3]])
        if count == 0:
            print(f"{vid},{code},{url},{count},{preview},object_missing")
            continue
        # construct a public URL for the first matching object (choose name)
        name = listed[0].get('name')
        # prefix may be '.' or empty; handle joins
        if prefix in (".", ""):
            object_path = name
        else:
            object_path = f"{prefix}/{name}" if prefix else name
        public_url = f"{SUPABASE_URL}/storage/v1/object/public/videos/{object_path}"
        action = "found_public_url"
        updated = False
        if SERVICE_ROLE:
            ok, err = update_video_url(SUPABASE_URL, SERVICE_ROLE, vid, public_url)
            if ok:
                action = "updated_to_public_url"
                updated = True
            else:
                action = f"update_failed:{err}"
        print(f"{vid},{code},{url},{count},{preview},{action}")


if __name__ == '__main__':
    main()
