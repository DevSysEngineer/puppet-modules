# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'metadata_support'

# Validate the declared project metadata structure without claiming semantic content review.
class RootMetadataStructureTest < Minitest::Test
  include MetadataSupport

  def problems(data)
    ProjectLint::RootMetadata.new(data, version: '7.4.0').problems
  end

  def test_top_level_strings_and_arrays_have_the_documented_types
    (ProjectLint::RootMetadata::STRINGS - ['version']).each do |field|
      [nil, '', ' ', 1].each do |value|
        assert_equal ["#{field}: expected a non-empty string"], problems(project_metadata.merge(field => value))
      end
    end
    ProjectLint::RootMetadata::ARRAYS.each do |field|
      assert_equal ["#{field}: expected an array"], problems(project_metadata.merge(field => {}))
    end
  end

  def test_dependency_and_requirement_entries_need_names_and_version_constraints
    %w[dependencies requirements].each do |field|
      assert_equal ["#{field}[0]: expected a JSON object"], problems(project_metadata.merge(field => [false]))
      assert_equal ["#{field}[0].version_requirement: expected a non-empty string"],
                   problems(project_metadata.merge(field => [{ 'name' => 'example-library' }]))
    end
  end

  def test_invalid_root_versions_report_actual_and_expected_values_once
    { nil => 'nil', '' => '""', 1 => '1' }.each do |value, actual|
      assert_equal ["version: expected 7.4.0 from VERSION; found #{actual}"],
                   problems(project_metadata.merge('version' => value))
    end
  end

  def test_platforms_releases_and_tags_keep_the_example_structure
    data = project_metadata.merge('operatingsystem_support' => [{ 'operatingsystem' => 'Debian' }])
    assert_equal ['operatingsystem_support[0].operatingsystemrelease: expected an array'], problems(data)
    data['operatingsystem_support'][0]['operatingsystemrelease'] = [12]
    assert_equal ['operatingsystem_support[0].operatingsystemrelease[0]: expected a non-empty string'], problems(data)
    assert_equal ['tags[0]: expected a non-empty string'], problems(project_metadata.merge('tags' => [nil]))
  end

  def test_projects_without_dependencies_or_platforms_can_use_empty_arrays
    data = project_metadata.merge(ProjectLint::RootMetadata::ARRAYS.to_h { |field| [field, []] })
    assert_empty problems(data)
  end
end
