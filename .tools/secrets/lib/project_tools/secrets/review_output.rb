# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative 'redaction'
require_relative 'source_versions'

module ProjectTools
  module Secrets
    # Full source inspection precedes a stable-ID diff; diagnostics also use local value knowledge.
    class ReviewOutput
      def initialize(data)
        @data = data
      end

      def diff
        raise Failure, 'review_requires_applied_session' unless @data['status'] == 'applied'

        verify_sources
        { 'operation' => 'diff', 'status' => 'reviewed', 'complete' => true,
          'diff' => @data['journal'].map { |entry| safe_diff(entry) }.join,
          'integrity' => @data.fetch('integrity') }
      end

      def verify_sources
        unchanged_versions
        sources = @data['files'].to_h { |safe, file| [safe, file['original']] }
        @data['journal'].each do |entry|
          actual = verified_content(entry)

          actual ? sources[entry['file']] = actual : sources.delete(entry['file'])
        end
        Scanner.complete!(Scanner.documents(sources))
      end

      def unchanged_versions
        SourceVersions.verify_policy(@data)

        changed = @data['journal'].map { |entry| entry['file'] }
        @data['files'].each do |safe, file|
          SourceVersions.verify_file(@data['root'], file) unless changed.include?(safe)
        end
      end

      def verified_content(entry)
        path = Paths.inside(@data['root'], entry['source'])
        actual = File.exist?(path) ? SourceReader.local_read(path) : nil
        raise Failure, 'review_source_conflict' unless actual == entry['after']

        actual
      end

      def safe_diff(entry)
        Dir.mktmpdir('secrets-diff-') do |dir|
          old = File.join(dir, 'old')
          new = File.join(dir, 'new')
          Paths.write_new(old, @data['files'].fetch(entry['file'], {}).fetch('analysis', ''))
          Paths.write_new(new, @data.fetch('final_analysis').fetch(entry['file'], ''))
          compare(old, new, entry['file'])
        end
      end

      def compare(old, new, path)
        stdout, _stderr, status = Open3.capture3('diff', '-u', '--label', "a/#{path}", '--label', "b/#{path}", old, new)
        raise Failure, 'diff_failed' unless [0, 1].include?(status.exitstatus)

        Redaction.new(data: @data).diagnostics(stdout)
      end
    end
  end
end
