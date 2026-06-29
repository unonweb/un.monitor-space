#!/usr/bin/bash

SCRIPT_PATH="$(readlink -f "${BASH_SOURCE}")"
SCRIPT_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_NAME=$(basename -- "$(readlink -f "${BASH_SOURCE}")")
SCRIPT_PARENT=$(dirname "${SCRIPT_DIR}")

APP_NAME="${SCRIPT_PARENT##*/}"

PATH_CONFIG="${SCRIPT_PARENT}/config.cfg"
PATH_DEFAULTS="${SCRIPT_PARENT}/defaults.cfg"

source "${SCRIPT_DIR}/lib/log.sh"

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
		[[ "${filesystem}" == "Filesystem" ]] && continue
		
		# Strip the literal '%' sign from the end
		percentage_used="${use_pct%%%}"

		# Quick safety check: Ensure percentage_used is actually a number before doing math
		if [[ ! "${percentage_used}" =~ ^[0-9]+$ ]]; then
			log "<3> Not a number: ${percentage_used}"
		fi
		
		# Calculate
		percentage_free=$((100 - percentage_used))

		# Check threshold
		if (( percentage_free < THRESHOLD_PERCENT_FREE )); then
			
			local msg="Alert: Low disk space!\nMountpoint: ${mount_point}\nSize: ${size}\nUsed: ${used}\nFree: ${percentage_free}%\nFilesystem: ${filesystem}"
			alert_msg+="${msg}\n"
			log "<3> ${msg}"			
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
			&& log "<6> Alert Mail send to: ${ALERT_MAIL_TO}"
		fi
	fi
}

main