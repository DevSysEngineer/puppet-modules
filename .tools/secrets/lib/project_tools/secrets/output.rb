# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'project_tools/shared/junit_report'

module ProjectTools
  module Secrets
    # Only sanitized snapshots are written, using new private destinations.
    class Output
      def initialize(documents, sources)
        @documents = documents
        @sources = sources.map { |path| File.exist?(path) ? File.realpath(path) : File.expand_path(path) }
      end

      def safe_path(path)
        result = path.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
        @documents.flat_map(&:values).reject(&:empty?).uniq.sort_by { |value| -value.length }.each do |value|
          result = result.gsub(value, '[REDACTED]')
        end
        result.gsub(Patterns::TOKENS, '[REDACTED]').gsub(/[[:cntrl:]]/, '?')
      end

      def records
        @documents.each_with_index.map do |document, index|
          { id: index + 1, file: safe_path(document.path), complete: document.complete?,
            findings: document.findings.sort_by { |item| [item[:line], item[:rule]] },
            errors: document.errors, copy: document.copy }
        end
      end

      def console_details
        records.flat_map { |record| record_details(record) }
      end

      def record_details(record)
        label = "#{record[:file]} | complete=#{record[:complete]}"
        items = record[:findings].map do |item|
          "#{label} | line=#{item[:line]} | #{item[:kind]} | #{item[:rule]}"
        end
        items += record[:errors].map { |code| "#{label} | #{code}" }
        items << "#{label} | copy=#{record[:copy]}" if record[:copy]
        items << "#{label} | no_findings" if items.empty?
        items
      end

      def destination(path)
        raise ArgumentError if path.empty?

        parent = File.realpath(File.dirname(File.expand_path(path)))
        target = File.join(parent, File.basename(path))
        raise ArgumentError if File.exist?(target) || File.symlink?(target)
        raise ArgumentError if @sources.any? { |source| target == source || target.start_with?("#{source}/") }

        target
      end

      def redact(directory)
        target = destination(directory)
        Dir.mkdir(target, 0o700)
        begin
          write_copies(target)
        rescue StandardError, SignalException
          @documents.each { |document| document.copy = nil }
          FileUtils.remove_entry(target)
          raise
        end
      end

      def write_copies(target)
        @documents.each_with_index do |document, index|
          name = format('file-%06d.txt', index + 1)
          File.open(File.join(target, name), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
            file.write(document.sanitized)
          end
          document.copy = name
        end
      end

      def junit(path)
        File.open(destination(path), File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
          Shared::JunitReport.write(file, name: 'secrets', **counts) do |xml|
            records.each { |record| junit_case(xml, record) }
          end
        end
      end

      def counts
        { tests: @documents.length,
          failures: @documents.count { |doc| doc.complete? && !doc.findings.empty? },
          errors: @documents.count { |doc| !doc.complete? } }
      end

      def junit_case(xml, record)
        xml.testcase(name: record[:file], classname: 'secrets') do
          detail = JSON.generate(record)
          if !record[:complete]
            xml.error(detail, type: 'incomplete_scan')
          elsif !record[:findings].empty?
            xml.failure(detail, type: 'possible_sensitive_data')
          end
        end
      end
    end
  end
end
