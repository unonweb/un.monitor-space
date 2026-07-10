# NOTES
# =====
# Daily: 1 day = 86,400 seconds
# Weekly: 7 days = 604,800 seconds
# Monthly: 30 days = 2,592,000 seconds

# REQUIRES
# ========
# - REPORT_MAIL
# - REPORT_PERIOD
# - MAIL_TO
# - MAIL_SUBJECT

function report {

	local disk="${1}"
	local input="${2}"
	local interval_seconds

	# CHECK internal dependencies
	for fctn in set_state get_state log; do
    	if ! declare -f "${fctn}" > /dev/null; then
        	echo "<3> Error: Required function missing: ${fctn}" >&2
        	return 1
    	fi
	done

	# CHECK external dependencies
	for cmd in mail; do
    	if ! command -v "${cmd}" &> /dev/null; then
        	log "<3> Error: Required external command missing: ${cmd}" >&2
        	return 1
    	fi
	done

	# CHECK vars
	for var in REPORT_MAIL REPORT_PERIOD MAIL_TO; do
		if [[ -z "${!var}" ]]; then
			log "<3> Required var missing: ${var}"
			return 1
		fi
	done

	# CHECK report at all?
	if (( ! REPORT_MAIL )); then
		return 0
	fi

	case "${REPORT_PERIOD}" in
        "daily")
			interval_seconds=86400 ;;
        "weekly")
			interval_seconds=604800 ;;
        "monthly")
			interval_seconds=2592000 ;;
        *)       
            log "<3> ERROR: Invalid interval '${REPORT_PERIOD}' configured."
            return 1 
            ;;
    esac

	# Time Calculations
    local current_time=$(date +%s) # Current epoch time in seconds
    local last_report_time=$(get_state "global" "last_scheduled_report_timestamp")

    # If run the first time
	# init timestamp
	# return
    if [[ -z "${last_report_time}" ]]; then
        log "<6> No previous report timestamp found. Initializing to current time."
        set_state "global" "last_scheduled_report_timestamp" "${current_time}"

        return 0
    fi

    local seconds_elapsed=$(( current_time - last_report_time ))
    log "<7> Time since last report: ${seconds_elapsed}s / Target: ${interval_seconds}s"

    # Check if the interval has matured
    if (( seconds_elapsed >= interval_seconds )); then

        log "<5> Interval (${REPORT_PERIOD}) reached! Sending report..."
		local rc_mail

		# Check if the input is a file
		if [[ -f "${input}" ]]; then
			# It's a file!
			# Stream it directly to preserve newlines
			mail -s "${MAIL_SUBJECT} [${disk}] REPORT" "${MAIL_TO}" < "${input}"
			rc_mail=${?}
		else
			# It's a raw string! 
			echo -e "${input}" | \
			mail -s "${MAIL_SUBJECT} [${disk}] REPORT" "${MAIL_TO}"
			rc_mail=${?}
		fi

		if [[ ${rc_mail} -eq 0 ]]; then
			log "<5> Mail-Report successfully sent to ${MAIL_TO}"
			set_state "global" "last_scheduled_report_timestamp" "${current_time}"
			return 0
		else
			log "<3> Failed to send Mail-Report to ${MAIL_TO}"
			return 1
		fi
	else
		log "<6> Not sending Mail-Report because REPORT_PERIOD ${REPORT_PERIOD} is not reached"
	fi

}