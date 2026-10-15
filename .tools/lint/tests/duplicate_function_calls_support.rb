# frozen_string_literal: true

# Synthetic resource inputs shared by duplicate-call tool tests.
module DuplicateFunctionCallsSupport
  NEXTCLOUD = <<~PUPPET
    define example(Integer $files_max_chunk_size, Boolean $enabled) {
      if $enabled {
    %<assignment>s    # Compare the string stored by config:app:set so an unchanged chunk size does not trigger another write.
        docker::nextcloud_occ { "${name}_files_max_chunk_size":
          command      => ['config:app:set', 'files', 'max_chunk_size', '--value', %<call>s],
          compose_name => $name,
          unless       => ['config:app:get', 'files', 'max_chunk_size'],
          unless_json  => stdlib::to_json(%<call>s),
        }
      }
    }
  PUPPET

  def nextcloud(shared: false)
    call = shared ? '$files_max_chunk_size_string' : 'String($files_max_chunk_size)'
    assignment = if shared
                   "    # Reuse the repeated calculation in this block.\n    " \
                     "$files_max_chunk_size_string = String($files_max_chunk_size)\n\n"
                 else
                   ''
                 end
    format(NEXTCLOUD, assignment: assignment, call: call)
  end

  def resource(*calls)
    "notify { 'example':\n  message => [#{calls.join(', ')}],\n}\n"
  end
end
