use Test;
use Test::When <author>;
use Docker::API;

my $docker = Docker::API.new;

my $events = $docker.events();

$events.stdout.tap({ .print });

await $events.start;

