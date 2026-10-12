# frozen_string_literal: true

require 'json'
require 'stringio'
require_relative 'redaction'
require 'project_tools/shared/junit_report'

module ProjectTools
  module Secrets
    # Session metadata uses the same JUnit writer as standalone scans.
    module SessionReport
      def session_xml(result, operation)
        buffer = StringIO.new
        Shared::JunitReport.write(buffer, name: 'secrets-session', **session_counts(result)) do |xml|
          xml.testcase(name: operation, classname: 'secrets-session') do
            session_detail(xml, result)
          end
        end
        buffer.string
      end

      def session_counts(result)
        { tests: 1, failures: result['status'] == 'findings' ? 1 : 0, errors: result['complete'] ? 0 : 1 }
      end

      def session_detail(xml, result)
        detail = JSON.generate(result)
        if !result['complete']
          xml.error(detail, type: 'incomplete_operation')
        elsif result['status'] == 'findings'
          xml.failure(detail, type: 'possible_sensitive_data')
        else
          xml.tag!('system-out', detail)
        end
      end
    end

    # Present the same inspected findings as console metadata, JSON and JUnit.
    class Output
      extend SessionReport

      def initialize(documents)
        @documents = documents
      end

      def records
        redaction = Redaction.new(values: @documents.flat_map(&:values))
        @documents.each_with_index.map do |document, index|
          { id: index + 1, file: redaction.path(document.path), complete: document.complete?,
            findings: document.findings.sort_by { |item| [item[:line], item[:rule]] },
            errors: document.errors, coverage: document.coverage }
        end
      end

      def console_details
        records.flat_map { |record| record_details(record) }
      end

      def record_details(record)
        label = "#{record[:file]} | complete=#{record[:complete]} | coverage=#{record[:coverage]}"
        items = record[:findings].map do |item|
          "#{label} | line=#{item[:line]} | #{item[:kind]} | #{item[:rule]}"
        end
        items += record[:errors].map { |code| "#{label} | #{code}" }
        items << "#{label} | no_findings" if items.empty?
        items
      end

      def junit
        output = StringIO.new
        Shared::JunitReport.write(output, name: 'secrets', **counts) do |xml|
          records.each { |record| junit_case(xml, record) }
        end
        output.string
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
