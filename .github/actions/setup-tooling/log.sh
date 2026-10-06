# Source from the existing Bash CI step; commands still run directly in that step.
# ci_begin NAME [details|native] starts presentation; ci_end CODE STATUS COMPLETENESS closes it.
# Without an explicit outcome, EXIT preserves the code and leaves failures unclassified.

ci_activity() {
    local sleep_pid=
    local stopping=0
    # A signal can arrive between starting sleep and assigning its PID.
    # KILL also stops the disposable child before it has execed sleep.
    trap '
        stopping=1
        if [ -n "$sleep_pid" ]; then
            if kill -KILL "$sleep_pid" 2>/dev/null; then :; fi
        fi
    ' INT TERM
    while [ "$stopping" -eq 0 ]; do
        $CI_SLEEP 15 &
        sleep_pid=$!
        if [ "$stopping" -ne 0 ]; then
            if kill -KILL "$sleep_pid" 2>/dev/null; then :; fi
        fi
        if wait "$sleep_pid" 2>/dev/null; then :; fi
        if [ "$stopping" -ne 0 ]; then
            if wait "$sleep_pid" 2>/dev/null; then :; fi
            return
        fi
        printf '[PROGRESS] %s | Still running | %s s | no new results\n' "$CI_LOG_NAME" "$((SECONDS - CI_LOG_STARTED))" >&2
    done
}

ci_end() {
    local original_status="$1"
    local result="$2"
    local completeness="$3"
    trap - EXIT INT TERM
    if [ -n "$CI_ACTIVITY_PID" ] && kill "$CI_ACTIVITY_PID" 2>/dev/null; then
        if wait "$CI_ACTIVITY_PID" 2>/dev/null; then :; fi
    fi
    if [ "$CI_LOG_GROUP" = github ]; then
        printf '::endgroup::\n'
    elif [ "$CI_LOG_GROUP" = gitlab ]; then
        printf '\033[0Ksection_end:%s:project_details\r\033[0K\n' "$($CI_DATE +%s)"
    fi
    printf '\n[%s] %s\nExecution: %s\nOriginal exit status: %s\nDuration: %s s\n' \
        "$result" "$CI_LOG_NAME" "$completeness" "$original_status" "$((SECONDS - CI_LOG_STARTED))"
    if [ "$original_status" -ne 0 ]; then
        printf 'Diagnostic: native output above; status preserved by this step.\n'
    fi
    return "$original_status"
}

ci_exit() {
    local original_status="$1"
    if [ "$original_status" -eq 0 ]; then
        ci_end "$original_status" PASSED complete
    else
        ci_end "$original_status" 'Result not classified' unknown
    fi
    exit "$original_status"
}

ci_begin() {
    CI_LOG_NAME="${1//$'\n'/ }"
    CI_LOG_NAME="${CI_LOG_NAME//$'\r'/ }"
    CI_LOG_STARTED=$SECONDS
    CI_LOG_GROUP=none
    CI_ACTIVITY_PID=
    printf '[START] %s\n' "$CI_LOG_NAME"
    if [ "${2:-}" != native ]; then
        CI_SLEEP=$(command -v sleep 2>/dev/null) || {
            printf '[ERROR] %s | Cannot find sleep for CI activity\nExecution: not executed\n' "$CI_LOG_NAME" >&2
            return 127
        }
    fi
    if [ "${2:-}" = details ]; then
        if [ "${GITHUB_ACTIONS:-}" = true ]; then
            CI_LOG_GROUP=github
            printf '::group::%s\n' "${CI_LOG_NAME//%/%25}"
        elif [ "${GITLAB_CI:-}" = true ]; then
            CI_DATE=$(command -v date 2>/dev/null) || {
                printf '[ERROR] %s | Cannot find date for GitLab sections\nExecution: not executed\n' "$CI_LOG_NAME" >&2
                return 127
            }
            CI_LOG_GROUP=gitlab
            printf '\033[0Ksection_start:%s:project_details[collapsed=true]\r\033[0K%s\n' "$($CI_DATE +%s)" "$CI_LOG_NAME"
        fi
    fi
    if [ "${2:-}" != native ]; then
        ci_activity &
        CI_ACTIVITY_PID=$!
    fi
    trap 'ci_exit "$?"' EXIT
    trap 'ci_end 130 ERROR incomplete; exit 130' INT
    trap 'ci_end 143 ERROR incomplete; exit 143' TERM
}
