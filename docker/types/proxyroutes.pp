# @summary Additional literal path prefixes and upstream ports for Docker reverse proxies.
#
# The root backend remains configured by proxy_port. Each additional route requires a port and may provide a URI
# path that replaces its matched prefix. Other upstream settings belong to docker::proxy and apply to every route.
# See docker::proxy::proxy_routes for matching and inheritance behavior.
#
# @api public
type Docker::ProxyRoutes = Hash[Pattern[/\A\/[-A-Za-z0-9_.~][-A-Za-z0-9\/_.~]*\z/], Struct[{
  port          => Integer[1, 65535],
  Optional[uri] => Pattern[/\A\/[-A-Za-z0-9\/_.~]*\z/],
}]]
