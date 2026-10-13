# frozen_string_literal: true

require_relative 'shell_helper'

# Quoting and expansion must never leave a suffix of an embedded value visible.
class SecretsShellBoundsTest < SecretsSessionTestCase
  include SecretsShellValuesHelper

  def test_adjacent_quotes_escapes_and_multiline_parts_are_one_word
    source = <<~SH
      #!/bin/sh
      password='first-part'"second-part"third\\ part\\
      last-part printf ordinary
    SH
    copy = inspect_script(source)
    %w[first-part second-part third last-part].each do |part|
      refute_includes copy, part
    end
    assert_includes copy, 'printf ordinary'
  end

  def test_shell_commas_are_part_of_the_value_and_pipes_end_arguments
    source = "#!/bin/sh\npassword=first,second|cat\nclient --token third,fourth&&echo ordinary\n"
    copy = inspect_script(source)
    %w[first second third fourth].each { |part| refute_includes copy, part }
    assert_includes copy, '|cat'
    assert_includes copy, '&&echo ordinary'
  end

  def test_quoted_default_and_nested_expansions_remain_one_word
    source = <<~SH
      #!/bin/sh
      password="${VALUE:-"first-part second-part"}" ordinary
      token=${VALUE:-${OTHER:-"third-part fourth-part"}} following
      secret="$(printf '%s' 'fifth-part sixth-part')" tail
    SH
    copy = inspect_script(source)
    %w[first-part second-part third-part fourth-part fifth-part sixth-part].each do |part|
      refute_includes copy, part
    end
    %w[ordinary following tail].each { |part| assert_includes copy, part }
  end

  def test_continued_option_argument_and_empty_assignment
    source = "#!/bin/sh\nclient --token \\\n    #{@value} next-argument\n" \
             "password= echo ordinary\nsecret=\n    echo following\n"
    copy = inspect_script(source)
    refute_includes copy, @value
    assert_includes copy, ' next-argument'
    assert_includes copy, "password= echo ordinary\nsecret=\n    echo following\n"
  end

  def test_single_quoted_reference_and_quoted_lookup_are_literal_values
    source = "#!/bin/sh\npassword='$VALUE'\nsecret=\"lookup('example')\"\n"
    copy = inspect_script(source)
    refute_includes copy, '$VALUE'
    refute_includes copy, "lookup('example')"
  end

  def test_backslash_before_closing_single_quote
    source = "#!/bin/sh\nsecret='literal\\'\"quoted-tail\" following\n"
    copy = inspect_script(source)
    refute_includes copy, 'literal'
    refute_includes copy, 'quoted-tail'
    assert_includes copy, ' following'
  end

  def test_multiline_quoted_option_with_adjacent_part
    source = "#!/bin/sh\nclient --token 'one-line\ntwo-line'\"three-line\" next-argument\n"
    copy = inspect_script(source)
    %w[one-line two-line three-line].each { |part| refute_includes copy, part }
    assert_includes copy, 'next-argument'
  end

  def test_shell_comments_and_literal_bodies_keep_conservative_value_boundaries
    source = <<~SH
      #!/bin/sh
      # password=first-part second-part
      payload='
      password=third-part fourth-part
      '
    SH
    copy = inspect_script(source)
    %w[first-part second-part third-part fourth-part].each { |part| refute_includes copy, part }
  end

  def test_heredoc_data_keeps_conservative_value_boundaries
    source = "#!/bin/sh\ncat <<DATA\npassword=first-part second-part\nDATA\necho ordinary\n"
    copy = inspect_script(source)
    %w[first-part second-part].each { |part| refute_includes copy, part }
    assert_includes copy, 'echo ordinary'
  end
end
