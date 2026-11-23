#!/bin/sh
home="${PRODUCK_HOME:-$HOME/.produck}"
[ -r "$home/hook-url" ] || exit 0
curl -sS --fail -m 2 -X POST -H @"$home/hook-headers" -H 'content-type: application/json' \
  --data-binary @- "$(cat "$home/hook-url")/hooks/$1/$2" 2>/dev/null || true
