use Test;
use Test::When <author>;
use Docker::API;

plan 6;

isa-ok my $docker = Docker::API.new, Docker::API;

ok $docker.image-build(:q, :rm, t => ['docker-perl-testing:test-version'],
    remote => 'https://github.com/CurtTilmes/docker-test.git'),
    'image build';

ok $docker.build-prune(:all), 'build prune';

ok my $images = $docker.images(reference => 'docker-perl-testing:test-version'),
    'image list';

with $images[0]
{
    is .<RepoTags>[0], 'docker-perl-testing:test-version', 'tag correct';
    is .<Labels><maintainer>, 'Curt Tilmes <Curt.Tilmes@nasa.gov>', 'label';
}

done-testing;
