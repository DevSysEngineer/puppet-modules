# frozen_string_literal: true

require 'project_lint/metadata_document'

module ProjectLint
  # Read and repair one metadata object, retaining independent write/read diagnostics.
  class MetadataFile
    attr_reader :problems

    def initialize(root, path, version:, name:, fix:)
      @path = File.join(root, path)
      @root_file = path == 'metadata.json'
      @version = version
      @name = name
      @fix = fix
      @problems = []
    end

    def read
      source = File.read(@path)
      object(source)
    rescue JSON::ParserError, EncodingError
      report('metadata: invalid JSON; expected a JSON object')
    rescue Errno::ENOENT
      missing
    rescue SystemCallError
      report('metadata: cannot read metadata.json; expected a readable file')
    end

    def object(source)
      data = JSON.parse(source)
      return report('metadata: expected a JSON object') unless data.is_a?(Hash)

      synchronize(source, data) if @fix
      data
    end

    def missing
      return create if @fix

      location = @root_file ? 'the project root' : 'every module directory'
      report("metadata: missing metadata.json; expected a file in #{location}")
    end

    def synchronize(source, data)
      values = known_changes(data)
      return if values.empty?

      replacement = values.reduce(source) { |text, (key, value)| MetadataDocument.new(text).with_field(key, value) }
      return unless write(source, replacement)

      data.merge!(values)
      report('version: synchronized from VERSION', :fixed) if values.key?('version')
      report('name: filled from the configured project identity', :fixed) if values.key?('name')
    rescue ArgumentError => e
      report(e.message)
    end

    def known_changes(data)
      values = {}
      values['version'] = @version if @version && data['version'] != @version
      values['name'] = @name if @name && !data.key?('name')
      values
    end

    def create
      data = { 'name' => @name, 'version' => @version }.compact
      if data.empty?
        return report('metadata: cannot create metadata.json; provide a valid VERSION or configured module owner')
      end
      return unless write(nil, "#{JSON.pretty_generate(data)}\n")

      report('metadata: created known fields; remaining errors identify required metadata', :fixed)
      data
    end

    def write(source, replacement)
      if File.symlink?(@path)
        return report('metadata: autofix skips symbolic links; provide a project-owned regular file')
      end

      flags = source ? File::RDWR : File::WRONLY | File::CREAT | File::EXCL
      File.open(@path, flags | File::NOFOLLOW) { |file| replace(file, source, replacement) }
    rescue SystemCallError, IOError
      report('metadata: cannot write autofix; check file and directory permissions')
    end

    def replace(file, source, replacement)
      if source && file.read != source
        return report('metadata: changed during inspection; rerun before applying autofix')
      end

      file.rewind
      file.write(replacement)
      file.truncate(file.pos)
      true
    end

    def report(message, kind = :error)
      @problems << [message, kind]
      nil
    end
  end
end
