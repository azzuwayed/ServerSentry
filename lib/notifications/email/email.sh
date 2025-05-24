#!/usr/bin/env bash
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
    if ! util_command_exists mail; then
      log_error "Mail command not found, cannot use 'mail' method"
      return 1
    fi
    ;;
  sendmail)
    if ! util_command_exists sendmail; then
      log_error "Sendmail command not found, cannot use 'sendmail' method"
      return 1
    fi
    ;;
  smtp)
    if ! util_command_exists curl; then
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
    if util_command_exists jq && echo "$details" | jq -e . >/dev/null 2>&1; then
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

  if ! util_command_exists mail; then
    log_error "Mail command not found"
    return 1
  fi

  # Send to each recipient
  IFS=',' read -r -a recipients <<<"$email_recipients"
  for recipient in "${recipients[@]}"; do
    # Skip empty entries
    [ -z "$recipient" ] && continue

    if echo -e "$body" | mail -s "$subject" "$recipient"; then
      log_debug "Email sent successfully to $recipient via mail"
    else
      log_error "Failed to send email to $recipient via mail"
      return 1
    fi
  done

  return 0
}

# Send via sendmail command
send_via_sendmail() {
  local subject="$1"
  local body="$2"

  log_debug "Sending email via sendmail command"

  if ! util_command_exists sendmail; then
    log_error "Sendmail command not found"
    return 1
  fi

  # Send to each recipient
  IFS=',' read -r -a recipients <<<"$email_recipients"
  for recipient in "${recipients[@]}"; do
    # Skip empty entries
    [ -z "$recipient" ] && continue

    local email_message
    email_message=$(
      cat <<EOF
To: ${recipient}
From: ${email_sender}
Subject: ${subject}

${body}
EOF
    )

    if echo -e "$email_message" | sendmail "$recipient"; then
      log_debug "Email sent successfully to $recipient via sendmail"
    else
      log_error "Failed to send email to $recipient via sendmail"
      return 1
    fi
  done

  return 0
}

# Send via SMTP using curl
send_via_smtp() {
  local subject="$1"
  local body="$2"

  log_debug "Sending email via SMTP"

  if ! util_command_exists curl; then
    log_error "Curl command not found"
    return 1
  fi

  # Build SMTP URL
  local smtp_url="smtp://${email_smtp_server}:${email_smtp_port}"
  if [ "$email_smtp_use_tls" = "true" ]; then
    smtp_url="smtps://${email_smtp_server}:${email_smtp_port}"
  fi

  # Send to each recipient
  IFS=',' read -r -a recipients <<<"$email_recipients"
  for recipient in "${recipients[@]}"; do
    # Skip empty entries
    [ -z "$recipient" ] && continue

    # Create email message
    local email_message
    email_message=$(
      cat <<EOF
To: ${recipient}
From: ${email_sender}
Subject: ${subject}

${body}
EOF
    )

    # Build curl command
    local curl_args=(
      "--url" "$smtp_url"
      "--mail-from" "$email_sender"
      "--mail-rcpt" "$recipient"
      "--upload-file" "-"
    )

    # Add authentication if configured
    if [ -n "$email_smtp_user" ] && [ -n "$email_smtp_password" ]; then
      curl_args+=("--user" "${email_smtp_user}:${email_smtp_password}")
    fi

    # Add TLS options
    if [ "$email_smtp_use_tls" = "true" ]; then
      curl_args+=("--ssl-reqd")
    fi

    # Send email
    if echo -e "$email_message" | curl "${curl_args[@]}"; then
      log_debug "Email sent successfully to $recipient via SMTP"
    else
      log_error "Failed to send email to $recipient via SMTP"
      return 1
    fi
  done

  return 0
}
