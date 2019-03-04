use Test;
use Test::When <author>;
use Docker::API;

plan 4;

isa-ok my $docker = Docker::API.new(), Docker::API;

ok $docker.image-create(fromImage => 'hello-world', tag => 'latest'),
    'pull image';

ok my $list = $docker.images(reference => 'hello-world:latest'),
    'list images';

is $list[0]<RepoTags>[0], 'hello-world:latest', 'image has been pulled';

done-testing;
