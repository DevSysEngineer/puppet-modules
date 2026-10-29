# frozen_string_literal: true

require_relative '../test_support/bootstrap'

# Isolated interface stubs do not activate or install a Puppet runtime.
class RuntimeInterfacesTest < Minitest::Test
  def test_runtime_free_reporting_does_not_load_puppet
    script = <<~RUBY
      require 'project_tools/shared/console'
      ProjectTools::Shared::Console.software('synthetic', version: '1.0')
      abort 'runtime loaded' if defined?(Puppet)
    RUBY
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', script)
    assert status.success?, errors
    assert_empty output
    assert_includes errors, 'Puppet runtime: not required'
  end

  def test_missing_or_changed_parser_api_fails_without_loading_a_runtime
    ['Class.new', 'Class.new { def parse_string(*); Object.new; end }'].each do |parser_class|
      script = parser_script(parser_class)
      output, errors, status = Open3.capture3(RbConfig.ruby, '-e', script)
      assert status.success?, errors
      assert_includes output, 'required syntax-tree interface'
    end
  end

  def parser_script(parser_class)
    <<~RUBY
      require 'project_tools/shared/puppet_runtime'
      runtime = ProjectTools::Shared::PuppetRuntime
      runtime.define_singleton_method(:load!) { |*| nil }
      module Puppet; module Pops; module Parser; end; end; end
      Puppet::Pops::Parser.const_set(:EvaluatingParser, #{parser_class})
      begin
        runtime.parser
        abort 'incompatible interface accepted'
      rescue ProjectTools::Shared::PuppetRuntime::Error => error
        puts error.message
      end
    RUBY
  end
end
