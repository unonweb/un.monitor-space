# REQUIRES
# ========
# - CACHE_TTL_HOURS
# - CACHE_FILE

function cleanup_cache {
	# Clean up the cache of records older than 48 hours to keep it tidy

	if [[ -f "${CACHE_FILE}" ]]; then
		# Keeps only lines where the timestamp is within the last 48 hours
		# Format in cache: EPOCH_TIMESTAMP|SERVICE_NAME
		local current_time=$(date +%s)
		local cutoff_time=$(( current_time - (CACHE_TTL_HOURS * 3600) ))
		# Cache pruning
		# Only keep timestamps that are younger than cutoff_time
		local tmp_cache=$(mktemp)
		while IFS='|' read -r timestamp key; do
			if (( timestamp >= cutoff_time )); then
				echo "${timestamp}|${key}" >> "${tmp_cache}"
			fi
		done < "${CACHE_FILE}"
		mv "${tmp_cache}" "${CACHE_FILE}"
	fi
}