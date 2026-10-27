if lookup('foreign', String, 'first', 'clean') != 'clean' { fail('foreign data leaked') }
inline_template('<% File.write(scope["facts"]["record"], Puppet[:codedir]) %>')
