# REQUIRES
# ========
# - root
# - THRESHOLD_PERCENT_FREE

function check_btrfs {
	# Loop through /proc/mounts to find all 'btrfs' filesystems
	# We use a while loop to read line-by-line using Bash internals
	while read -r device mount_point fs_type options _; do
		# Filter for btrfs type only
    	if [[ "${fs_type}" == "btrfs" ]]; then
			log "<6> Checking Btrfs filesystem mounted at: ${mount_point}"
			# Query btrfs for data in Gigabytes (requires root/sudo)
        	btrfs_output=$(btrfs filesystem usage -g "${mount_point}" 2>/dev/null)
			
			# Extract Total Device Size (Integer only) using Bash regex
			if [[ "${btrfs_output}" =~ Device\ size:[[:space:]]+([0-9]+) ]]; then
				total_size="${BASH_REMATCH[1]}"
			fi
			
			# Extract Estimated Minimum Free Space (Integer only)
			if [[ "${btrfs_output}" =~ Estimated\ \(min\):[[:space:]]+([0-9]+) ]]; then
				free_space="${BASH_REMATCH[1]}"
			fi
			
			# Calculate percentage using Bash integer math
			if [[ -n "${total_size}" && -n "${free_space}" && "${total_size}" -gt 0 ]]; then
				# Bash math trick: (Free * 100) / Total gives us the floor percentage
				pct_free=$(( (free_space * 100) / total_size ))
				
				log "<6> Total Size: ${total_size} GiB"
				log "<6> Free Space: ${free_space} GiB (${pct_free}% free)"
				
				# Comparison
				if (( pct_free < THRESHOLD_PERCENT_FREE )); then
					echo "--> ALERT: Free space (${pct_free}%) is below threshold (${THRESHOLD_PERCENT_FREE}%)!"
				else
					echo "--> Space status: OK"
				fi
			else
				echo "--> Error: Could not calculate space metrics for ${mount_point}"
			fi
		fi
	done < /proc/mounts
}