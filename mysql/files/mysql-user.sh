#!/bin/sh
# Managed by puppet
# Manage one account using private temporary MySQL inputs; never accept a password argument.
# Usage: mysql-user.sh ACTION DEFAULTS INPUT_BASE AUTHENTICATION ROOT_ACCOUNT ACCOUNT
# ACTION: check-present, present, check-absent, absent. Checks return 0 for convergence, 1 for drift, 2 for failure.
# Mutations repeat all preconditions and return 2 on failure. No raw client diagnostics are printed.
# Every present account must prove its desired login and account identity on each invocation.
# The calling shell owns temporary input creation and cleanup.

# Client errors can contain SQL and must never be included in the error category.
die() {
    printf 'MySQL account management: %s\n' "$1" >&2
    exit 2
}

MYSQL=$(command -v mysql 2>/dev/null) || die 'mysql client is unavailable'

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
ACCOUNT="$6"
ADMIN_DEFAULTS="$DEFAULTS"
DESIRED_WORKS=false

# Both administrative and desired connections target the same local server as the module's configuration.
run_mysql() {
    $MYSQL "--defaults-file=$1" --protocol=socket --socket=/var/run/mysqld/mysqld.sock \
        --connect-timeout=5 --default-character-set=utf8mb4 --batch --raw --skip-column-names --binary-mode
}

# Desired credentials are not proven by a successful socket-authenticated connection alone.
# Return 1 only for authentication denial; a different account or technical error aborts before mutation.
check_login() {
    login_result=$(printf '%s\n' 'SELECT CURRENT_USER();' | run_mysql "$INPUT_BASE.cnf" 2>&1)
    login_status=$?
    if [ "$login_status" -eq 0 ]; then
        [ "$login_result" = "$ACCOUNT" ] || die 'desired-credential login selected a different account'
    else
        case "$login_result" in
            'ERROR 1045 '*|'ERROR 1698 '*|'ERROR 1820 '*) return 1 ;;
            *) die 'desired-credential connection failed for a technical reason' ;;
        esac
    fi
}

# Accept socket authentication only when explicitly selected; password modes must prove a password-backed plugin.
authentication_matches() {
    case "$AUTHENTICATION" in
        auth_socket|caching_sha2_password)
            [ "${AUTH_STATE%%:*}" = "$AUTHENTICATION" ] && [ "${AUTH_STATE##*:}" = N ]
            return $?
            ;;
    esac
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

# A successful login must belong to this account and use the requested authentication plugin.
account_matches() {
    [ "$DESIRED_WORKS" = true ] && [ -n "$AUTH_STATE" ] && authentication_matches
}

# Reject incomplete input before establishing connections or changing an account.
[ "$#" -eq 6 ] || die 'invalid helper arguments'
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
        if check_login; then
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

# Checks never change accounts.
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
        run_mysql "$ADMIN_DEFAULTS" < "$SQL_INPUT" >/dev/null 2>&1 || die 'account authentication change failed'
        check_login || die 'new account credentials could not be confirmed'
        if [ "$ROOT_ACCOUNT" = true ]; then
            ADMIN_DEFAULTS="$INPUT_BASE.cnf"
        fi
        inspect_account
        [ -n "$AUTH_STATE" ] && authentication_matches || die 'new account authentication state could not be confirmed'
        ;;
esac
