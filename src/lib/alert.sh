# REQUIRES
# ========
# - ALERT_MAIL
# - ALERT_MAIL_TO
# - ALERT_MAIL_SUBJECT

function alert {

	local alert_msg="${1}"

	if (( ! ALERT_MAIL )); then
		return 0
	fi

	if (( ALERT_MAIL )) && [[ -z "${ALERT_MAIL_TO}" ]]; then
		log "<3> Required var not set: ALERT_MAIL_TO"
		return 1
	fi

	if [[ -n "${alert_msg}" ]]; then

		# ALERT
		alert_msg_header+="DATE: $(date "+%Y-%m-%d %H:%M:%S")\n"
		alert_msg_header+="HOSTNAME: ${HOSTNAME}\n\n"
		
		echo -e "${alert_msg_header}${alert_msg}" | \
		mail -s "${ALERT_MAIL_SUBJECT}" "${ALERT_MAIL_TO}" 2>/dev/null \
		&& log "<5> Alert Mail send to: ${ALERT_MAIL_TO}"
	
	fi
}