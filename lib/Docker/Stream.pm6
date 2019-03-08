use NativeCall;

sub strstr(Pointer, Str --> Pointer) is native {}

class Docker::Stream
{
    has $.rest is required;
    has $.url is required;
    has Bool $.merge = True;
    has Bool $.mux;
    has $.method = 'GET';
    has $.enc = 'utf8';
    has $.translate-nl = True;
    has $.timeout = 60*60*1000;  # milliseconds
    has $!encoder;
    has $!stdout-supply;
    has $!stderr-supply;
    has Bool $.started = False;

    submethod TWEAK(--> Nil)
    {
        $!encoder := Encoding::Registry.find($!enc).encoder(:$!translate-nl);
    }

    method !dechunk(Blob:D $buf)
    {
        return True unless $buf.elems;
        my $pos = 0;
        repeat
        {
            my $ptr = nativecast(Pointer, $buf) + $pos;
            my $eol = strstr(Pointer.new($ptr), "\r\n");
            return False unless $eol &&
                my $chunk-size = $buf.subbuf($pos, +$eol - $ptr)
                .decode.parse-base(16);
            my $chunk-start = +$eol - $ptr + $pos + 2;
            my $chunk = $buf.subbuf($chunk-start ..^ $chunk-start + $chunk-size);
            if $!mux
            {
                self!demux($chunk)
            }
            else
            {
                .emit($chunk) with $!stdout-supply
            }
            $pos = $chunk-start + $chunk-size + 2;
        } while $pos < $buf.elems;
        True;
    }

    method !demux(Blob:D $buf)
    {
        my $pos = 0;
        while $pos < $buf.elems
        {
            my $size = $buf[$pos+4] +< 24
                    +| $buf[$pos+5] +< 16
                    +| $buf[$pos+6] +< 8
                    +| $buf[$pos+7];

            die "Data not muxed, try :tty" if $pos+8+$size > $buf.elems;

            my $next = $buf.subbuf($pos+8..^$pos+8+$size);

            if $!merge
            {
                $!stdout-supply.emit($next)
            }
            else
            {
                given $buf[$pos]
                {
                    when 0|1 { .emit($next) with $!stdout-supply }
                    when 2   { .emit($next) with $!stderr-supply }
                }
            }
            $pos += 8 + $size;
        }
    }

    method !wrap-decoder(Supply:D $supply, Str:D :$enc, Bool:D :$translate-nl)
    {
        supply
        {
            my $decoder = Encoding::Registry.find($enc).decoder(:$translate-nl);
            whenever $supply -> $buf
            {
                $decoder.add-bytes($buf);
                my $available = $decoder.consume-available-chars();
                emit $available if $available ne '';
                LAST
                {
                    with $decoder
                    {
                        my $rest = .consume-all-chars();
                        emit $rest if $rest ne '';
                    }
                }
            }
        }
    }

    method stdout(:$bin, :$enc = $!enc, :$translate-nl = $!translate-nl)
    {
        $!stdout-supply = Supplier::Preserving.new;
        $bin ?? $!stdout-supply.Supply
             !! self!wrap-decoder($!stdout-supply.Supply, :$enc, :$translate-nl)
    }

    method stderr(:$bin, :$enc = $!enc, :$translate-nl = $!translate-nl)
    {
        $!stderr-supply = Supplier::Preserving.new;
        $bin ?? $!stderr-supply.Supply
             !! self!wrap-decoder($!stderr-supply.Supply, :$enc, :$translate-nl)
    }

    method start()
    {
        die "Already started" if $!started;
        $!started = True;

        $!rest.curl.setopt(URL => $!rest.prefix, :connect-only).perform;

        $!rest.curl.handle.send("$!method /$!url HTTP/1.1\r\n" ~
                                "Host: localhost\r\n" ~
                                "Accept: */*\r\n\r\n");

        my $buf = $!rest.curl.handle.recv;
        my $ptr = nativecast(Pointer, $buf);
        my $eol = strstr($ptr, "\r\n");
        my $statusline = $buf.subbuf(^($eol - $ptr)).decode;
#        say $statusline;
        die "Bad Status: $statusline" unless $statusline eq 'HTTP/1.1 200 OK';
        my $eoh = strstr(Pointer.new($eol+2), "\r\n\r\n");
#        my $headers = $buf.subbuf(($eol + 2 - $ptr) ..^ ($eoh - $ptr)).decode;
#        say $headers;
        $buf = $buf.subbuf($eoh+4-$ptr);
        start
        {
            loop
            {
                last unless self!dechunk($buf);
                $buf = $!rest.curl.handle.recv(:$!timeout);
            }
        }
    }

    method Str()
    {
        my $str = '';
        self.stdout.tap({ $str ~= $_ });
        await self.start;
        $str
    }
}
