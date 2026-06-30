# REQUIRES
# ========
# - root
# - THRESHOLD_PERCENT_FREE
# - CACHE_FILE
# - CACHE_TTL_HOURS
# - ALERT_MSG

function check_btrfs {

	# Loop through /proc/mounts to find all 'btrfs' filesystems
	# We use a while loop to read line-by-line using Bash internals
	while read -r device mount_point fs_type options _; do
		
		# Filter for btrfs type only
		if [[ ${device} != /dev/* || "${fs_type}" != "btrfs" ]]; then
			continue
		fi

		log "<6> Checking Btrfs filesystem mounted at: ${mount_point}"
		# Query btrfs for data in Gigabytes (requires root/sudo)
		btrfs_output=$(btrfs filesystem usage -g "${mount_point}" 2>/dev/null)
		
		# Extract Total Device Size (Integer only) using Bash regex
		if [[ "${btrfs_output}" =~ Device[[:space:]]+size:[[:space:]]*([0-9]+) ]]; then
			total_size="${BASH_REMATCH[1]}"
		fi
		
		# Extract Estimated Minimum Free Space (Integer only)
		# Represents the guaranteed space remaining
		if [[ "${btrfs_output}" =~ min:[[:space:]]*([0-9]+) ]]; then
			min_free="${BASH_REMATCH[1]}"
		fi
		
		# Calculate percentage using Bash integer math
		if [[ -n "${total_size}" && -n "${min_free}" && "${total_size}" -gt 0 ]]; then
			# Bash math trick: (Free * 100) / Total gives us the floor percentage
			pct_free=$(( (min_free * 100) / total_size ))
			
			log "<6> Total Size: ${total_size} GiB"
			log "<6> Free Space: ${min_free} GiB (${pct_free}% free)"
			
			# THRESHOLD
			if (( pct_free < THRESHOLD_PERCENT_FREE )); then

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
				log "<4> ALERT: Free space at ${mount_point} is ${pct_free}% and below threshold (${THRESHOLD_PERCENT_FREE}%)!"
			else
				log "<6> Space of status of ${mount_point}: OK"
			fi
		else
			log "<3> Error: Could not calculate space metrics for ${mount_point}"
		fi

	done < /proc/mounts
}