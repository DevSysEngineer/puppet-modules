# frozen_string_literal: true

require_relative '../../../shared/test_support/bootstrap'
require_relative 'log_support'
require 'timeout'

# Hold the activity child before trap installation to expose immediate-stop races deterministically.
class CiActivityStartupTest < Minitest::Test
  include CiLogSupport

  def test_shutdown_waits_until_the_activity_child_can_handle_termination
    output, errors, status = delayed_activity
    assert_equal 19, status.exitstatus
    assert_includes output, '[ERROR] Synthetic'
    assert_equal 1, output.scan('[ERROR]').size
    refute_includes errors, '[PROGRESS]'
  end

  def delayed_activity
    starting = File.join(@project, 'starting')
    arguments = ['bash', '-e', '-c', delayed_script, 'activity-startup', @helper, starting]
    Open3.popen3(*arguments, pgroup: true) do |input, output, errors, child|
      input.close
      begin
        Timeout.timeout(10) { [output.read, errors.read, child.value] }
      ensure
        stop_group(child.pid)
      end
    end
  end

  def stop_group(pid)
    Process.kill('KILL', -pid)
  rescue Errno::ESRCH
    nil
  end

  def delayed_script
    <<~BASH
      source "$1"
      starting="$2"
      definition=$(declare -f ci_activity)
      eval "${definition/ci_activity/original_ci_activity}"
      ci_activity() {
          trap '' TERM
          : > "$starting"
          "$CI_SLEEP" 1
          original_ci_activity
      }
      ci_begin Synthetic
      while [ ! -f "$starting" ]; do "$CI_SLEEP" 0.01; done
      ci_end 19 ERROR incomplete
    BASH
  end
end
