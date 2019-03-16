use Test;
use Test::When <author>;
use Docker::API;

plan 12;

my $docker = Docker::API.new;

ok $docker.image-create(fromImage => 'hello-world', tag => 'latest'),
    'image pull';

ok my $created = $docker.container-create(name => 'perltesting',
                                          Image => 'hello-world'),
    'create container';

my $id = $created<Id>;

ok $docker.container-start(:$id), 'start container';

ok my $file-info = $docker.container-archive-info(:$id, path => '/hello'),
    'container archive info';

is $file-info<name>, 'hello', 'file info name';

ok my $tarfile = $docker.container-archive(:$id, path => '/hello'),
    'container archive';

ok my $cont2 = $docker.container-create(name => 'perltesting2',
                                        Image => 'hello-world'),
    'create container 2';

my $id2 = $cont2<Id>;

ok $docker.container-start(id => $id2), 'start container 2';

ok $docker.container-copy(id => $id2, path => '/etc', send => $tarfile),
    'copy file to container 2';

my $diff = $docker.container-diff(id => $id2).sort;

is-deeply $diff, ({:Kind(0), :Path("/etc")},
                  {:Kind(1), :Path("/etc/hello")}), 'Added hello to /etc';

ok $docker.container-remove(:$id, :force), 'remove container 1';

ok $docker.container-remove(id => $id2, :force), 'remove container 2';

done-testing;
