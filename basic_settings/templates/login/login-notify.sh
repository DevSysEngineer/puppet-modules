#!/bin/sh
# Managed by Puppet

die() {
    printf '%s\n' "$*" >&2
    exit 0 # Important, we do not want to fail the login
}

# Locate awk
AWK=$(command -v awk 2>/dev/null)
[ -n "$AWK" ] || die "awk not available"

# Locate date
DATE=$(command -v date 2>/dev/null)
[ -n "$DATE" ] || die "date not available"

# Locate head
HEAD=$(command -v head 2>/dev/null)
[ -n "$HEAD" ] || die "head not available"

# Locate last
LAST=$(command -v last 2>/dev/null)
[ -n "$LAST" ] || die "last not available"

# Locate notification helper or mail fallback
MONITORING_NOTIFY=/usr/local/lib/puppet/monitoring-notify
MAIL=$(command -v mail 2>/dev/null)
[ -x "$MONITORING_NOTIFY" ] || [ -n "$MAIL" ] || die "monitoring-notify and mail not available"

# Locate ps
PS=$(command -v ps 2>/dev/null)
[ -n "$PS" ] || die "ps not available"

send_notification() {
    subject=$1

    if [ -x "$MONITORING_NOTIFY" ]; then
        "$MONITORING_NOTIFY" -t <%= @mail_to_shell %> -r <%= @audit_mail_from_shell %> "$subject"
    else
        "$MAIL" -s "$subject" -r <%= @audit_mail_from_shell %> <%= @mail_to_shell %>
    fi
}

# Try to get service
SERVICE=$($PS -o comm= -p "$PPID" 2>/dev/null | $AWK '{gsub(/[[:space:]]+/,""); print}')
[ -z "$SERVICE" ] && SERVICE="unknown"

# Determine originating user and target user
if [ -n "$PAM_RUSER" ]; then # su / sudo
    USER="$PAM_RUSER"
    TARGET_USER="$PAM_USER"
else # direct session
    WHOAMI=/usr/bin/whoami ; [ -x "$WHOAMI" ] || exit 0 # Important, we do not want to fail the login
    TARGET_USER="$($WHOAMI)"
    USER="$TARGET_USER"
fi

# Determine IP address
if [ -n "$SSH_CLIENT" ]; then
    IP=$(printf '%s\n' "$SSH_CLIENT" | $AWK '{print $1}')
elif [ -n "$SSH_CONNECTION" ]; then
    IP=$(printf '%s\n' "$SSH_CONNECTION" | $AWK '{print $1}')
else
    IP=$($LAST -i -n 1 "$USER" | $AWK '{print $3}' | $HEAD -n 1)
    [ -z "$IP" ] && IP="UNKNOWN"
fi

# Get current time
NOW="$($DATE)"

# Interactive feedback
if [ -n "$PS1" ]; then
    if [ "$TARGET_USER" = "root" ]; then
        printf "\033[0;31mYou login as root, this action is registered and sent to the server administrator(s) (service %s).\033[0m\n" "$SERVICE"
    elif [ "$TARGET_USER" = "$USER" ]; then
        printf "\033[0;36mYour IP (%s), login time (%s) and username (%s) have been registered and sent to the server administrator(s) (service %s).\033[0m\n" "$IP" "$NOW" "$USER" "$SERVICE"
    else
        printf '\033[0;36mYou are logged in as %s; this action is registered and sent to the server administrator(s) (service %s).\033[0m\n' "$TARGET_USER" "$SERVICE"
    fi
fi

# Send mail notification
if [ "$TARGET_USER" = "$USER" ]; then
    printf 'User %s logged into %s at %s\nIP: %s\nService: %s\n' "$USER" <%= @server_fdqn_shell %> "$NOW" "$IP" "$SERVICE" | send_notification "Audit login $USER via $SERVICE"
else
    printf 'User %s logged in as %s into %s at %s\nIP: %s\nService: %s\n' "$USER" "$TARGET_USER" <%= @server_fdqn_shell %> "$NOW" "$IP" "$SERVICE" | send_notification "Audit $USER->$TARGET_USER via $SERVICE"
fi
