#!/usr/bin/env bash

if [ "${EUID}" -ne 0 ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# gets the progress of a running SMART test as a string, or outputs nothing if
# no test is currently running.
function get_smart_progress {
  local drive="${1}"

  smartctl -a "${drive}" | \
    grep 'of test remaining' | \
    sed 's/^[[:blank:]]*//' | \
    sed 's/\.$//'
}

# run a SMART test in offline mode and wait until it's done, printing remaining
# progress every minute.
function smart_test {
  local drive="${1}"
  local test_name="${2}"

  echo "Running ${test_name} SMART test on $(date):"
  smartctl --test=${test_name} "${drive}"

  # wait for the progress remaining to disappear, signaling the end of the test
  local result="NONEMPTY"
  while [ -n "${result}" ]; do
    result="$(get_smart_progress "${drive}")"

    echo "> ${result}"
    sleep 60
  done
}

# run a succession of SMART tests and badblocks on a drive, and output the final
# results when complete.
function burnin {
  local drive=$1

  echo
  echo "Starting burn-in test for ${drive} on $(date):"

  echo
  echo "Aborting any running SMART tests on ${drive}:"
  smartctl -X "${drive}"

  echo
  echo "Current SMART status for ${drive}:"
  smartctl -a "${drive}"

  echo
  echo "Putting kernel in raw mode"
  sysctl kern.geom.debugflags=0x10

  echo
  smart_test "${drive}" "short"

  echo
  smart_test "${drive}" "conveyance"

  echo
  smart_test "${drive}" "long"

  echo
  echo "Running destructive badblocks test on $(date):"
  # badblocks -ws "${drive}"

  echo
  smart_test "${drive}" "long"

  echo
  echo "Burn-in test completed on $(date)"

  echo
  echo "Burn-in test results:"
  smartctl -a "${drive}"
}

if [ -z "${1}" ]; then
  echo "Drive required as first argument"
  exit 1
fi

# run the burn-in and see how long it takes, just for fun
time burnin "${1}"