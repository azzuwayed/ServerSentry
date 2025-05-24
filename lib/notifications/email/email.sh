#!/bin/bash
#
# ServerSentry v2 - Email Notification Provider
#
# This module sends notifications via email using the system's mail command

# Provider metadata
email_provider_name="email"
email_provider_version="1.0"
email_provider_description="Sends notifications via email"
email_provider_author="ServerSentry Team"

# Default configuration
email_recipients=""
email_sender="serversentry@$(hostname -f 2>/dev/null || echo 'localhost')"
email_subject_prefix="[ServerSentry]"
email_send_method="mail" # mail, sendmail, or smtp

# SMTP configuration (when using smtp method)
email_smtp_server=""
email_smtp_port="25"
email_smtp_user=""
email_smtp_password=""
email_smtp_use_tls="false"

# Return provider information
email_provider_info() {
  echo "Email Notification Provider v${email_provider_version}"
}

# Configure the provider
email_provider_configure() {
  local config_file="$1"

  # Load global configuration first
  email_recipients=$(get_config "email_recipients" "")
  email_sender=$(get_config "email_sender" "serversentry@$(hostname -f 2>/dev/null || echo 'localhost')")
  email_subject_prefix=$(get_config "email_subject_prefix" "[ServerSentry]")
  email_send_method=$(get_config "email_send_method" "mail")

  # SMTP config
  email_smtp_server=$(get_config "email_smtp_server" "")
  email_smtp_port=$(get_config "email_smtp_port" "25")
  email_smtp_user=$(get_config "email_smtp_user" "")
  email_smtp_password=$(get_config "email_smtp_password" "")
  email_smtp_use_tls=$(get_config "email_smtp_use_tls" "false")

  # Load provider-specific configuration if file exists
  if [ -f "$config_file" ]; then
    source "$config_file"
  fi

  # Validate configuration
  if [ -z "$email_recipients" ]; then
    log_error "Email recipients not configured"
    return 1
  fi

  # Validate method-specific requirements
  case "$email_send_method" in
  mail)
    if ! command_exists mail; then
      log_error "Mail command not found, cannot use 'mail' method"
      return 1
    fi
    ;;
  sendmail)
    if ! command_exists sendmail; then
      log_error "Sendmail command not found, cannot use 'sendmail' method"
      return 1
    fi
    ;;
  smtp)
    if ! command_exists curl; then
      log_error "Curl command not found, cannot use 'smtp' method"
      return 1
    fi
    if [ -z "$email_smtp_server" ]; then
      log_error "SMTP server not configured for 'smtp' method"
      return 1
    fi
    ;;
  *)
    log_error "Invalid email send method: $email_send_method"
    return 1
    ;;
  esac

  log_debug "Email notification provider configured"

  return 0
}

# Send notification
email_provider_send() {
  local status_code="$1"
  local status_message="$2"
  local plugin_name="$3"
  local details="$4"

  # Get the hostname
  local hostname
  hostname=$(hostname)

  # Format timestamp
  local timestamp
  timestamp=$(get_formatted_date)

  # Determine status text
  local status_text
  case "$status_code" in
  0) status_text="OK" ;;
  1) status_text="WARNING" ;;
  2) status_text="CRITICAL" ;;
  *) status_text="UNKNOWN" ;;
  esac

  # Prepare email subject
  local subject="${email_subject_prefix} ${status_text}: ${plugin_name} on ${hostname}"

  # Prepare email body
  local body
  body=$(
    cat <<EOF
ServerSentry Notification
------------------------

Status: ${status_text}
Host: ${hostname}
Plugin: ${plugin_name}
Time: ${timestamp}

Message: ${status_message}
EOF
  )

  # Add details if available
  if [ -n "$details" ]; then
    if command_exists jq && echo "$details" | jq -e . >/dev/null 2>&1; then
      # Format JSON details nicely
      body="${body}

Details:
$(echo "$details" | jq .)"
    else
      # Just add raw details
      body="${body}

Details:
${details}"
    fi
  fi

  # Send email based on configured method
  case "$email_send_method" in
  mail)
    send_via_mail "$subject" "$body"
    ;;
  sendmail)
    send_via_sendmail "$subject" "$body"
    ;;
  smtp)
    send_via_smtp "$subject" "$body"
    ;;
  esac

  return $?
}

# Send via mail command
send_via_mail() {
  local subject="$1"
  local body="$2"

  log_debug "Sending email via mail command"

  # Check if mail command exists
  if ! command_exists mail; then
    log_error "Cannot send email: 'mail' command not found"
    return 1
  fi

  # Send using mail
  echo "$body" | mail -s "$subject" "$email_recipients"
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send email via mail command"
    return 1
  fi

  log_debug "Email notification sent successfully via mail"
  return 0
}

# Send via sendmail
send_via_sendmail() {
  local subject="$1"
  local body="$2"

  log_debug "Sending email via sendmail command"

  # Check if sendmail command exists
  if ! command_exists sendmail; then
    log_error "Cannot send email: 'sendmail' command not found"
    return 1
  fi

  # Format recipients
  local to_list=""
  for recipient in $email_recipients; do
    to_list="${to_list}To: ${recipient}
"
  done

  # Send using sendmail
  {
    echo "From: ${email_sender}"
    echo "$to_list"
    echo "Subject: $subject"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=utf-8"
    echo ""
    echo "$body"
  } | sendmail -t
  local exit_code=$?

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send email via sendmail command"
    return 1
  fi

  log_debug "Email notification sent successfully via sendmail"
  return 0
}

# Send via SMTP using curl
send_via_smtp() {
  local subject="$1"
  local body="$2"

  log_debug "Sending email via SMTP"

  # Check if curl command exists
  if ! command_exists curl; then
    log_error "Cannot send email: 'curl' command not found"
    return 1
  fi

  # Create a temp file for the email content
  local temp_file
  temp_file=$(mktemp)

  # Format recipients
  local to_list=""
  for recipient in $email_recipients; do
    to_list="${to_list}To: ${recipient}
"
  done

  # Create email content
  {
    echo "From: ${email_sender}"
    echo "$to_list"
    echo "Subject: $subject"
    echo "MIME-Version: 1.0"
    echo "Content-Type: text/plain; charset=utf-8"
    echo ""
    echo "$body"
  } >"$temp_file"

  # Build curl command
  local curl_cmd="curl --silent --show-error "

  # Add SMTP server info
  curl_cmd+="--url 'smtp://${email_smtp_server}:${email_smtp_port}' "

  # Add authentication if provided
  if [ -n "$email_smtp_user" ]; then
    curl_cmd+="--user '${email_smtp_user}:${email_smtp_password}' "
  fi

  # Add TLS if enabled
  if [ "$email_smtp_use_tls" = "true" ]; then
    curl_cmd+="--ssl-reqd "
  fi

  # Add sender and recipients
  curl_cmd+="--mail-from '${email_sender}' "
  for recipient in $email_recipients; do
    curl_cmd+="--mail-rcpt '${recipient}' "
  done

  # Add the email content
  curl_cmd+="--upload-file $temp_file"

  # Send the email
  local response
  response=$(eval "$curl_cmd" 2>&1)
  local exit_code=$?

  # Clean up temp file
  rm -f "$temp_file"

  if [ $exit_code -ne 0 ]; then
    log_error "Failed to send email via SMTP: $response"
    return 1
  fi

  log_debug "Email notification sent successfully via SMTP"
  return 0
}
