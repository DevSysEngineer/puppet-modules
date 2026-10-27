# frozen_string_literal: true

require_relative 'helper'

# Prepared edits retain local keys while every released representation stays masked.
class SecretsSshPublicKeySessionTest < SecretsSshPublicKeyTestCase
  def test_puppet_gate_and_writer_allow_public_keys
    source = "$public_keys = { 'example' => '#{@record}' }\n$ordinary = 'before'\n"
    path = write('sample.pp', source)
    scan('--puppet', path)
    assert_puppet_clean
    round_trip(path, source)
    call_session('diff', '--session', @session)
    assert_reviewed
    assert_hidden(@result.to_json)
  end

  def test_puppet_gate_still_rejects_credentials_alongside_public_keys
    source = "$public_keys = '#{@record}'\n$#{%w[pass word].join} = '#{@value}'\n"
    scan('--puppet', write('rejected.pp', source))
    assert_complete_scan
    assert(@report['files'].first['findings'].any? { |finding| finding['rule'] == 'puppet_hardcoded_value' })
  end

  def test_decoded_multiline_literals_hide_options_and_comments
    source = { ordinary: "command=\"#{@option}\"\n#{@algorithm}\t#{@encoded}\n#{@comment}" }.to_json
    write('sample.json', source)
    prepare(['sample.json'])
    assert_hidden(analysis('sample.json'))
    assert_source(File.join(@input, 'sample.json'), source)
  end

  def test_diagnostics_and_reports_hide_full_records_and_separate_encoded_keys
    path = write('example.pub', "#{@record}\n")
    report = File.join(@directory, 'scan.xml')
    scan('--junit', report, path)
    assert_complete_scan
    assert_hidden(@out + @err + File.read(report))
    command = [Gem.ruby, '-e', "s = File.read('example.pub'); print s; warn s; print s.split[-2]"]
    prepare(['example.pub'], commands: { 'inspect' => command })
    call_session('run', '--session', @session, '--command', 'inspect')
    assert_equal 'executed', @result['status']
    assert_hidden(@result.to_json)
  end

  def test_unbounded_text_and_interpolation_hide_the_complete_surrounding_record
    sources = {
      'wrapped.txt' => "command=\"#{@option}\ncontinued\" #{@algorithm} #{@encoded}\n#{@comment}\n",
      'quoted_fragment.pp' => "$ordinary = \"${name} '#{@algorithm} #{@encoded}' #{@comment}\"\n",
      'interpolated.pp' => "$ordinary = \"#{@algorithm} #{@encoded} ${name} #{@comment}\"\n"
    }
    sources.each { |name, source| write(name, source) }
    prepare(sources.keys)
    sources.each_key { |name| assert_hidden(analysis(name)) }
    assert(@result['files'].all? { |file| file['context_omitted'] })
  end

  def test_incomplete_selection_does_not_release_any_analysis
    write('example.pub', "#{@record}\n")
    write('broken.pp', 'class {')
    File.write(@policy, JSON.generate('files' => %w[example.pub broken.pp]))
    call_session('prepare', '--root', @input, '--tree', @copies, '--policy', @policy)
    assert_equal 2, @code
    refute @result['complete']
    refute File.exist?(@copies)
    assert_hidden(@result.to_json)
  end

  def test_puppet_writer_keeps_repeated_keys
    source = "$first = '#{@record}'\n$second = '#{@record}'\n$ordinary = 'before'\n"
    round_trip(write('sample.pp', source), source)
  end

  def test_prepare_protects_plain_files_and_preserves_benign_yaml_fields
    write('example.pub', "#{@record}\n")
    write('authorized_keys', "#{@record}\n")
    write('sample.yaml', "ordinary: before\nrecord: #{@record.to_json}\n")
    prepare(%w[example.pub authorized_keys sample.yaml])
    %w[example.pub authorized_keys sample.yaml].each { |name| assert_hidden(analysis(name)) }
    assert_includes analysis('sample.yaml'), 'ordinary: before'
  end

  def test_writer_rejects_a_new_unregistered_public_key
    path = write('sample.pp', "$ordinary = 'before'\n")
    prepare(['sample.pp'])
    edit('sample.pp', "$ordinary = '#{@record}'\n")
    apply('write' => ['sample.pp'])
    assert_equal ['unregistered_value'], @result['errors']
    assert_source(path, "$ordinary = 'before'\n")
    assert_hidden(@result.to_json)
  end

  def test_escaped_puppet_values_cannot_bypass_record_protection
    write('sample.pp', "$ordinary = \"#{@algorithm}\\t#{@encoded} #{@comment}\"\n")
    command = [Gem.ruby, '-e', 'print File.read("sample.pp")[%r{[A-Za-z0-9+/]{40,}={0,3}}]']
    prepare(['sample.pp'], commands: { 'inspect' => command })
    assert_hidden(analysis('sample.pp'))
    assert @result['files'].first['context_omitted']
    call_session('run', '--session', @session, '--command', 'inspect')
    assert_equal 'executed', @result['status']
    assert_hidden(@result.to_json)
  end
end
