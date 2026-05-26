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

GREP=$(command -v grep 2>/dev/null) || exit 1
MYSQL=$(command -v mysql 2>/dev/null) || exit 1
SED=$(command -v sed 2>/dev/null) || exit 1

run_mysql() {
	$MYSQL "--defaults-file=<%= @defaults_file %>" -NBe "$1"
}

arg_database_esc="$arg_database"
arg_table_esc="$arg_table"

if [ "$arg_database" != "*" ]; then
	arg_database_esc=$(printf '%s\n' "$arg_database" | $SED 's/\\/\\\\/g')
	arg_database="\`$arg_database\`"
	arg_database_esc="\`$arg_database_esc\`"
else
	arg_database_esc="\\*"
fi

if [ "$arg_table" != "*" ]; then
	arg_table_esc=$(printf '%s\n' "$arg_table" | $SED 's/\\/\\\\/g')
	arg_table="\`$arg_table\`"
	arg_table_esc="\`$arg_table_esc\`"
else
	arg_table_esc="\\*"
fi


if [ "$arg_grant_option" = "1" ]; then
	grant_option_str=" WITH GRANT OPTION"
else
	grant_option_str=""
fi

cmd_show_grants="SHOW GRANTS FOR '$arg_username'@'$arg_hostname'"

grant_str="GRANT $arg_grant_privilege ON $arg_database.$arg_table TO '$arg_username'@'$arg_hostname'${grant_option_str}"
<% if @version == 8.0 or @version == 8.4 -%>
grep_grant_str_esc="GRANT $arg_privileges ON $arg_database_esc.$arg_table_esc TO \`$arg_username\`@\`$arg_hostname\`${grant_option_str}"
<% else -%>
grep_grant_str_esc="GRANT $arg_privileges ON $arg_database_esc.$arg_table_esc TO '$arg_username'@'$arg_hostname'\( IDENTIFIED BY PASSWORD '\*[a-zA-Z0-9]\{40\}'\)\{0,1\}${grant_option_str}"
<% end -%>

databasetable_str_esc="ON $arg_database_esc.$arg_table_esc TO"
cmd_revoke_all="REVOKE ALL PRIVILEGES ON $arg_database.$arg_table FROM '$arg_username'@'$arg_hostname'"
cmd_revoke_grant="REVOKE GRANT OPTION ON $arg_database.$arg_table FROM '$arg_username'@'$arg_hostname'"

# Actions
case "$arg_action" in
	check)
		run_mysql "$cmd_show_grants" | $SED 's/\\\\/\\/g' | $GREP -qix "$grep_grant_str_esc"
		exit $?
		;;
	grant)
		if run_mysql "$cmd_show_grants" | $SED 's/\\\\/\\/g' | $GREP -qi "$databasetable_str_esc"; then
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
