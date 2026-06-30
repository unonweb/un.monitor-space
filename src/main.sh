#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

# IMPORTS
source "${SCRIPT_DIR}/lib/log.sh"
source "${SCRIPT_DIR}/lib/cleanup_cache.sh"

function main {

	local alert_msg=""
	local df_args=""

	log "<6> Starting ${APP_NAME}"

	# CONFIG & DEFAULTS
	if [[ -r ${PATH_CONFIG} ]]; then
		source "${PATH_CONFIG}"
	else
		echo "<4>WARN: No config file found at ${PATH_CONFIG}. Using defaults ..."
		source "${PATH_DEFAULTS}"
	fi

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

	for type in "${DF_EXCLUDE_TYPES[@]}"; do
		df_args+="--exclude-type=${type} "
	done

	while read -r filesystem size used avail use_pct mount_point; do
		
		# DEBUG
		# log "<7> filesystem: ${filesystem}"
		# log "<7> size: ${size}"
		# log "<7> used: ${used}"
		# log "<7> avail: ${avail}"
		# log "<7> use_pct: ${use_pct}"
		# log "<7> mount_point: ${mount_point}"

		# Skip the header row
		[[ "${filesystem}" == "Filesystem" || "${filesystem}" == "Dateisystem" ]] && continue
		
		# Strip the literal '%' sign from the end
		percentage_used="${use_pct%%%}"

		# Quick safety check: Ensure percentage_used is actually a number before doing math
		if [[ ! "${percentage_used}" =~ ^[0-9]+$ ]]; then
			log "<3> Not a number: ${percentage_used}"
			continue
		fi
		
		# Calculate
		percentage_free=$((100 - percentage_used))

		# Cleanup Cache
		cleanup_cache

		# Check threshold
		if (( percentage_free < THRESHOLD_PERCENT_FREE )); then
			
			local msg="ALERT: LOW DISK SPACE!\nMountpoint: ${mount_point}\nSize: ${size}\nUsed: ${used}\nFree: ${percentage_free}%\nFilesystem: ${filesystem}"
			log "<3> ${msg}"

			# Check cache
			if [[ -f "${CACHE_FILE}" ]] && grep --quiet --fixed-strings "|${mount_point}" "${CACHE_FILE}"; then
				# mount_point found in cache, skip alerting
				log "<7> Skipping alert for '${mount_point}' (already alerted within past ${CACHE_TTL_HOURS} hours)."
			else
				# Alert msg
				alert_msg+="${msg}\n"
				# Log the alert to the cache with the current epoch timestamp
				echo "$(date +%s)|${mount_point}" >> "${CACHE_FILE}"
			fi
		else
			log "<7> ${mount_point}: ${percentage_free}% free space."
		fi

	done < <(df --human-readable --portability --local ${df_args})

	if (( ALERT_MAIL )) && [[ -z "${ALERT_MAIL_TO}" ]]; then
		log "<3> Required var not set: ALERT_MAIL_TO"
	fi

	if [[ -n "${alert_msg}" ]]; then

		# ALERT
		alert_msg_header+="DATE: $(date "+%Y-%m-%d %H:%M:%S")\n"
		alert_msg_header+="HOSTNAME: ${HOSTNAME}\n\n"
		
		if (( ALERT_MAIL )); then
			echo -e "${alert_msg_header}${alert_msg}" | \
			mail -s "${ALERT_MAIL_SUBJECT}" "${ALERT_MAIL_TO}" 2>/dev/null \
			&& log "<5> Alert Mail send to: ${ALERT_MAIL_TO}"
		fi
	fi
}

main