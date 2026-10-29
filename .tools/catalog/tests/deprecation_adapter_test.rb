# frozen_string_literal: true

require_relative '../../shared/test_support/bootstrap'

# Mutate only isolated processes; simulations do not claim support for unexecuted releases.
class CatalogDeprecationAdapterTest < Minitest::Test
  def probe(mutation, assertion)
    script = probe_script(mutation, assertion)
    output, errors, status = Open3.capture3(RbConfig.ruby, '-e', script)
    assert status.success?, output + errors
  end

  def probe_script(mutation, assertion)
    <<~RUBY
      require 'project_tools/shared/puppet_runtime'
      ProjectTools::Shared::PuppetRuntime.load!
      require #{File.expand_path('../lib/deprecations', __dir__).inspect}
      Puppet::Util::Log.level = :err
      Puppet.deprecation_warning('preexisting synthetic warning', 'preexisting')
      original = $deprecation_warnings
      #{mutation}
      detector = ProjectTools::Catalog::Deprecations.new
      #{assertion}
    RUBY
  end

  def rejected
    <<~RUBY
      begin
        detector.start
        abort 'incompatible registration accepted'
      rescue ProjectTools::Catalog::Deprecations::DetectionError
        abort 'probe discarded previous warnings' unless original['preexisting'] == 'preexisting synthetic warning'
      end
    RUBY
  end

  def test_absent_or_silent_native_registration_is_not_success
    ['Puppet.singleton_class.undef_method(:puppet_deprecation_warning)',
     'Puppet.define_singleton_method(:puppet_deprecation_warning) { |*| nil }'].each do |mutation|
      probe(mutation, rejected)
    end
  end

  def test_changed_language_diagnostic_interface_is_not_success
    probe('Puppet::Pops::Validation::Acceptor.class_eval { def warnings; []; end }', rejected)
  end

  def test_probe_preserves_prior_warnings_and_discovers_a_smaller_registration_limit
    mutation = smaller_registry
    assertion = <<~RUBY
      detector.start
      abort 'registry replaced' unless original.equal?($deprecation_warnings)
      abort 'probe leaked' unless original.size == 2
      4.times { |index| Puppet.deprecation_warning('synthetic warning', index) }
      abort 'coverage reported complete' unless detector.result[:deprecation_error]
    RUBY
    probe(mutation, assertion)
  end

  def smaller_registry
    <<~RUBY
      Puppet.singleton_class.prepend(Module.new do
        def puppet_deprecation_warning(*arguments, **options)
          super if $deprecation_warnings.size < 5
        end
      end)
    RUBY
  end
end
