use LibCurl::Easy;
use URI::Template;
use JSON::Fast;

sub filters(%filters is copy = %(), *%vars) is export
{
    for %vars.kv -> $k, $v
    {
        for $v.list
        {
            when Bool { %filters{$k}{.so ?? 'true' !! 'false'} = True }
            default { %filters{$k}{$_} = True }
        }
    }
    %filters ?? to-json(%filters, :!pretty) !! Nil
}

class Docker::API
{
    has $.verbose;
    has $.socket;
    has $.prefix;
    has $.curl;        # Use a separate curl handle set up for GET/POST/DELETE
    has $.curl-post;
    has $.curl-delete;

    submethod BUILD(:$!socket = '/var/run/docker.sock', :$!verbose,
        :$!prefix = 'http://localhost')
    {
        $!curl = LibCurl::Easy.new(unix-socket-path => $!socket, :$!verbose);

        die "Bad server"
            unless $!curl.URL("$!prefix/_ping").perform.content eq 'OK';

        $!curl-post = LibCurl::Easy.new(unix-socket-path => $!socket,
                                        Content-Type => 'application/json',
                                        :$!verbose, customrequest => 'POST');

        $!curl-delete = LibCurl::Easy.new(unix-socket-path => $!socket,
                                        :$!verbose, customrequest => 'DELETE');
    }

    method get(Str:D $url)
    {
        my $res = from-json($!curl.URL("$!prefix/$url").perform.content);

        $!curl.success ?? $res !! fail $res<message>;
    }

    method get-str(Str:D $url)
    {
        my $res = $!curl.URL("$!prefix/$url").perform.content;

        $!curl.success ?? $res !! fail from-json($res)<message>;
    }

    method post(Str:D $url, $body = '')
    {
        my $res = $!curl-post.URL("$!prefix/$url")
                            .send(to-json($body), :!pretty).perform.content;

        $res = from-json($res) if $res;

        $!curl-post.success ?? ($res || True) !! fail $res<message>
    }

    method delete(Str:D $url)
    {
        $!curl-delete.URL("$!prefix/$url").perform.success
            ?? True
            !! fail from-json($!curl-delete.content)<message>
    }

    method version() { $.get('version') }

    method info() { $.get('info') }

    method df() { $.get('system/df') }

    method containers(Bool :$all, Int :$limit, Bool :$size,
                      :%filters, |args)
    {
        state $uri = URI::Template.new(
            template => 'containers/json{?all,limit,size,filters}');
        $.get($uri.process(:$all, :$limit, :$size,
                           filters => filters(%filters, |args)))
    }

