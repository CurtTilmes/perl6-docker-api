use Docker::API;

class Docker::Container
{
    has $.api;
    has $.id;

    method new(:$api = Docker::API.new, |opts)
    {
        my $container = $api.container-create(|opts);

        self.bless(:$api, id => $container<Id>);
    }

    method start(|opts) { $!api.container-start(:$!id, |opts) }

    method wait(|opts) { $!api.container-wait(:$!id, |opts)<StatusCode> }

    method remove(|opts) { $!api.container-remove(:$!id, |opts) }

    method copy(|opts) { $!api.container-copy(:$!id, |opts) }

    method logs(|opts) { $!api.container-logs(:$!id, |opts) }

    method inspect(|opts) { $!api.container-inspect(:$!id, |opts) }

    method stats(|opts) { $!api.container-stats(:$!id, |opts) }
}
