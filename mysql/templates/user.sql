<%
# Restrict SQL mode to this session so backslashes stay literal and only apostrophes need doubling.
quote_sql = lambda do |value|
  raise 'MySQL account input cannot contain NUL' if value.include?("\0")
  "'" + value.gsub("'", "''") + "'"
end
account = quote_sql.call(@username) + '@' + quote_sql.call(@hostname)
statement = scope.lookupvar('statement')
-%>
-- Managed by puppet
SET SESSION sql_mode = 'NO_BACKSLASH_ESCAPES';
SET NAMES utf8mb4;
<% if statement == 'inspect' -%>
<% if @authentication == 'legacy' -%>
SELECT CONCAT(COALESCE(plugin, ''), ':', HEX(Password)) FROM mysql.user WHERE User = <%= quote_sql.call(@username) %> AND Host = <%= quote_sql.call(@hostname) %>;
<% else -%>
SELECT CONCAT(plugin, ':', HEX(authentication_string), ':', password_expired) FROM mysql.user WHERE User = <%= quote_sql.call(@username) %> AND Host = <%= quote_sql.call(@hostname) %>;
<% end -%>
<% elsif statement == 'drop' -%>
DROP USER <%= account %>;
<% elsif @authentication == 'auth_socket' -%>
<%= statement.upcase %> USER <%= account %> IDENTIFIED WITH auth_socket;
<% elsif @authentication == 'legacy' && statement == 'alter' -%>
SET PASSWORD FOR <%= account %> = PASSWORD(<%= quote_sql.call(@password.unwrap) %>);
<% else -%>
<%= statement.upcase %> USER <%= account %> IDENTIFIED<% if ['mysql_native_password', 'caching_sha2_password'].include?(@authentication) %> WITH <%= @authentication %><% end %> BY <%= quote_sql.call(@password.unwrap) %>;
<% end -%>
