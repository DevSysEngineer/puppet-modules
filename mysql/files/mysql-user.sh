#!/bin/sh
# Managed by puppet
# Manage one account using Puppet-owned MySQL option and SQL files; never accept a password argument.
# Usage: mysql-user.sh ACTION DEFAULTS INPUT_BASE AUTHENTICATION ROOT_ACCOUNT HOST ACCOUNT
# ACTION: check-present, present, check-absent, absent. Checks return 0 for convergence, 1 for drift, 2 for failure.
# Mutations repeat all preconditions and return 2 on failure. No raw client diagnostics are printed.
# Only remote accounts need an applied record: input digest plus the observed server authentication state.
# Puppet removes that record and secret inputs on retirement; the helper never deletes managed inputs.

# Client errors can contain SQL and must never be included in the error category.
die() {
    printf 'MySQL account management: %s\n' "$1" >&2
    exit 2
}

MYSQL=$(command -v mysql 2>/dev/null) || die 'mysql client is unavailable'
SHA256SUM=$(command -v sha256sum 2>/dev/null) || die 'sha256sum is unavailable'

# Isolate client authentication without changing or deleting the operator's login-path file.
unset MYSQL_PWD MYSQL_HOST MYSQL_TCP_PORT MYSQL_UNIX_PORT MYSQL_GROUP_SUFFIX
MYSQL_TEST_LOGIN_FILE=/dev/null
export MYSQL_TEST_LOGIN_FILE
LC_ALL=C
export LC_ALL
umask 077
ACTION="$1"
DEFAULTS="$2"
INPUT_BASE="$3"
AUTHENTICATION="$4"
ROOT_ACCOUNT="$5"
ACCOUNT_HOST="$6"
ACCOUNT="$7"
ADMIN_DEFAULTS="$DEFAULTS"
DESIRED_WORKS=false

# Both administrative and desired connections target the same local server as the module's configuration.
run_mysql() {
    $MYSQL "--defaults-file=$1" --protocol=socket --socket=/var/run/mysqld/mysqld.sock \
        --connect-timeout=5 --default-character-set=utf8mb4 --batch --raw --skip-column-names --binary-mode
}

# Desired credentials are not proven by a successful socket-authenticated connection alone.
# Return 1 only for authentication denial or a different account; transport and input errors abort before mutation.
check_login() {
    login_result=$(printf '%s\n' 'SELECT CURRENT_USER();' | run_mysql "$INPUT_BASE.cnf" 2>&1)
    login_status=$?
    if [ "$login_status" -eq 0 ]; then
        [ "$login_result" = "$ACCOUNT" ]
    else
        case "$login_result" in
            'ERROR 1045 '*|'ERROR 1698 '*|'ERROR 1820 '*) return 1 ;;
            *) die 'desired-credential connection failed for a technical reason' ;;
        esac
    fi
}

# These are password-backed plugins; auth_socket and unknown plugins cannot prove a desired password.
password_plugin_matches() {
    case "$AUTHENTICATION:$AUTH_STATE" in
        mysql_native_password:mysql_native_password:*) return 0 ;;
        default:mysql_native_password:*|default:caching_sha2_password:*|default:sha256_password:*) return 0 ;;
        legacy:mysql_native_password:*|legacy:mysql_old_password:*|legacy::*) return 0 ;;
        *) return 1 ;;
    esac
}

# Inspect through a proven administrative connection, selecting both User and Host in the managed SQL.
inspect_account() {
    AUTH_STATE=$(run_mysql "$ADMIN_DEFAULTS" < "$INPUT_BASE.inspect.sql" 2>/dev/null) || die 'account inspection failed'
}

# Only remote accounts use the confirmation record; local accounts always prove the desired login and plugin.
account_matches() {
    [ -n "$AUTH_STATE" ] && password_plugin_matches || return 1
    if [ "$ACCOUNT_HOST" = 'localhost' ]; then
        [ "$DESIRED_WORKS" = true ]
    elif [ -f "$INPUT_BASE.applied" ]; then
        [ -r "$INPUT_BASE.applied" ] || die 'account confirmation record is unreadable'
        {
            IFS= read -r applied_input && IFS= read -r applied_auth
        } < "$INPUT_BASE.applied" || return 1
        [ "$applied_input" = "$INPUT_DIGEST" ] && [ "$applied_auth" = "$AUTH_STATE" ]
    else
        return 1
    fi
}

