# frozen_string_literal: true

module ProjectLint
  # Native NEWLINE rendering otherwise discards the restored CRLF spelling.
  module ArrayLineEndings
    def to_manifest
      type == :NEWLINE && value == "\r\n" ? value : super
    end
  end

  # Preserve source line endings even in opaque strings and comments.
  module ArraySourceEndings
    def load_data(fileinfo, data)
      super
      return unless (enabled_checks & %i[project_layout 2sp_soft_tabs]).any? && data.include?("\r\n")

      lines = data.lines
      PuppetLint::Data.tokens.each { |part| restore_part_endings(part, lines) }
    end

    def restore_part_endings(part, lines)
      part.value = restore_endings(part.value, part.line, lines)
      part.raw = restore_endings(part.raw, part.line, lines) if part.respond_to?(:raw)
    end

    def restore_endings(value, first_line, lines)
      return value unless value.is_a?(String) && value.include?("\n")

      line = first_line - 1
      value.gsub(/\r?\n/) do
        ending = lines[line]&.end_with?("\r\n") ? "\r\n" : "\n"
        line += 1
        ending
      end
    end
  end

  # Keep fixed history while replacing active diagnostics with the final-source findings.
  module ArrayDiagnosticReconciliation
    def reconciled_problems(previous, final, current)
      remaining = current.map { |problem| diagnostic_key(problem) }.tally
      resolved = previous.filter_map { |problem| resolved_problem(problem, remaining) }
      append_final_fixes(resolved, final) + current
    end

    def append_final_fixes(resolved, final)
      recorded = resolved.map { |problem| diagnostic_key(problem) }.tally
      final.each do |problem|
        resolved << problem if problem[:kind] == :fixed && !consume_diagnostic?(recorded, problem)
      end
      resolved
    end

    def resolved_problem(problem, remaining)
      return problem if problem[:kind] == :fixed
      return if problem[:kind] == :ignored || consume_diagnostic?(remaining, problem)

      problem.merge(kind: :fixed)
    end

    def consume_diagnostic?(counts, problem)
      key = diagnostic_key(problem)
      return false unless counts.fetch(key, 0).positive?

      counts[key] -= 1
      true
    end

    def diagnostic_key(problem)
      problem.values_at(:check, :message)
    end
  end

  # Array decisions use the final source, after native fixes have consumed their original anchors.
  module FinalArrayLayout
    include ArrayDiagnosticReconciliation

    def run(fileinfo, data)
      result = super
      return result unless finalize_arrays?(fileinfo, result)

      load_data(fileinfo, manifest)
      final = finish_array_check
      return result if final.empty? && result.none? { |problem| array_finding?(problem) }

      final.concat(final_resource_indents(fileinfo))
      load_data(fileinfo, manifest)
      @problems = reconciled_problems(result, final, current_findings)
    end

    # A title array changes the attribute level when it expands or collapses.
    # Replan value arrays once after correcting those prefixes; title decisions
    # depend on resource headers and cannot be changed by attribute prefixes.
    def final_resource_indents(fileinfo)
      return [] unless enabled_checks.include?(:'2sp_soft_tabs')

      load_data(fileinfo, manifest)
      problems = finish_resource_check
      return [] unless problems.any? { |problem| problem[:kind] == :fixed }

      load_data(fileinfo, manifest)
      problems + finish_array_check
    end

    def finish_resource_check
      check = PuppetLint.configuration.check_object.fetch(:'2sp_soft_tabs').new
      check.run
      check.fix_problems
    end

    def finish_array_check
      PuppetLint.configuration.check_object.fetch(:project_layout).new.finish_arrays
    end

    def finalize_arrays?(fileinfo, result)
      PuppetLint.configuration.fix && enabled_checks.include?(:project_layout) &&
        !File.extname(fileinfo).match?(/\.ya?ml\z/i) && result.none? { |problem| problem[:check] == :syntax }
    end

    def current_findings
      enabled_checks.flat_map { |name| PuppetLint.configuration.check_object.fetch(name).new.run }
    end

    def array_finding?(problem)
      problem[:check] == :project_layout && ArrayLayout::MESSAGES.values.any? do |message|
        problem[:message].start_with?(message)
      end
    end
  end
end

PuppetLint::Checks.prepend(ProjectLint::ArraySourceEndings)
PuppetLint::Checks.prepend(ProjectLint::FinalArrayLayout)
PuppetLint::Lexer::Token.prepend(ProjectLint::ArrayLineEndings)
