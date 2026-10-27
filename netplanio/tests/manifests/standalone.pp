include netplanio

netplanio::ethernet { 'eth0': }

# Use an open synthetic network; no wireless credentials are required to compile.
netplanio::wifi { 'wlan0':
  access_points => { 'compile-example' => {} },
}
