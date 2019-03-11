# Docker - Perl 6 Docker API

A simple wrapper around the [Docker REST
API](https://docs.docker.com/engine/api/latest).  Much of the API is
not fully documented here -- it just follows the API.

## Basic Usage

    use Docker;

    my $d = Docker.new;      # Defaults to /var/run/docker.sock

    $d.version<Version>;     # Other stuff in version too

    $d.info<ProductLicense>; # Other stuff in info too

    $d.images;               # List Images

    $d.containers;           # List Containers

    $d.image-create(fromImage => 'alpine', tag => 'latest'); # image pull

    $d.container-create(name => 'foo',
                        Image => 'alpine',
                        Cmd => ( '/bin/echo', 'hello world!') );

    $d.container-start(id => 'foo');

    print $d.container-logs(id => 'foo');

    $d.container-stop(id => 'foo');

    $d.container-remove(id => 'foo');

## Connection

By default, Docker.new() will just use a unix socket on `/var/run/docker.sock`
If you use a different socket name, you can pass in `:unix-socket-path`:

    my $docker = Docker.new(unix-socket-path => '/my/special/socket')

If you have it running on a TCP port (hopefully you know what you are
doing and do it securely), you can pass in a host/port like this:

    my $docker = Docker.new(host => 'somehost', port => 12345);

If you know what you are doing, you can pass in other options for
`LibCurl` and they just get passed through.

One `LibCurl` option that is useful for debugging is `:verbose` which
will dump out the HTTP headers.

## filters

Many of the command have a `:%filters` option.  You can construct your
own hash of filter argument and just pass that in.  If you pass in
other arguments, they will get stuck into filters.

For example:

    $docker.volumes(filters => { label => { foo => True } } );

and

    $docker.volumes(label => 'foo');

do the same thing.

## Streams

Some commands (`stats`, `logs`, `events`, `exec`) have options for
streaming ongoing output.  They return a `Docker::Stream` object.  It
is kind of, but not really like `Proc::Async`.

It stringifies to just slurp in all the output and return it as a
string, so you can do things like this:

    print $docker.logs(id => 'foo');

If you do that with something that keeps on streaming, it will keep on
slurping forever and appear to hang.

You can access `.stdout` and `.stderr` streams which are by default
merged (and if you have a container with a `tty`, they are also merged
so even if you ask for stderr, all output will be on stdout anyway).
They are returned as supplies that must be tapped to use.

You have to call `.start` to start the process.  It returns a
`Promise` that will be kept when the process completes.

```
my $stream = $docker.logs(id => $foo, :!tty, :follow);
$stream.stdout.tap({ .print });
await self.start;
```

You can also use react/whenever:

```
my $stream = $docker.logs(id => $foo, :follow);
react {
    whenever $stream.stdout.lines { .put }
    whenever $stream.start { done }
}
```

By default everything goes to stdout, by you can also separate
out stderr and do something different:

```
my $stream = $docker.logs(id => $foo, :!merge, :stdout, :stderr, :follow);
react {
    whenever $stream.stdout.lines { .put }
    whenever $stream.stderr(:bin) {  # Binary Blobs instead of Strs
        .decode.put
    }
    whenever $stream.start { done }
}
```

## Methods

### auth(...)

    $docker.auth(username => 'me',
                 password => %*ENV<DOCKERHUB_PW>,
                 email => 'me@example.com',
                 serveraddress => 'https://index.docker.io/v1/');

### version()

### info()

### df()

### containers(Bool :$all, Int :$limit, Bool :$size, :%filters, |args)

`:$all`
`:$limit`
`:$size`
`:%filters`

bunch of other filter args

### container-inspect(Str:D :$id!)

### container-top(Str:D :$id!)

### container-changes(Str:D :$id!)

### container-stats(Str:D :$id)

### container-logs(Str:D :$id!, Bool :$merge = True, Bool :$stdout, Bool :$stderr, Int :$since, Int :$until, Bool :$timestamps, Str :$tail)

Note, this sets `:merge` by default to true.

`:merge` will automatically select *both* `:stdout` and `:stderr` and
merge them into a single stream.  If you don't want that, pass in
`:!merge` and `:stdout` and/or `:stderr`.

If you pass in `:follow` it will leave the connection open and stream
output to you.

### container-start(Str:D :$id!, Str :$detachKeys)

### container-stop(Str:D :$id!, Int :$t)

`:t` = Number of seconds to wait before killing the container

### container-restart(Str:D :$id!, Int :$t)

`:t` = Number of seconds to wait before restarting the container

### container-kill(Str:D :$id!, Cool :$signal)

:signal can be a POSIX signal integer or string (e.g. `SIGINT`)
default `SIGKILL`

### container-rename(Str:D :$id!, Str:D :$name!)

### container-pause(Str:D :$id!)

### container-unpause(Str:D :$id!)

### container-wait(Str:D :$id!, Str :$condition)

`:condition` = `not-running` (default), `next-exit`, `removed`

### container-remove(Str:D :$id!, Bool :$v, Bool :$force, Bool :$link)

### containers-prune(:%filters)

### container-create(Str :$name, *%fields)

     my $container = $docker.container-create(
                          Image => 'alpine',
                          Cmd => ( 'echo', 'hello world' ));

     put $container<Id>;

### container-update(Str:D :$id!, *%fields)

### images(:%filters, Bool :$all, Bool :$digests)

    my $list = $docker.images(filters =>
                                %( reference =>
                                    %( 'alpine*:*' => True )));
    .<RepoTags>.say for @$list;

### image-create(Str :$fromImage, Str :$fromStr, Str :$repo, Str :$tag,
                Str :$platform)

    $docker.image-create(fromImage => 'alpine', tag => 'latest');

