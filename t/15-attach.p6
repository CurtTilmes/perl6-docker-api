use Test;
use Test::When <author>;
use Docker::API;
use LibCurl::EasyHandle;

my $docker = Docker::API.new;

plan 1;
ok 1;

#my $stream = $docker.container-logs(id => 'test', :tty, :follow);

#$stream.stdout(:bin).tap({ .decode.print });

#await $stream.start;

#react
#{
#    whenever $stream.stdout.lines { say 'line: ', $_ }
#    whenever $stream.stderr { print "ERROR:", $_ }
#    whenever $stream.start  { say "complete"; done }
#}

#$stream.stdout.tap({ print 'line : ', $_ });

#await $stream.start;

#say "done";

done-testing;

