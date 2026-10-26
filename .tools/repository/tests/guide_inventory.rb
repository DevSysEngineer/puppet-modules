# frozen_string_literal: true

# Inventory tracked and new documentation through Git without scanning dependencies.
module RepositoryGuideInventory
  def repository_markdown(root)
    output, errors, status = Open3.capture3('git', 'ls-files', '-z', '--cached', '--others', '--exclude-standard',
                                            '--', '*.md', chdir: root)
    assert status.success?, errors
    output.split("\0").map { |path| File.join(root, path) }.select { |path| File.file?(path) }
  end
end