# A partial record after interruption fails comparison and is rebuilt on the next application.
# This persistent private file avoids temporary remnants and is removed by Puppet when the account retires.
save_confirmation() {
    printf '%s\n%s\n' "$INPUT_DIGEST" "$AUTH_STATE" > "$INPUT_BASE.applied" || die 'cannot write account confirmation record'
}

# Reject incomplete input before establishing connections or changing an account.
[ "$#" -eq 7 ] || die 'invalid helper arguments'
case "$ACTION" in
    present|check-present|absent|check-absent) ;;
    *) die 'invalid action' ;;
esac
for INPUT_FILE in "$INPUT_BASE.inspect.sql" "$INPUT_BASE.drop.sql"; do
    [ -f "$INPUT_FILE" ] && [ -r "$INPUT_FILE" ] || die 'account SQL input is missing or unreadable'
done
case "$ACTION" in
    present|check-present)
        for INPUT_FILE in "$INPUT_BASE.cnf" "$INPUT_BASE.create.sql" "$INPUT_BASE.alter.sql"; do
            [ -f "$INPUT_FILE" ] && [ -r "$INPUT_FILE" ] || die 'credential input is missing or unreadable'
        done
        INPUT_DIGEST=$($SHA256SUM < "$INPUT_BASE.alter.sql") || die 'cannot read credential input'
        if [ "$ACCOUNT_HOST" = 'localhost' ] && check_login; then
            DESIRED_WORKS=true
        fi
        # Recover interrupted root rotation before the first query against mysql.user.
        if [ "$ROOT_ACCOUNT" = true ] && [ "$DESIRED_WORKS" = true ]; then
            ADMIN_DEFAULTS="$INPUT_BASE.cnf"
        fi
        ;;
esac
[ -f "$ADMIN_DEFAULTS" ] && [ -r "$ADMIN_DEFAULTS" ] || die 'administrative defaults file is missing or unreadable'
ADMIN_RESULT=$(printf '%s\n' 'SELECT 1;' | run_mysql "$ADMIN_DEFAULTS" 2>/dev/null) || die 'no working administrative connection'
[ "$ADMIN_RESULT" = 1 ] || die 'administrative connection returned an unexpected result'
inspect_account

# Checks never change SQL, files, or server state.
case "$ACTION" in
    check-present)
        account_matches
        exit $?
        ;;
    check-absent)
        [ -z "$AUTH_STATE" ]
        exit $?
        ;;
    absent)
        if [ -n "$AUTH_STATE" ]; then
            run_mysql "$ADMIN_DEFAULTS" < "$INPUT_BASE.drop.sql" >/dev/null 2>&1 || die 'account removal failed'
        fi
        ;;
    present)
        if account_matches; then
            exit 0
        fi
        if [ -n "$AUTH_STATE" ]; then
            SQL_INPUT="$INPUT_BASE.alter.sql"
        else
            SQL_INPUT="$INPUT_BASE.create.sql"
        fi
        run_mysql "$ADMIN_DEFAULTS" < "$SQL_INPUT" >/dev/null 2>&1 || die 'account password change failed'
        if [ "$ACCOUNT_HOST" = 'localhost' ]; then
            check_login || die 'new account credentials could not be confirmed'
            if [ "$ROOT_ACCOUNT" = true ]; then
                ADMIN_DEFAULTS="$INPUT_BASE.cnf"
            fi
        fi
        inspect_account
        [ -n "$AUTH_STATE" ] && password_plugin_matches || die 'new password authentication state could not be confirmed'
        if [ "$ACCOUNT_HOST" != 'localhost' ]; then
            save_confirmation
        fi
        ;;
esac
