# frozen_string_literal: true

module PuppetX
  # Render once all primary and redirect vhosts have registered their sockets.
  class NginxDefaultServers
    def initialize(resource)
      @servers = resource[:servers]
      @sockets = Hash.new { |table, socket| table[socket] = { options: {} } }
      resource[:baseline].each { |address| @sockets["tcp #{address}"] }
      resource[:listeners].each { |participant| add_listener(participant) }
      resource[:options].each { |option| add_option(option) }
    end

    def content
      groups = @sockets.group_by { |_socket, entry| entry[:protocol] ? 'https' : 'http' }
      blocks = %w[http https].filter_map do |group|
        next unless groups.key?(group)

        lines = groups[group].map { |socket, entry| listen_line(socket, entry) }
        format(@servers.fetch(group), listeners: lines.sort.join("\n"))
      end
      "# Managed by puppet\n\n#{blocks.join("\n")}"
    end

    def reload_on_change?(path, desired)
      manual = @sockets.select { |_socket, entry| entry[:restart] == false }
      return true if manual.empty?

      # The native File always synchronizes. Only changes on participating automatic sockets trigger a reload.
      reloadable_blocks(File.binread(path), manual) != reloadable_blocks(desired, manual)
    rescue Errno::ENOENT
      true
    end

    private

    def add_listener(participant)
      entry = @sockets[participant.fetch('socket')]
      protocol = participant['protocol']
      entry[:protocol] = protocol if %w[ssl quic].include?(protocol)
      entry[:restart] ||= participant.fetch('restart')
    end

    def add_option(option)
      socket, setting, value = option.values_at('socket', 'setting', 'value')
      @sockets[socket][:options][setting] = value
    end

    def listen_line(socket, entry)
      address = socket.split(' ', 2).last
      options = entry[:options].sort.map { |key, value| value == true ? key : "#{key}=#{value}" }
      arguments = [address, entry[:protocol], *options, 'default_server'].compact
      "    listen #{arguments.join(' ')};"
    end

    def reloadable_blocks(content, manual)
      content.split(/(?=^server \{)/).filter_map do |block|
        lines = block.lines
        visible = lines.reject { |line| manual.key?(listen_socket(line)) }
        remaining = visible.join.rstrip
        # An entirely manual block may appear or disappear. Changes to its handler still require a reload.
        remaining unless visible.size < lines.size && empty_server?(remaining)
      end
    end

    def empty_server?(block)
      @empty_servers ||= @servers.values.map { |template| template.sub(/^%\{listeners\}\n/, '').rstrip }
      @empty_servers.include?(block)
    end

    def listen_socket(line)
      arguments = line[/^    listen (.+);$/, 1]
      return unless arguments

      address, *options = arguments.split
      transport = options.include?('quic') ? 'udp' : 'tcp'
      "#{transport} #{address}"
    end
  end
end

Puppet::Type.newtype(:nginx_default_config) do
  @doc = 'Builds the HTTP and TLS fallback servers for the nginx class.'

  newparam(:path, namevar: true) { desc 'Absolute path of the managed Nginx configuration.' }
  newparam(:baseline) { desc 'HTTP addresses opened by the class without a vhost.' }
  newparam(:servers) { desc 'Rendered HTTP and HTTPS server templates with a listeners placeholder.' }
  newparam(:listeners) do
    desc 'Socket, protocol and reload preference contributed by each vhost.'
    defaultto { [] }
  end
  newparam(:options) do
    desc 'Socket, option and value registered once per effective setting.'
    defaultto { [] }
  end

  autorequire(:file) { [self[:path]] }

  def generate
    servers = PuppetX::NginxDefaultServers.new(self)
    content = servers.content
    attributes = { path: self[:path], ensure: :file, owner: 'root', group: 'root', mode: '0600', content: content }
    attributes[:notify] = 'Service[nginx]' if servers.reload_on_change?(self[:path], content)
    [Puppet::Type.type(:file).new(attributes)]
  end
end
