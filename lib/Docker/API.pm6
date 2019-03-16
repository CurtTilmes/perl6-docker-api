use Docker::Stream;
use LibCurl::REST;
use URI::Template;
use JSON::Fast;
use Base64;

#
# Docker allows filters to various commands to be specified in different
# ways.  I always have a %filters argument so you can just pass in what
# you want, and it tries to unpack other variables, Bool or Lists to
# do the right thing in building it into a filter.
#
sub filters(%filters is copy = %(), *%vars)
{
    for %vars.kv -> $k, $v
    {
        for $v.list
        {
            when Bool { %filters{$k}{.so ?? 'true' !! 'false'} = True }
            default { %filters{$k}{$_} = True }
        }
    }
    filters => (%filters ?? to-json(%filters, :!pretty) !! Nil)
}

#
# cache URI::Templates, and process them with whatever variables get
# passed in.  See URI::Template for more details
#
sub expand($template, |args)
{
    state %template-cache;

    my $uri = %template-cache{$template} //
             (%template-cache{$template} = URI::Template.new(:$template));

    $uri.process(|args)
}


class Docker::API
{
    has LibCurl::REST $.rest handles<query get post delete head put>;
    has $!host;
    has $!port;
    has $!unix-socket-path;
    has $.auth-token is rw;
    has $!other-opts;

    submethod BUILD(Str :$!unix-socket-path, Str :$!host, Int :$!port,
                    Str :$!auth-token, |other-opts)
    {
        $!unix-socket-path //= '/var/run/docker.sock' unless $!host;
        $!host //= 'localhost';
        $!port //= 80;
        $!other-opts = other-opts;
        $!auth-token //= %*ENV<DOCKER_API_AUTH_TOKEN>;
        $!rest = self!new-rest-handle;
    }

    method !new-rest-handle(--> LibCurl::REST)
    {
        LibCurl::REST.new(:$!host, :$!port, :$!unix-socket-path,
                          |$!other-opts)
    }

    method token(|creds)
    {
        encode-base64(:str, to-json(creds.hash, :!pretty))
    }

    method !registry-auth-header()
    {
        $!auth-token ?? headers => { X-Registry-Auth => $!auth-token } !! ()
    }

    method ping()
    {
        $.get('_ping') eq 'OK'
    }

    method auth(|creds)
    {
        $.post('auth', creds.hash)
    }

    method version()
    {
        $.get('version')
    }

    method info()
    {
        $.get('info')
    }

    method df()
    {
        $.get('system/df')
    }

    method containers(Bool :$all, Int :$limit, Bool :$size,
                      :%filters, |filters)
    {
        $.get(expand('containers/json{?all,limit,size,filters}',
                     :$all, :$limit, :$size,
                     |filters(%filters, |filters)))
    }

    method container-inspect(Str:D :$id!, Bool :$size)
    {
        $.get(expand('containers/{id}/json{?size}', :$id, :$size))
    }

    method container-top(Str:D :$id!, Str :$ps_args)
    {
        $.get(expand('containers/{id}/top{?ps_args}'), $id, :$ps_args)
    }

    method container-diff(Str:D :$id!)
    {
        $.get(expand('containers/{id}/changes', :$id))
    }

    method container-export(Str:D :$id!, |opts)
    {
        $.get(expand('containers/{id}/export', :$id), :bin, |opts)
    }

    method container-stats(Str:D :$id!, Bool :$stream = False)
    {
        my $url = expand('containers/{id}/stats{?stream}', :$id, :$stream);
        $stream
            ?? Docker::Stream.new(rest => self!new-rest-handle, :$url,
                                  :json, :!mux)
            !! $.get($url)
    }

    method container-logs(Str:D :$id!,
                          Bool :$tty,
                          Bool :$follow = False,
                          Bool :$merge = True,
                          Bool :$stdout = True,
                          Bool :$stderr = True,
                          Int :$since,
                          Int :$until,
                          Bool :$timestamps,
                          Str :$tail,
                          Str :$enc = 'utf8',
                          Bool :$translate-nl = True,
                          Int :$timeout = 60*60*1000)
    {
        my $url = expand('containers/{id}/logs'
                         ~'{?follow,stdout,stderr,since,until,timestamps,tail}',
                         :$id, :$follow, :$stdout, :$stderr, :$since,
                         :$until, :$timestamps, :$tail);

        Docker::Stream.new(rest => self!new-rest-handle, :$url, :$merge,
                           mux => !$tty, :$enc,:$translate-nl, :$timeout);
    }

    method container-attach(Str:D :$id!,
                            Bool :$tty,
                            Str :$detachKeys,
                            Bool :$logs,
                            Bool :$stream = True,
                            Bool :$stdin = True,
                            Bool :$stdout = True,
                            Bool :$stderr = True,
                            Bool :$merge = True,
                            Str  :$enc = 'utf8',
                            Bool :$translate-nl = True,
                            Int :$timeout = 60*60*1000)
    {
        my $url = expand('containers/{id}/attach'
                         ~'{?detachKeys,logs,stream,stdin,stdout,stderr}',
                         :$id, :$detachKeys, :$logs, :$stream,
                         :$stdin, :$stdout, :$stderr);

        Docker::Stream.new(rest => self!new-rest-handle, method => 'POST',
                           :$url, :$merge, mux => !$tty, :$enc, :$translate-nl,
                           :$timeout)
    }

