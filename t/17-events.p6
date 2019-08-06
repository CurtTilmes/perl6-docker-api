use Test;
use Test::When <author>;
use Docker::API;
use JSON::Fast;

plan 8;

my $docker = Docker::API.new;

isa-ok my $events = $docker.events(), Supply, 'open event stream Supply';

start react
{
    whenever $events -> % (:$Action, :$id, :$time, *%)
    {
        ok $Action, $Action;
    }
}

$docker.image-create(fromImage => 'busybox', tag => 'latest');

my $created = $docker.container-create(Image => 'busybox',
                                       Cmd => ('/bin/echo', 'Hello World!'));
my $id = $created<Id>;
$docker.container-start(:$id);
$docker.container-wait(:$id);
$docker.container-remove(:$id, :force);

done-testing;
