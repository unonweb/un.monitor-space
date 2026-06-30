# REQUIRES
# ========
# - THRESHOLD_PERCENT_FREE
# - CACHE_FILE
# - CACHE_TTL_HOURS
# - ALERT_MSG

function check_filesystems {
	
	while read -r filesystem size used avail use_pct mount_point; do

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

		# THRESHOLD
		if (( percentage_free < THRESHOLD_PERCENT_FREE )); then
			
			# Below threshold
			local msg="ALERT: LOW DISK SPACE!\nMountpoint: ${mount_point}\nSize: ${size}\nUsed: ${used}\nFree: ${percentage_free}%\nFilesystem: ${filesystem}"
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
			log "<7> ${mount_point}: ${percentage_free}% free space."
		fi

	done < <(df --human-readable --portability --local --exclude-type=btrfs ${df_args})
}