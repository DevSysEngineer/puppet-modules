# frozen_string_literal: true

require 'project_lint/metadata'

# Register native selection/disable controls; the CLI checks metadata once per project scan.
PuppetLint.new_check(:project_metadata) do
  def check; end
end
