inline_template('<% File.write(scope["facts"]["record"], Puppet[:codedir]) %>')
fail('synthetic compile failure')
