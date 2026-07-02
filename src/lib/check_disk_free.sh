# REQUIRES
# ========
# - THRESHOLD_PERCENT_FREE
# - CACHE_FILE
# - CACHE_TTL_HOURS
# - ALERT_MSG
# - REPORT_MSG

function check_disk_free
	
	# CHECK external dependencies
	for cmd in df; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	return 1
    	fi
	done

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
			local msg="ALERT: LOW DISK SPACE!\nMountpoint: ${mount_point}\nSize: ${size}\nUsed: ${used}\nFree: ${pct_free}%\nFilesystem: ${filesystem}"
			log "<3> ${msg}"

			# CACHE
			if [[ -f "${CACHE_FILE}" ]] && grep --quiet --fixed-strings "|${mount_point}" "${CACHE_FILE}"; then
				# mount_point found in cache, skip alerting
				log "<7> Skipping alert for '${mount_point}' (already alerted within past ${CACHE_TTL_HOURS} hours)."
			else
				# ALERT msg
				ALERT_MSG+="${msg}\n"
				# Log the alert to the cache with the current epoch timestamp
				echo "$(date +%s)|${mount_point}" >> "${CACHE_FILE}"
			fi
		else
			# Above threshold
			log "<7> ${mount_point}: ${pct_free}% free space."
		fi
		
		# REPORT
		REPORT_MSG+="MOUNT: ${mount_point}\n"
		REPORT_MSG+="TYPE: ${filesystem}\n"
		REPORT_MSG+="---\n"
		REPORT_MSG+="size: ${size}\n"
		REPORT_MSG+="used: ${used}\n"
		REPORT_MSG+="avail: ${avail} (calculated: ${pct_free})\n"
		REPORT_MSG+="use_pct: ${use_pct} (calculated: ${pct_used})\n"

	done < <(df --human-readable --portability --local --exclude-type=btrfs ${df_args})
}