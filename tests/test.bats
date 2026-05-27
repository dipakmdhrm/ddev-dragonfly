#!/usr/bin/env bats

# Tests for ddev-dragonfly addon

setup() {
  export DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )/.."
  export TESTDIR=$(mktemp -d -t testdragonfly-XXXXXX)
  export PROJNAME=test-dragonfly
  export DDEV_NON_INTERACTIVE=true

  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true
  cd "${TESTDIR}"
}

health_checks() {
  # Verify dragonfly container is running
  ddev describe | grep -q dragonfly

  # Verify PING
  result=$(ddev redis-cli PING)
  [ "$result" = "PONG" ]

  # Verify SET/GET
  ddev redis-cli SET testkey hello
  result=$(ddev redis-cli GET testkey)
  [ "$result" = "hello" ]

  # Verify FLUSHALL
  ddev dragonfly-flush
  result=$(ddev redis-cli DBSIZE)
  echo "$result" | grep -q "0"
}

teardown() {
  cd "${TESTDIR}" || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1
  [ "${TESTDIR}" != "" ] && rm -rf "${TESTDIR}"
}

# bats test_tags=generic
@test "generic project" {
  cd "${TESTDIR}"
  echo "# Testing generic project in ${TESTDIR}" >&3
  ddev config --project-name="${PROJNAME}"
  ddev start -y >/dev/null
  ddev add-on get "${DIR}"
  ddev restart

  health_checks
}

# bats test_tags=drupal10
@test "drupal10 project" {
  cd "${TESTDIR}"
  echo "# Testing drupal10 project in ${TESTDIR}" >&3
  ddev config --project-name="${PROJNAME}" --project-type=drupal10 --docroot=web
  mkdir -p web/sites/default
  # Create a minimal settings.php so the setup script can append to it
  echo '<?php' > web/sites/default/settings.php
  ddev start -y >/dev/null
  ddev add-on get "${DIR}"
  ddev restart

  health_checks

  # Verify Drupal settings file was copied
  [ -f "${TESTDIR}/web/sites/default/settings.ddev.dragonfly.php" ]

  # Verify include line was added to settings.php
  grep -q 'settings.ddev.dragonfly.php' "${TESTDIR}/web/sites/default/settings.php"
}

# bats test_tags=drupal11
@test "drupal11 project" {
  cd "${TESTDIR}"
  echo "# Testing drupal11 project in ${TESTDIR}" >&3
  ddev config --project-name="${PROJNAME}" --project-type=drupal11 --docroot=web
  mkdir -p web/sites/default
  echo '<?php' > web/sites/default/settings.php
  ddev start -y >/dev/null
  ddev add-on get "${DIR}"
  ddev restart

  health_checks

  # Verify Drupal settings file was copied
  [ -f "${TESTDIR}/web/sites/default/settings.ddev.dragonfly.php" ]

  # Verify include line was added to settings.php
  grep -q 'settings.ddev.dragonfly.php' "${TESTDIR}/web/sites/default/settings.php"
}
