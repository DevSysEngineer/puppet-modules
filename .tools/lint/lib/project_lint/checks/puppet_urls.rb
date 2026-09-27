# frozen_string_literal: true

# Project-owned Puppet lint rules.
module ProjectLint
  # Native checks and their local analyses.
  module Checks
    # Implements the project_puppet_urls check through the native Puppet-lint contract.
    module PuppetUrls
      def check
        tokens.each do |token|
          # Keep the upstream scope: literal strings and the fixed prefix before interpolation, including source arrays.
          next unless %i[SSTRING STRING DQPRE].include?(token.type) && token.value.start_with?('puppet://')
          next if token.value.match?(%r{\Apuppet://[^/]*/(?:modules|files)/})

          notify(:warning, message: 'puppet:// URL must use a modules/ or files/ mount', line: token.line,
                           column: token.column)
        end
      end

      # No automatic fix: choosing a mount changes the source and requires knowledge of the fileserver layout.
    end
    PuppetLint.new_check(:project_puppet_urls) { include PuppetUrls }

    # Upstream inserts modules/ even for configured files/ mounts; only the operator knows the intended source.
    module PreservePuppetMount
      def fix(_problem)
        raise PuppetLint::NoFix
      end
    end
    PuppetLint.configuration.check_object.fetch(:puppet_url_without_modules).prepend(PreservePuppetMount)
  end
end