    method container-start(Str:D :$id!, Str :$detachKeys)
    {
        $.post(expand('containers/{id}/start{?detachKeys}',
                      :$id, :$detachKeys))
    }

    method container-stop(Str:D :$id!, Int :$t)
    {
        $.post(expand('containers/{id}/stop{?t}', :$id, :$t))
    }

    method container-restart(Str:D :$id!, Int :$t)
    {
        $.post(expand('containers/{id}/restart{?t}', :$id, :$t))
    }

    method container-update(Str:D :$id!, *%fields)
    {
        $.post("/containers/$id/update", %fields)
    }

    method container-kill(Str:D :$id!, Cool :$signal)
    {
        $.post(expand('containers/{id}/kill{?signal}',
                      :$id, :$signal))
    }

    method container-rename(Str:D :$id!, Str:D :$name!)
    {
        $.post(expand('containers/{id}/rename{?name}', :$id, :$name))
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
        $.post(expand('containers/{id}/wait{?condition}', :$id, :$condition))
    }

    method container-remove(Str:D :$id!, Bool :$v, Bool :$force, Bool :$link)
    {
        $.delete(expand('containers/{id}{?v,force,link}',
                        :$id, :$v, :$force, :$link))
    }

    method container-archive-info(Str:D :$id!, Str :$path!)
    {
        my $headers = $.head(expand('containers/{id}/archive{?path}',
                                    :$id, :$path));
        from-json(decode-base64($headers<X-Docker-Container-Path-Stat>,
                                :bin).decode)
    }

    method container-archive(Str:D :$id!, Str :$path!, |opts)
    {
        $.get(expand('containers/{id}/archive{?path}', :$id, :$path),
              :bin, |opts)
    }

    method container-copy(Str:D :$id!, Str:D :$path!,
                          Bool :$noOverwriteDirNonDir, |opts)
    {
        $.put(expand('containers/{id}/archive{?path,noOverwriteDirNonDir}',
                     :$id, :$path, :$noOverwriteDirNonDir), |opts)
    }

    method containers-prune(:%filters, |filters)
    {
        $.post(expand('containers/prune{?filters}',
                      |filters(%filters, |filters)))
    }

    method container-create(Str :$name, *%fields)
    {
        $.post(expand('containers/create{?name}', :$name), %fields)
    }

    method images(Bool :$all, Bool :$digests, :%filters, |filters)
    {
        $.get(expand('images/json{?all,filters,digests}', :$all, :$digests,
                     |filters(%filters, |filters)))
    }

    method image-create(Str :$fromImage, Str :$fromSrc, Str :$repo,
                        Str :$tag, Str :$platform)
    {
        $.post(expand('images/create' ~
                      '{?fromImage,fromSrc,repo,tag,platform}',
                      :$fromImage, :$fromSrc, :$repo, :$tag, :$platform),
               |self!registry-auth-header)
    }

    method image-build(Str :$dockerfile, :@t, Str :$extrahosts,
                       Str :$remote, Bool :$q, Bool :$nocache,
                       :@cachefrom, Str :$pull, Bool :$rm, Bool :$forcerm,
                       Int :$memory, Int :$memswap, Int :$cpushares,
                       Str :$cpusetcpus, Int :$cpuperiod, Int :$cpuquota,
                       :%buildargs, Int :$shmsize, Bool :$squash, :%labels,
                       Str :$networkmode, Str :$platform, Str :$target)
    {
        my $cachefrom = to-json(@cachefrom) if @cachefrom;
        my $buildargs = to-json(%buildargs) if %buildargs;
        my $labels    = to-json(%labels)    if %labels;

        $.post(expand('build{?dockerfile,t*,extrahosts,remote,q,nocache,cachefrom,pull,rm,forcerm,memory,memswap,cpushares,cpusetcpus,cpuperiod,cpuquota,buildargs,shmsize,squash,labels,networkmode,platform,target}', :$dockerfile, :@t, :$extrahosts, :$remote, :$q, :$nocache, :$cachefrom, :$pull, :$rm, :$forcerm, :$memory, :$memswap, :$cpushares, :$cpusetcpus, :$cpuperiod, :$cpuquota, :$buildargs, :$shmsize, :$squash, :$labels, :$networkmode, :$platform, :$target))
    }

    method build-prune(Int :$keep-storage, Bool :$all, :%filters, |filters)
    {
        $.post(expand('build/prune{?keep-storage,all,filters}',
                      :$keep-storage, :$all,
                      |filters(%filters, |filters)))
    }

    method images-search(Str:D :$term, Int :$limit, :%filters, |filters)
    {
        $.get(expand('images/search{?term,limit,filters}',
                     :$term, :$limit, |filters(%filters, |filters)))
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
        $.post(expand('images/{name}/tag{?repo,tag}', :$name, :$repo, :$tag))
    }

