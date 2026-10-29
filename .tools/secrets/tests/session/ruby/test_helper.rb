# frozen_string_literal: true

require_relative '../../session_helper'

# Protected Ruby values retain their container and survive edits without evaluating source.
class SecretsRubyContainerTestCase < SecretsSessionTestCase
  def source(value, name: 'password')
    "#{name} = #{value.inspect}\nordinary = :before\n"
  end

  def prepare_ruby(value, name: 'password', file: 'config.rb')
    @original = source(value, name: name)
    @path = write(file, @original)
    prepare([file])
    copy = analysis(file)
    refute_includes copy, @value
    assert Ripper.sexp(copy), 'Prepared Ruby must parse'
    copy
  end

  def register_value(file, value)
    input = File.join(@directory, 'registered.txt')
    File.write(input, value)
    call_session('register', '--session', @session, '--input', input, '--to', file)
    @result.fetch('marker')
  end
end
