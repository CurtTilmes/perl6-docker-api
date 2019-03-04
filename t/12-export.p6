use Test;
use Test::When <author>;
use Docker::API;

my $docker = Docker::API.new;

#$docker.images-get(names => [<docker-perl-testing:latest>],
#                   download => 'testing.tar');

#say $docker.images-load(:quiet, upload => 'testing.tar');

