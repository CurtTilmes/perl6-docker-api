use Test;
use Test::When <author>;
use Docker::API;

plan 4;

my $docker = Docker::API.new;

ok my $dist = $docker.distribution(name => 'alpine:3.9'), 'distribution';

ok $dist<Descriptor><size>, 'Descriptor size';

ok $dist<Descriptor><digest>, 'Descriptor digest';

ok $dist<Platforms> ~~ Array, 'Platforms Array';

done-testing;
