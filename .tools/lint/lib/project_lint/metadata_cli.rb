# frozen_string_literal: true

module ProjectLint
  # Carry non-manifest findings through the native CLI's reporting and exit-status loop.
  class MetadataPath < String
    def initialize(path, scan)
      super(path)
      @scan = scan
    end

    def findings
      @scan.results.fetch(to_s, [])
    end
  end

  # Defer writes until native option parsing and file selection have completed.
  class MetadataScan
    def initialize(metadata)
      @metadata = metadata
    end

    def results
      @results ||= @metadata.findings(fix: PuppetLint.configuration.fix)
    end
  end

  # The native CLI discovers only Puppet/YAML files, so extend selection after option parsing.
  module MetadataOptions
    def build(arguments = [])
      parser = super
      extend_metadata_selection(arguments) if metadata_scan?(arguments)
      parser
    end

    def metadata_scan?(arguments)
      config = PuppetLint.configuration
      config.checks.include?(:project_metadata) && config.project_metadata_enabled? &&
        !arguments.empty? && !config.display_version && !config.list_checks
    end

    def extend_metadata_selection(arguments)
      metadata = Metadata.new
      findings = metadata.findings
      if File.directory?(arguments.first)
        directory = arguments.first
        arguments.replace(Dir.glob(["#{directory}/**/*.pp", "#{directory}/**/*.{yaml,yml}"]))
      end
      arguments.reject! do |argument|
        PuppetLint.configuration.ignore_paths.any? { |pattern| File.fnmatch(pattern, argument) }
      end
      append_metadata(arguments, findings, MetadataScan.new(metadata))
    end

    def append_metadata(arguments, findings, scan)
      findings.each do |path, problems|
        explicit = arguments.reject! { |argument| File.expand_path(argument) == File.expand_path(path) }
        next if problems.empty? && !explicit && !arguments.empty?

        arguments << MetadataPath.new(path, scan)
      end
    end
  end

  # Metadata never passes through the Puppet parser or the manifest autofixer.
  module MetadataInput
    def file=(path)
      @metadata_findings = path.is_a?(MetadataPath) ? path.findings : nil
      if @metadata_findings
        @path = path
      else
        super
      end
    end

    def run
      return super unless @metadata_findings

      @problems = @metadata_findings
      @statistics = { error: 0, warning: 0, fixed: 0 }.merge(@problems.map { |problem| problem[:kind] }.tally)
    end

    def get_context(message)
      @metadata_findings ? nil : super
    end

    def supports_fixes?
      !@metadata_findings && super
    end
  end
end

PuppetLint::OptParser.singleton_class.prepend(ProjectLint::MetadataOptions)
PuppetLint.prepend(ProjectLint::MetadataInput)
