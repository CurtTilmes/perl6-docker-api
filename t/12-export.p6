use Test;
use Test::When <author>;
use Docker::API;
use Libarchive::Simple;
use JSON::Fast;

plan 11;

my $docker = Docker::API.new;

ok $docker.image-create(fromImage => 'hello-world', tag => 'latest'),
    'pull image';

ok $docker.images(reference => 'hello-world:latest'), 'image present';

isa-ok my $tar = $docker.images-get(names => [<hello-world:latest>]),
    'Buf', 'Download image tar file';

isa-ok my $archive = archive-slurp($tar), 'Libarchive::Archive', 'Untar';

ok from-json($archive<repositories>)<hello-world>, 'hello-world repository';

ok $docker.image-remove(name => <hello-world:latest>), 'remove image';

nok $docker.images(reference => 'hello-world:latest'), 'image gone';

ok $docker.images-load($tar), 'image loaded from tar file';

ok $docker.images(reference => 'hello-world:latest'), 'image loaded';

ok $docker.image-remove(name => <hello-world:latest>), 'remove image';

nok $docker.images(reference => 'hello-world:latest'), 'image gone';

done-testing;

