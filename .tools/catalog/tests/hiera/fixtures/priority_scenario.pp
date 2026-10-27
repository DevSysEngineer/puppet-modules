include sample
if lookup('sample::priority', String) != 'fixture-high' { fail('wrong priority') }
if lookup('sample::items', Array[String]) != ['high', 'shared', 'low'] { fail('wrong merge') }
if lookup('sample::module_value', String) != 'module-data' { fail('lost module data') }
if lookup('sample::fallback', String) != 'module-default' { fail('lost module default') }
if lookup('absent', String, 'first', 'lookup-default') != 'lookup-default' { fail('lost default') }