    method image-push(Str:D :$name!, Str :$tag)
    {
        $.post(expand('images/{name}/push{?tag}', :$name, :$tag),
               |self!registry-auth-header)
    }

    method image-remove(Str:D :$name!, Bool :$force, Bool :$noprune)
    {
        $.delete(expand('images/{name}{?force,noprune}',
                        :$name, :$force, :$noprune))
    }

    method images-prune(:%filters, |filters)
    {
        $.post(expand('images/prune{?filters}',
                      |filters(%filters, |filters)))
    }

    method image-get(Str:D :$name!, |opts)
    {
        $.get(expand('images/{name}/get', :$name), :bin, |opts)
    }

    method images-get(:@names!, |opts)
    {
        $.get(expand('images/get{?names}', :@names), :bin, |opts)
    }

    method images-load(Bool :$quiet, |opts)
    {
        $.post(expand('images/load{?quiet}', :$quiet), |opts)
    }

    method volumes(:%filters, |filters)
    {
        $.get(expand('volumes{?filters}',
                     |filters(%filters, |filters)))
    }

    method volume-create(|desc)
    {
        $.post('volumes/create', desc.hash);
    }

    method volume-inspect(Str:D :$name)
    {
        $.get("volumes/$name")
    }

    method volume-remove(Str:D :$name!, Bool :$force)
    {
        $.delete(expand('volumes/{name}{?force}', :$name, :$force))
    }

    method volumes-prune(:%filters, |filters)
    {
        $.post(expand('volumes/prune{?filters}',
                      |filters(%filters, |filters)))
    }

    method commit(Str :$container, Str :$repo, Str :$tag, Str :$comment,
                  Str :$author, Bool :$pause, Str :$changes)
    {
        # Still need to upload body variables..
        ...
        $.post(expand('/commit{?container,repo,tag,comment,author,pause,changes}',
                      :$container, :$repo, :$tag, :$comment, :$author, :$pause,
                      :$changes))
    }

    method networks(:%filters, |filters)
    {
        $.get(expand('networks{?filters}',
                     |filters(%filters, |filters)))
    }

    method network-inspect(Str:D :$id!, Bool :$verbose, Str :$scope)
    {
        $.get(expand('networks/{id}{?verbose,scope}',
                     :$id, :$verbose, :$scope))
    }

    method network-remove(Str:D :$id!)
    {
        $.delete(expand('networks/{id}', :$id))
    }

    method network-create(|desc)
    {
        $.post('networks/create', desc.hash)
    }

    method network-connect(Str:D :$id!, |desc)
    {
        $.post(expand('networks/{id}/connect', :$id), desc.hash)
    }

    method network-disconnect(Str:D :$id!, |desc)
    {
        $.post(expand('networks/{id}/disconnect', :$id), desc.hash)
    }

    method networks-prune(:%filters, |filters)
    {
        $.post(expand('networks/prune{?filters}',
                      |filters(%filters, |filters)))
    }

    method exec-create(Str:D :$id!, |desc)
    {
        $.post(expand('containers/{id}/exec', :$id), desc.hash)
    }

    method exec-start(Str:D :$id!, Bool :$Detach, Bool :$Tty,
                      Bool :$merge = True,
                      Str  :$enc = 'utf8',
                      Bool :$translate-nl = True,
                      Int :$timeout = 60*60*1000)
    {

        my $url = expand('exec/{id}/start', :$id);

        return $.post($url, { :$Detach, :$Tty }) if $Detach;

        my $rest = $!rest;  # Must create/start exec on same connection?
        $!rest = self!new-rest-handle;

        Docker::Stream.new(:$rest, method => 'POST', :$url, mux => !$Tty,
                           Content-Type => 'application/json',
                           body => to-json({ :$Detach, :$Tty }),
                           :$merge, :$enc, :$translate-nl, :$timeout)
    }

    method exec-resize(Str:D :$id!, Int :$h, Int :$w)
    {
        $.post(expand('exec/{id}/resize{?h,w}', :$id, :$h, :$w))
    }

    method exec-inspect(Str:D :$id!)
    {
        $.get(expand('exec/{id}/json', :$id))
    }

    method exec(Str:D :$id!, Bool :$Detach, Bool :$Tty, |desc)
    {
        $.exec-start(:$Detach, :$Tty,
                     id => $.exec-create(:$id, :$Tty, |desc)<Id>)
    }

    method distribution(Str:D :$name!)
    {
        $.get(expand('distribution/{name}/json', :$name))
    }

    method plugins(:%filters, |filters)
    {
        $.get(expand('plugins{?filters}', |filters(%filters, |filters)))
    }

    method events(Str :$since, Str :$until, :$timeout = 60*60*1000,
                  :%filters, |filters)
    {
        my $url = expand('events{?since,until,filters}', :$since, :$until,
                         |filters(%filters, |filters));

        Docker::Stream.new(rest => self!new-rest-handle,
                           :$url, :$timeout);
    }
}
