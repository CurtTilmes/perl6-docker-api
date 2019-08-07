use Test;
use Test::When <author>;
use Docker::API;
use LibYAML:auth<github:CurtTilmes>;

my $docker = Docker::API.new;

plan 10;

ok $docker.image-create(fromImage => 'busybox', tag => 'latest'),
    'image pull';

ok $docker.container-create(name => 'perltesting',
                            Image => 'busybox',
                            :AttachStdin, :OpenStdin, :AttachStdout),
    'create container';

ok $docker.container-start(id => 'perltesting'),
    'start container';

isa-ok my $stream = $docker.container-attach(id => 'perltesting'),
    Docker::Stream, 'attach to container';

my $stdout = '';

ok $stream.stdout.tap({ $stdout ~= $_ }), 'tap stdout';

isa-ok my $p = $stream.start, Promise, 'start process';

lives-ok { $stream.print("echo hello world\nexit\n") },
    'send command';

lives-ok { await($p) }, 'wait for container finish';

is $stdout, "hello world\n", 'correct output';

ok $docker.container-remove(id => 'perltesting'),
    'remove container';

done-testing;

