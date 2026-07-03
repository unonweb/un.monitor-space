# REQUIRES
# ========
# - ALERT_MAIL
# - MAIL_TO
# - MAIL_SUBJECT

function alert {

	local alert_msg="${1}"

	if (( ! ALERT_MAIL )); then
		return 0
	fi

	if (( ALERT_MAIL )) && [[ -z "${MAIL_TO}" ]]; then
		log "<3> Required var not set: MAIL_TO"
		return 1
	fi

	if [[ -n "${alert_msg}" ]]; then

		# ALERT
		alert_msg_header+="DATE:		$(date "+%Y-%m-%d %H:%M:%S")\n"
		alert_msg_header+="HOSTNAME:	${HOSTNAME}\n\n"
		
		echo -e "${alert_msg_header}${alert_msg}" | \
		mail -s "${MAIL_SUBJECT} ALERT" "${MAIL_TO}" 2>/dev/null \
		&& log "<5> Alert Mail send to: ${MAIL_TO}"
	
	fi
}