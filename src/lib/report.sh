# NOTES
# =====
# Daily: 1 day = 86,400 seconds
# Weekly: 7 days = 604,800 seconds
# Monthly: 30 days = 2,592,000 seconds

# REQUIRES
# ========
# REPORT_MAIL
# REPORT_PERIOD

function report {
	local disk="${1}"
	local msg="${2}"

	local interval_seconds

	if (( ! REPORT_MAIL )); then
		return 0
	fi

	case "${REPORT_PERIOD}" in
        daily)
			interval_seconds=86400 ;;
        weekly)
			interval_seconds=604800 ;;
        monthly)
			interval_seconds=2592000 ;;
        *)       
            log "<3> ERROR: Invalid interval '${REPORT_PERIOD}' configured."
            return 1 
            ;;
    esac

	# Time Calculations
    local current_time=$(date +%s) # Current epoch time in seconds
    local last_report_time=$(get_state "global" "last_scheduled_report_timestamp")

    # Initialize if this is the script's very first run
    if [[ -z "${last_report_time}" ]]; then
        log "<6> No previous report timestamp found. Initializing to current time."
        set_state "global" "last_scheduled_report_timestamp" "${current_time}"
        return 0
    fi

    local seconds_elapsed=$(( current_time - last_report_time ))

    log "<7> Time since last report: ${seconds_elapsed}s / Target: ${interval_seconds}s"

    # Check if the interval has matured
    if (( seconds_elapsed >= interval_seconds )); then
        log "<6> Interval (${interval}) reached! Sending report..."

		echo -e "${msg}" | \
			mail -s "${MAIL_SUBJECT} [${disk}] REPORT" "${MAIL_TO}" \
			&& log "<5> Mail-Report sent to ${MAIL_TO}" \
			&& return 0
	fi

}