#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

ALERT_MSG=""

# IMPORTS
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/alert.sh"
source "${SCRIPT_DIR}/lib/report.sh"
source "${SCRIPT_DIR}/lib/check_disk_free.sh"
source "${SCRIPT_DIR}/lib/check_btrfs.sh"
source "${SCRIPT_DIR}/lib/cleanup_cache.sh"

function main {

	local df_args=""

	# CHECK root
	if [ "${UID}" -ne 0 ]; then
  		echo "This script must be run as root."
  		exit 1
	fi

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

	# CHECK internal dependencies
	for fctn in log alert report check_disk_free check_btrfs cleanup_cache; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	exit 1
    	fi
	done

	# CHECK vars
	for var in STATE_DIR; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			exit 1
		fi
	done

	# SET vars
	CACHE_FILE="${STATE_DIR}/cache.txt"

	# MKDIR state
	if [[ ! -d "${STATE_DIR}" ]]; then
		log "<6> Creating state dir at: ${STATE_DIR}"
		mkdir -p "${STATE_DIR}"
	fi

	# TOUCH cache
	if [[ ! -f "${CACHE_FILE}" ]]; then
		log "<6> Creating cache file at: ${CACHE_FILE}"
		touch "${CACHE_FILE}"
	fi

	# BUILD args
	for type in "${DF_EXCLUDE_TYPES[@]}"; do
		df_args+="--exclude-type=${type} "
	done

	# MAIN
	cleanup_cache
	check_disk_free
	check_btrfs

	# ALERT
	alert "${ALERT_MSG}"

	# REPORT
	report "${REPORT_MSG}"
}

main