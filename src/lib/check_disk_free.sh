# REQUIRES
# ========
# - THRESHOLD_PERCENT_FREE
# - CACHE_FILE
# - CACHE_TTL_HOURS
# - ALERT_MSG
# - REPORT_MSG
# - DF_EXCLUDE_TYPES

function check_disk_free {
	
	# CHECK internal dependencies
	for fctn in log trim; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	return 1
    	fi
	done

	# CHECK external dependencies
	for cmd in df; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	return 1
    	fi
	done

	# BUILD args
	local df_args=""
	for type in "${DF_EXCLUDE_TYPES[@]}"; do
		df_args+="--exclude-type=${type} "
	done

	REPORT_MSG+="DISK FREE\n"
	REPORT_MSG+="=========\n\n"
	while read -r filesystem size used avail use_pct mount_point; do

		# Skip the header row
		[[ "${filesystem}" == "Filesystem" || "${filesystem}" == "Dateisystem" ]] && continue
		
		# Strip the literal '%' sign from the end
		local pct_used="${use_pct%%%}"

		# Safety check: Ensure pct_used is actually a number before doing math
		if [[ ! "${pct_used}" =~ ^[0-9]+$ ]]; then
			log "<3> Not a number: ${pct_used}"
			continue
		fi
		
		# Calculate
		local pct_free=$((100 - pct_used))

		# THRESHOLD
		if (( pct_free < THRESHOLD_PERCENT_FREE )); then
			
			# Below threshold
			local alert_msg=""
			alert_msg+="ALERT: 		DISK SPACE BELOW THRESHOLD!\n"
			alert_msg+="MOUNTPOINT:	${mount_point}\n"
			alert_msg+="FILESYSTEM:	${filesystem}\n"
			alert_msg+="Size: 		${size}\n"
			alert_msg+="Used: 		${used}\n"
			alert_msg+="Free: 		${pct_free}%\n"
			alert_msg+="Threshold:	${THRESHOLD_PERCENT_FREE}%\n"
			
			log "<3> ${alert_msg}"

			# CACHE
			if [[ -f "${CACHE_FILE}" ]] && grep --quiet --fixed-strings "|${mount_point}" "${CACHE_FILE}"; then
				# mount_point found in cache, skip alerting
				log "<7> Skipping alert for '${mount_point}' (already alerted within past ${CACHE_TTL_HOURS} hours)."
			else
				# ALERT msg
				ALERT_MSG+="${alert_msg}\n"
				# Log the alert to the cache with the current epoch timestamp
				echo "$(date +%s)|${mount_point}" >> "${CACHE_FILE}"
			fi
		else
			# Above threshold
			log "<7> ${mount_point}: ${pct_free}% free space."
		fi
		
		# REPORT
		REPORT_MSG+="FS:		${filesystem}\n"
		REPORT_MSG+="MOUNT: 	${mount_point}\n"
		REPORT_MSG+="Size: 		${size}\n"
		REPORT_MSG+="Used: 		${used}\n"
		REPORT_MSG+="Free:	 	${pct_free}%\n"
		REPORT_MSG+="Threshold:	${THRESHOLD_PERCENT_FREE}%\n"
		REPORT_MSG+="---------\n"

	done < <(df --human-readable --portability --local --exclude-type=btrfs "${df_args}")

	REPORT_MSG+="\n\n"
}