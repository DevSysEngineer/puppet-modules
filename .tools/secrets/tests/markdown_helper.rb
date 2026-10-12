# frozen_string_literal: true

require_relative 'test_helper'

# Markdown contributes boundaries, never exemptions from the shared detector.
class SecretsMarkdownTestCase < SecretsTest
  def inspect_markdown(source, name = 'sample.md')
    ProjectTools::Secrets::Scanner.documents({ name => source }).first
  end
end
