class Docker::Container
{
    has $.api;
    has $.id;

    method new(:$api = Docker::API.new, :$Image, |opts)
    {
        $api.image-create(fromImage => $Image);

        my $container = $api.container-create(:$Image, |opts);

        self.bless(:$api, id => $container<Id>);
    }

    method start() { $!api.container-start(:$!id) }

    method wait() { $!api.container-wait(:$!id) }

    method remove() { $!api.container-remove(:$!id) }
}
