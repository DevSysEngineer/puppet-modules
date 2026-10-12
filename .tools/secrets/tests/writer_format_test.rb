# frozen_string_literal: true

require_relative 'session_helper'
require 'erb'

# Format selection is exercised through restored files, never by evaluating input.
class SecretsWriterFormatTest < SecretsSessionTestCase
  def rewrite(source, path: 'script.sh', error: nil)
    original = write(path, source)
    File.chmod(0o750, original)
    before = file_metadata(original)
    prepare([path])
    edit(path, "#{analysis(path)}\n# ordinary edit\n")
    apply('write' => [path])
    assert_rewrite_result(original, source, error)
    assert_equal before, file_metadata(original)
  end

  def assert_rewrite_result(original, source, error)
    if error
      assert_equal 'refused', @result['status']
      assert_includes @result['errors'], error
      assert_source(original, source)
    else
      assert_applied
      assert_source(original, "#{source}\n# ordinary edit\n")
    end
  end

  def test_valid_posix_shell
    rewrite("#!/bin/sh\nif true; then\n  printf '%s\\n' before\nfi\n")
  end

  def test_invalid_posix_shell
    rewrite("#!/bin/sh\nif true; then\n", error: 'invalid_shell')
  end

  def test_bash_arrays_keep_the_bash_parser
    rewrite("#!/bin/bash\n# Arrays require Bash.\nitems=(one two)\nprintf '%s\\n' \"${items[@]}\"\n")
  end

  def test_invalid_bash
    rewrite("#!/bin/bash\nif true; then\n", error: 'invalid_shell')
  end

  def test_literal_erb_opening_in_shell
    rewrite("#!/bin/sh\nprintf '%s\\n' '<%'\n", path: 'files/script.sh')
  end

  def test_literal_complete_tag_does_not_disable_shell_validation
    rewrite("#!/bin/sh\nprintf '%s\\n' '<%= 1 %>'\nif true; then\n",
            path: 'files/script.sh', error: 'invalid_shell')
  end

  def test_literal_opening_under_templates_still_checks_shell
    rewrite("#!/bin/sh\nprintf '%s\\n' '<%'\nif true; then\n",
            path: 'templates/script.sh', error: 'invalid_shell')
  end

  def test_erb_with_shell_extension_and_trim_tags
    source = "#!/bin/sh\n<%- if true -%>\nprintf '%s\\n' <%= 'before'.inspect %>\n<%- end -%>\n"
    rewrite(source, path: 'example/templates/script.sh')
    rendered = ERB.new(source, trim_mode: '-').result
    _out, _err, status = Open3.capture3('sh', '-n', stdin_data: rendered)
    assert status.success?, 'Fixed synthetic ERB did not render valid POSIX shell'
  end

  def test_erb_extension_with_trim_tags_and_bash_output
    source = "#!/bin/bash\n# Arrays require Bash.\n<% if true -%>\nitems=(one two)\n<% end -%>\n"
    rewrite(source, path: 'script.sh.erb')
    rendered = ERB.new(source, trim_mode: '-').result
    _out, _err, status = Open3.capture3('bash', '-n', stdin_data: rendered)
    assert status.success?, 'Fixed synthetic ERB did not render valid Bash'
  end

  def test_extensionless_repository_template
    rewrite("<%= 'ordinary' %>\n", path: 'example/templates/settings')
  end

  def test_invalid_ruby_in_shell_template
    rewrite("#!/bin/sh\nprintf '%s\\n' <%= (1 +) %>\n",
            path: 'templates/script.sh', error: 'invalid_template')
  end

  def test_invalid_ruby_in_erb
    rewrite("<%= (1 +) %>\n", path: 'script.erb', error: 'invalid_template')
  end

  def test_template_code_is_not_executed
    rewrite("<% raise 'synthetic template must not execute' %>\n", path: 'templates/script.sh')
  end
end
