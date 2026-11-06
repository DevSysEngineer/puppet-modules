# frozen_string_literal: true

require_relative '../test_support/bootstrap'
require 'project_tools/shared/atomic_file'

# Report producers publish complete bytes while failed writers leave no partial target.
class SharedAtomicFileTest < Minitest::Test
  def setup
    @root = Dir.mktmpdir('atomic publication ')
    @destination = File.join(@root, 'report.xml')
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def test_publication_replaces_the_destination_only_after_the_writer_finishes
    File.write(@destination, 'previous')
    ProjectTools::Shared::AtomicFile.write(@destination) do |output|
      output.write('complete report')
      assert_equal 'previous', File.read(@destination)
    end
    assert_equal 'complete report', File.read(@destination)
    assert_equal 0o600, File.stat(@destination).mode & 0o777
    assert_equal ['report.xml'], Dir.children(@root)
  end

  def test_writer_failure_preserves_existing_content_and_removes_partial_output
    File.write(@destination, 'previous')
    actual = assert_raises(IOError) do
      ProjectTools::Shared::AtomicFile.write(@destination) do |output|
        output.write('partial')
        raise IOError, 'synthetic writer failure'
      end
    end
    assert_equal 'synthetic writer failure', actual.message
    assert_equal 'previous', File.read(@destination)
    assert_equal ['report.xml'], Dir.children(@root)
  end

  def test_rename_failure_preserves_the_destination_and_cleans_up
    Dir.mkdir(@destination)
    assert_raises(SystemCallError) do
      ProjectTools::Shared::AtomicFile.write(@destination) { |output| output.write('complete report') }
    end
    assert File.directory?(@destination)
    assert_equal ['report.xml'], Dir.children(@root)
  end
end
