# frozen_string_literal: true

require 'puppet'

# Install synthetic foreign settings before the worker configures its isolated environment.
module SyntheticCatalogSettings
  def initialize_settings(*arguments)
    super
    self[:hiera_config] = File.join(ENV.fetch('CATALOG_TEST_FOREIGN'), 'hiera.yaml')
    self[:environmentpath] = ENV.fetch('CATALOG_TEST_FOREIGN')
    File.write(File.join(ENV.fetch('CATALOG_TEST_ROOT'), 'foreign-settings-used'), 'synthetic settings installed')
  end
end
Puppet.singleton_class.prepend(SyntheticCatalogSettings)
