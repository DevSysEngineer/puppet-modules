# frozen_string_literal: true

require_relative '../session_helper'

# Shared publication assertions for the shell regressions below.
module SecretsShellValuesHelper
  def inspect_script(source, name: 'script.sh')
    path = write(name, source)
    scan(path)
    assert_complete_scan
    prepare([name])
    assert_source(path, source)
    analysis(name)
  end
end