    method container-inspect(Str:D :$id, Bool :$size)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/json{?size}');
        $.get($uri.process(:$id, :$size))
    }

    method container-top(Str:D :$id!, Str :$ps_args)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/top{?ps_args}');
        $.get($uri.process(:$id, :$ps_args))
    }

    method container-changes(Str:D :$id!)
    {
        $.get("containers/$id/changes")
    }

    method container-stats(Str:D :$id!)
    {
        my Bool $stream = False; # no stream yet
        state $uri = URI::Template.new(
            template => 'containers/{id}/stats{?stream}');

        $.get($uri.process(:$id, :$stream))
    }

    method container-logs(Str:D :$id!,
                          Bool :$stdout,
                          Bool :$stderr,
                          Int :$since,
                          Int :$until,
                          Bool :$timestamps,
                          Str :$tail)
    {
        my Bool $follow = False;  # no streaming yet!
        state $uri = URI::Template.new(template => 'containers/{id}/logs'
            ~'{?follow,stdout,stderr,since,until,timestamps,tail}');

        $.get-str($uri.process(:$id, :$follow, :$stdout, :$stderr,
                               :$since, :$until, :$timestamps, :$tail))
    }

    method container-start(Str:D :$id!, Str :$detachKeys)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/start{?detachKeys}');

        $.post($uri.process(:$id, :$detachKeys))
    }

    method container-stop(Str:D :$id!, Int :$t)
    {
        state $uri = URI::Template.new(template => 'containers/{id}/stop{?t}');

        $.post($uri.process(:$id, :$t))
    }

    method container-restart(Str:D :$id!, Int :$t)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/restart{?t}');

        $.post($uri.process(:$id, :$t))
    }

    method container-update(Str:D :$id!, *%fields)
    {
        $.post("/containers/$id/update", %fields)
    }

    method container-kill(Str:D :$id!, Cool :$signal)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/kill{?signal}');

        $.post($uri.process(:$id, :$signal))
    }

    method container-rename(Str:D :$id!, Str:D :$name!)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/rename{?name}');

        $.post($uri.process(:$id, :$name))
    }

    method container-pause(Str:D :$id!)
    {
        $.post("containers/$id/pause")
    }

    method container-unpause(Str:D :$id!)
    {
        $.post("containers/$id/unpause")
    }

    method container-wait(Str:D :$id!, Str :$condition)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}/wait{?condition}');

        $.post($uri.process(:$id, :$condition))
    }

    method container-remove(Str:D :$id!, Bool :$v, Bool :$force, Bool :$link)
    {
        state $uri = URI::Template.new(
            template => 'containers/{id}{?v,force,link}');

        $.delete($uri.process(:$id, :$v, :$force, :$link))
    }

    method containers-prune(:%filters, |args)
    {
        state $uri = URI::Template.new(
            template => 'containers/prune{?filters}');

        $.post($uri.process(filters => filters(%filters, |args)))
    }

    method container-create(Str :$name, *%fields)
    {
        state $uri = URI::Template.new(template => 'containers/create{?name}');

        $.post($uri.process(:$name), %fields)
    }

    method images(Bool :$all, Bool :$digests, :%filters, |args)
    {
        state $uri = URI::Template.new(
            template => 'images/json{?all,filters,digests}');

        $.get($uri.process(:$all, :$digests,
                           filters => filters(%filters, |args)))
    }

    method images-search(Str:D :$term, Int :$limit, :%filters, |args)
    {
        state $uri = URI::Template.new(template =>
                                       'images/search{?term,limit,filters}');

        $.get($uri.process(:$term, :$limit, filters => filters(%filters, |args)))
    }

    method image-inspect(Str:D :$name!)
    {
        $.get("images/$name/json")
    }

    method image-history(Str:D :$name!)
    {
        $.get("images/$name/history")
    }

    method image-tag(Str:D :$name!, Str :$repo, Str :$tag)
    {
        state $uri = URI::Template.new(
            template =>'images/{name}/tag{?repo,tag}');

        $.post($uri.process(:$name, :$repo, :$tag))
    }

    method image-remove(Str:D :$name!, Bool :$force, Bool :$noprune)
    {
        state $uri = URI::Template.new(
            template =>'images/{name}{?force,noprune}');

        $.delete($uri.process(:$name, :$force, :$noprune))
    }

    method images-prune(:%filters, |args)
    {
        state $uri = URI::Template.new(template =>'images/prune{?filters}');
        $.post($uri.process(filters => filters(%filters, |args)))
    }

    method volumes(:%filters, |args)
    {
        state $uri = URI::Template.new(template => 'volumes{?filters}');
        $.get($uri.process(filters => filters(%filters, |args)))
    }

    method volume-create(Str :$Name, Str :$Driver, :%DriverOpts, :%Labels)
    {
        my %vol;
        %vol<Name> = $Name if $Name;
        %vol<Driver> = $Driver if $Driver;
        %vol<DriverOpts> = %DriverOpts if %DriverOpts;
        %vol<Labels> = %Labels if %Labels;
        $.post('volumes/create', %vol);
    }

    method volume-inspect(Str:D :$name)
    {
        $.get("volumes/$name")
    }

    method volume-remove(Str:D :$name!, Bool :$force)
    {
        state $uri = URI::Template.new(template => 'volumes/{name}{?force}');
        $.delete($uri.process(:$name, :$force))
    }

    method volumes-prune(:%filters, |args)
    {
        state $uri = URI::Template.new(template => 'volumes/prune{?filters}');
        $.post($uri.process(filters => filters(%filters, |args)))
    }
}