### image-build(Str :$dockerfile, :@t, Str :$extrahosts,
                       Str :$remote, Bool :$q, Bool :$nocache,
                       :@cachefrom, Str :$pull, Bool :$rm, Bool :$forcerm,
                       Int :$memory, Int :$memswap, Int :$cpushares,
                       Str :$cpusetcpus, Int :$cpuperiod, Int :$cpuquota,
                       :%buildargs, Int :$shmsize, Bool :$squash, :%labels,
                       Str :$networkmode, Str :$platform, Str :$target)


    $docker.image-build(:q, :rm, t => ['docker-perl-testing:test-version'],
        remote => 'https://github.com/CurtTilmes/docker-test.git')

`:q` = quiet

`:rm` = Remove intermediate containers after a successful build

`:remote` = A URL, can be for a git repository, or a single file that
is a Dockerfile, or a single file that is a tarball with a Dockerfile
in it.  If you rename the dockerfile, pass in `:dockerfile` to tell it
which file is the Dockerfile.

### image-inspect(Str:D :$name!)

### image-history(Str:D :$name!)

### image-tag(Str:D :$name!, Str :$repo, Str :$tag)

### image-push(Str:D :$name!, Str :$tag)

### image-remove(Str:D :$name!, Bool :$force, Bool :$noprune)

### images-search(Str:D :$term, Int :$limit, :%filters,
                 Bool :$is-official, Bool :$is-automated, Int :$stars)

    my $list = $docker.images-search(term => 'alpine',
                                     limit => 10,
                                     :is-official, :!is-automated, :5000stars);

    for @$list
    {
        say .<name>;
        say .<description>;
    }

### images-prune(:%filters, :$dangling :$until :$label)

### image-get(Str:D :$name!, Str :$download)

Returns Blob of a tar file

You can pass in a filename in `:download` and it will dump the tar
file into that file.

### images-get(:@names, Str :$download))

Returns Blob of a tar file

You can pass in a filename in `:download` and it will dump the tar
file into that file.

### images-load(Bool :$quiet, Str :$upload)

Upload a tar file with images.

### volumes(:%filters, :$name, :$label)

    $docker.volumes(filters => { label => { foo => True } } );

    $docker.volumes(label => 'foo');       # has label foo
    $docker.volumes(label => 'foo=bar');   # has label foo = 'bar'
    $docker.volumes(label => <foo bar>);   # has both labels foo and bar

    $docker.volumes(name => 'foo');        # volume with name foo
    $docker.volumes(name => <foo bar>);    # volume with name foo or bar

### volume-create(...)

Everything is optional, it will make a random volume.

    $docker.volume-create(Name => 'foo', Labels => { foo => 'bar' });

### volume-inspect(:$name)

### volume-remove(:$name, :force)

`:name` required

`:force` boolean

### volume-prune(:%filters)

### networks(:%filters, ...)

### network-inspect(Str:D :$id!, Bool :$verbose, Str :$scope)

### network-create(...)

    $docker.network-create(Name => 'foo');

lots of other options

### network-connect(Str:D :$id!, ...)

`:Container` id or name

`:EndpointConfig` lots of options

### network-disconnect(Str:D :$id!, ...)

`:Container`

`:Force`

### networks-prune(:%filters, ...)

### exec-create(Str:D :$id!, ...)

`:id` of container

### exec-start(Str:D :$id!, ...)

`:id` of exec

### exec-resize(Str:D :$id!, Int :$h, Int :$w)

### exec-inspect(Str:D :$id!)

`:id` of exec

### exec(Str:D :$id!, ...)

call `exec-create(:$id, ...)`, then `exec-start()`

### plugins(%filters, ...)

### distribution(Str:D :$name!)

## INSTALL

Uses [LibCurl](https://github.com/CurtTilmes/LibCurl) to communicate
with Docker, so that will need to be installed.  Since it depends on
the [libcurl](https://curl.haxx.se/download.html) library, you must
also install that first.

## LICENSE

Copyright © 2019 United States Government as represented by the
Administrator of the National Aeronautics and Space Administration.
No copyright is claimed in the United States under Title 17,
U.S.Code. All Other Rights Reserved.
