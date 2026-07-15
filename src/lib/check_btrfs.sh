# REQUIRES
# ========
# - root
# - THRESHOLD_PERCENT_FREE
# - CACHE_FILE
# - CACHE_TTL_HOURS
# - ALERT_MSG
# - REPORT_MSG

function check_btrfs {

	# CHECK external dependencies
	for cmd in btrfs; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	return 1
    	fi
	done

	REPORT_MSG+="BTRFS\n"
	REPORT_MSG+="=====\n\n"
	# Loop through /proc/mounts to find all 'btrfs' filesystems
	# We use a while loop to read line-by-line using Bash internals
	while read -r device mount_point fs_type options _; do
		
		# Filter for btrfs type only
		if [[ ${device} != /dev/* || "${fs_type}" != "btrfs" ]]; then
			continue
		fi

		log "<6> Checking Btrfs filesystem mounted at: ${mount_point}"
		# Query btrfs for data in Gigabytes (requires root/sudo)
		local btrfs_output=$(btrfs filesystem usage -g "${mount_point}" 2>/dev/null)
		
		# EXTRACT total_size (integer)
		if [[ "${btrfs_output}" =~ Device[[:space:]]+size:[[:space:]]*([0-9]+) ]]; then
			local total_size="${BASH_REMATCH[1]}"
		fi

		# EXTRACT free (integer)
		# Represents the possible space remaining
		if [[ "${btrfs_output}" =~ Free[[:space:]]+\(estimated\):[[:space:]]*([0-9]+) ]]; then
			local free="${BASH_REMATCH[1]}"
		fi
		
		# EXTRACT min_free (integer)
		# Represents the guaranteed space remaining
		if [[ "${btrfs_output}" =~ min:[[:space:]]*([0-9]+) ]]; then
			local min_free="${BASH_REMATCH[1]}"
		fi
		
		# Calculate percentage using Bash integer math
		if [[ -n "${total_size}" && -n "${min_free}" && "${total_size}" -gt 0 ]]; then
			# Bash math trick: (Free * 100) / Total gives us the floor percentage
			local free_pct=$(( (free * 100) / total_size ))
			local min_free_pct=$(( (min_free * 100) / total_size ))
			
			log "<7> Total Size: ${total_size} GiB"
			log "<7> Free Space: ${min_free}GiB - ${free}GiB (${min_free_pct}% - ${free_pct}%)"
			
			# THRESHOLD
			if (( free_pct < THRESHOLD_PERCENT_FREE )); then

				# CACHE
				if [[ -f "${CACHE_FILE}" ]] && grep --quiet --fixed-strings "|${mount_point}" "${CACHE_FILE}"; then
					# mount_point found in cache, skip alerting
					log "<6> Skipping alert for '${mount_point}' (already alerted within past ${CACHE_TTL_HOURS} hours)."
				else
					# ALERT msg
					local alert_msg=""
					alert_msg+="ALERT: 			DISK SPACE BELOW THRESHOLD!\n"
					alert_msg+="Mount:		${mount_point}\n"
					alert_msg+="Total Size: 	${total_size}\n"
					alert_msg+="Free:			${free}\n"
					alert_msg+="Min free:		${min_free}\n"
					alert_msg+="Threshold: 		${THRESHOLD_PERCENT_FREE}%\n"
					alert_msg+="Free pct: 		${free_pct}%\n"
					alert_msg+="Min free pct: 	${min_free_pct}%\n"

					ALERT_MSG+="${msg}\n\n"

					# Log the alert to the cache with the current epoch timestamp
					echo "$(date +%s)|${mount_point}" >> "${CACHE_FILE}"
				fi
				log "<4> ${alert_msg}"
			else
				log "<6> Space of status of ${mount_point}: OK"
			fi
		else
			log "<3> Error: Could not calculate space metrics for ${mount_point}"
		fi

		# REPORT
		REPORT_MSG+="Mount:			${mount_point}\n"
		REPORT_MSG+="Type:			BTRFS\n"
		REPORT_MSG+="Total size:		${total_size}GiB\n"
		REPORT_MSG+="Free:			${free}\n"
		REPORT_MSG+="Min free:		${min_free}GiB\n"
		REPORT_MSG+="Threshold:		${THRESHOLD_PERCENT_FREE}%\n"
		REPORT_MSG+="Free pct: 		${free_pct}%\n"
		REPORT_MSG+="Min free pct: 	${min_free_pct}%\n"
		REPORT_MSG+="${btrfs_output}\n\n"
		REPORT_MSG+="---------------------------------------------\n\n"

	done < /proc/mounts
}