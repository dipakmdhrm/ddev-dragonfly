#!/usr/bin/env bash

# Plain shell tests for ddev-dragonfly addon.
# Usage: tests/test.sh <generic|drupal10|drupal11>

set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
TESTDIR=$(mktemp -d -t testdragonfly-XXXXXX)
PROJNAME=test-dragonfly
export DDEV_NON_INTERACTIVE=true

cleanup() {
  printf "==> Cleaning up project %s in %s\n" "$PROJNAME" "$TESTDIR"
  cd "$TESTDIR" || true
  ddev delete -Oy "$PROJNAME" >/dev/null 2>&1 || true
  [ -n "$TESTDIR" ] && rm -rf "$TESTDIR"
}
trap cleanup EXIT

health_checks() {
  printf "  Checking dragonfly container is running...\n"
  ddev describe | grep -q dragonfly

  printf "  Checking PING...\n"
  result=$(ddev redis-cli PING)
  if [ "$result" != "PONG" ]; then
    printf "FAIL: expected PONG, got '%s'\n" "$result" >&2
    return 1
  fi

  printf "  Checking SET/GET...\n"
  ddev redis-cli SET testkey hello
  result=$(ddev redis-cli GET testkey)
  if [ "$result" != "hello" ]; then
    printf "FAIL: expected 'hello', got '%s'\n" "$result" >&2
    return 1
  fi

  printf "  Checking FLUSHALL + DBSIZE...\n"
  ddev dragonfly-flush
  result=$(ddev redis-cli DBSIZE)
  if ! echo "$result" | grep -q "0"; then
    printf "FAIL: expected DBSIZE 0, got '%s'\n" "$result" >&2
    return 1
  fi

  printf "  Health checks passed.\n"
}

drupal_settings_checks() {
  printf "  Checking Drupal settings file was copied...\n"
  if [ ! -f "${TESTDIR}/web/sites/default/settings.ddev.dragonfly.php" ]; then
    printf "FAIL: settings.ddev.dragonfly.php not found\n" >&2
    return 1
  fi

  printf "  Checking include line in settings.php...\n"
  if ! grep -q 'settings.ddev.dragonfly.php' "${TESTDIR}/web/sites/default/settings.php"; then
    printf "FAIL: include line not found in settings.php\n" >&2
    return 1
  fi

  printf "  Drupal settings checks passed.\n"
}

run_test() {
  local test_name="$1"
  printf "==> Running test: %s\n" "$test_name"

  cd "$TESTDIR"

  case "$test_name" in
    generic)
      ddev config --project-name="$PROJNAME"
      ;;
    drupal10)
      ddev config --project-name="$PROJNAME" --project-type=drupal10 --docroot=web
      mkdir -p web/sites/default
      echo '<?php' > web/sites/default/settings.php
      ;;
    drupal11)
      ddev config --project-name="$PROJNAME" --project-type=drupal11 --docroot=web
      mkdir -p web/sites/default
      echo '<?php' > web/sites/default/settings.php
      ;;
    *)
      printf "Unknown test: %s\n" "$test_name" >&2
      exit 1
      ;;
  esac

  ddev start -y >/dev/null
  ddev add-on get "$DIR"
  ddev restart

  health_checks

  case "$test_name" in
    drupal10|drupal11)
      drupal_settings_checks
      ;;
  esac

  printf "==> Test '%s' passed.\n" "$test_name"
}

# --- main ---
if [ $# -ne 1 ]; then
  printf "Usage: %s <generic|drupal10|drupal11>\n" "$0" >&2
  exit 1
fi

run_test "$1"
