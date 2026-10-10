#!/usr/bin/env bash
# Cycle the wallpaper in the running shell. Path is the tree that owns this script.
self="$(readlink -f -- "${BASH_SOURCE[0]}")"
export SENTINEL_HOME="$(dirname -- "$(dirname -- "$self")")"
exec "$SENTINEL_HOME/session/sentinel-ctl" wallpaper next
