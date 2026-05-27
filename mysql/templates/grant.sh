#!/bin/sh
# Managed by puppet

arg_action="$1"
arg_username="$2"
arg_hostname="$3"
arg_database="$4"
arg_table="$5"
arg_privileges="$6"
arg_grant_option="$7"
arg_grant_privilege="$8"

# Binary checks
AWK=$(command -v awk 2>/dev/null) || exit 1
GREP=$(command -v grep 2>/dev/null) || exit 1
MYSQL=$(command -v mysql 2>/dev/null) || exit 1
SED=$(command -v sed 2>/dev/null) || exit 1
SORT=$(command -v sort 2>/dev/null) || exit 1

# Run a MySQL command with the provided defaults file and return the output.
run_mysql() {
	$MYSQL "--defaults-file=<%= @defaults_file %>" -NBe "$1"
}

# Keep multi-word privileges intact while making list order and case irrelevant.
normalize_privileges() {
	printf '%s\n' "$1" \
		| $AWK -F',' '{
			for (i = 1; i <= NF; i++) {
				gsub(/^[[:space:]]+|[[:space:]]+$/, "", $i)
				if ($i != "") {
					print toupper($i)
				}
			}
		}' \
		| $SORT \
		| $AWK '
			BEGIN {
				first = 1
			}
			{
				if (!first) {
					printf ", "
				}
				printf "%s", $0
				first = 0
			}
			END {
				printf "\n"
			}
		'
}

# Quote database if they are not wildcards to handle reserved words and special characters.
if [ "$arg_database" != "*" ]; then
	arg_database="\`$arg_database\`"
fi

# Quote table name if it is not a wildcard to handle reserved words and special characters.
if [ "$arg_table" != "*" ]; then
	arg_table="\`$arg_table\`"
fi

# Create the grant option string once since it is used in multiple places.
if [ "$arg_grant_option" = "1" ]; then
	grant_option_str=" WITH GRANT OPTION"
else
	grant_option_str=""
fi

# Build the object and account strings once since they are used in multiple places. 
grant_object="$arg_database.$arg_table"
<% if @version == 8.0 or @version == 8.4 -%>
grant_account="\`$arg_username\`@\`$arg_hostname\`"
grant_account_allows_password="0"
<% else -%>
grant_account="'$arg_username'@'$arg_hostname'"
grant_account_allows_password="1"
<% end -%>

# Extract only the grant line for the requested scope and account; the caller
# normalizes the returned privilege list before comparison.
extract_grant_privileges() {
	$AWK \
		-v object="$grant_object" \
		-v account="$grant_account" \
		-v grant_option="$grant_option_str" \
		-v allow_password="$grant_account_allows_password" '
		function strip_legacy_password_tail(tail, prefix, rest, quote_pos) {
			if (allow_password != "1") {
				return tail
			}

			prefix = account " IDENTIFIED BY PASSWORD '\''"
			if (index(tail, prefix) != 1) {
				return tail
			}

			rest = substr(tail, length(prefix) + 1)
			quote_pos = index(rest, "'\''")
			if (quote_pos == 0) {
				return tail
			}

			return account substr(rest, quote_pos + 1)
		}

		BEGIN {
			marker = " ON " object " TO "
		}

		index($0, "GRANT ") == 1 {
			marker_pos = index($0, marker)
			if (marker_pos == 0) {
				next
			}

			privileges = substr($0, 7, marker_pos - 7)
			tail = substr($0, marker_pos + length(marker))
			tail = strip_legacy_password_tail(tail)

			if (tail == account grant_option) {
				print privileges
			}
		}
	'
}

# Pre-build command strings to avoid repeating logic in the action cases.
databasetable_str="ON $grant_object TO"
grant_str="GRANT $arg_grant_privilege ON $arg_database.$arg_table TO '$arg_username'@'$arg_hostname'${grant_option_str}"

# Commands
cmd_show_grants="SHOW GRANTS FOR '$arg_username'@'$arg_hostname'"
cmd_revoke_all="REVOKE ALL PRIVILEGES ON $arg_database.$arg_table FROM '$arg_username'@'$arg_hostname'"
cmd_revoke_grant="REVOKE GRANT OPTION ON $arg_database.$arg_table FROM '$arg_username'@'$arg_hostname'"

# Actions
case "$arg_action" in
	check)
		wanted_privileges=$(normalize_privileges "$arg_privileges")
		current_privileges=$(
			run_mysql "$cmd_show_grants" \
				| $SED 's/\\\\/\\/g' \
				| extract_grant_privileges \
				| while IFS= read -r privileges; do
					normalize_privileges "$privileges"
				done
		)

		printf '%s\n' "$current_privileges" | $GREP -Fxq "$wanted_privileges"
		exit $?
		;;
	grant)
		if run_mysql "$cmd_show_grants" | $SED 's/\\\\/\\/g' | $GREP -Fqi "$databasetable_str"; then
			run_mysql "$cmd_revoke_grant; $cmd_revoke_all;"
		fi
		run_mysql "$grant_str; FLUSH PRIVILEGES;"
		exit 0
		;;
	revoke)
		run_mysql "$cmd_revoke_grant; $cmd_revoke_all; FLUSH PRIVILEGES;"
		exit 0
		;;
esac
