#!/bin/sh
# Managed by Puppet

# Exit silently when invoked by cron
[ "$PAM_SERVICE" = "cron" ] || [ "$PAM_SERVICE" = "crond" ] && exit 0

die() {
    echo "$*" >&2
    exit 3
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

# Locate last
MAIL=$(command -v mail 2>/dev/null)
[ -n "$MAIL" ] || die "mail not available"

# Determine originating user and target user
if [ -n "$PAM_RUSER" ]; then # su / sudo
    USER="$PAM_RUSER"
    TARGET_USER="$PAM_USER"
else # direct session
    WHOAMI=/usr/bin/whoami ; [ -x "$WHOAMI" ] || exit 1
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

# Set some values
NOW="$($DATE)"
SERVICE=${PAM_SERVICE:-unknown}

# Interactive feedback
if [ -n "$PS1" ]; then
    if [ "$TARGET_USER" = "root" ]; then
        printf '\033[0;31mYou are logged in as root; this action has been logged and reported.\033[0m\n'
    elif [ "$TARGET_USER" = "$USER" ]; then
        printf '\033[0;36mIP %s, time %s, user %s – recorded and reported (service %s).\033[0m\n' "$IP" "$NOW" "$USER" "$SERVICE"
    else
        printf '\033[0;36mYou are logged in as %s; this action has been recorded and reported (service %s).\033[0m\n' "$TARGET_USER" "$SERVICE"
    fi
fi

# Send mail notification
if [ "$TARGET_USER" = "$USER" ]; then
    printf 'User %s logged into %s at %s\nIP: %s\nService: %s\n' "$USER" "<%= @server_fdqn %>" "$NOW" "$IP" "$SERVICE" | $MAIL -s "Audit login $USER via $SERVICE" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
else
    printf 'User %s logged in as %s into %s at %s\nIP: %s\nService: %s\n' "$USER" "$TARGET_USER" "<%= @server_fdqn %>" "$NOW" "$IP" "$SERVICE" | $MAIL -s "Audit $USER->$TARGET_USER via $SERVICE" -r "audit@<%= @server_fdqn %>" "<%= @mail_to %>"
fi
