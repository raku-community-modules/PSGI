# Some helpers for PSGI frameworks.
use HTTP::Status;

my constant CRLF = "\x0D\x0A";              # Output lines separated by CRLF.
my constant STATUS_HEADER = 'Status:';      # Used for Parsed Headers.
my constant DEFAULT_PROTOCOL = 'HTTP/1.0';  # Used for Non-Parsed Headers.

# Encode a PSGI-compliant response.
# The Code must be a Str or Int representing the numeric HTTP status code.
# Headers can be an Array of Pairs, or a Hash.
# Body can be an Array, a Str or a Buf.
proto sub encode-psgi-response(|) is export {*}
multi sub encode-psgi-response(
  Int() $code,                      # Required parameters
     $headers,
        $body,
  Bool :$nph,                       # Optional parameters
       :$protocol = DEFAULT_PROTOCOL
) {
    my Stringy $output = ($nph ?? $protocol !! STATUS_HEADER)
      ~ " $code "
      ~ get_http_status_msg($code) 
      ~ CRLF;

    my @headers = $headers ~~ List
       ?? @$headers
       !! $headers ~~ Map
         ?? $headers.pairs
         !! ();

    for @headers -> $header {
        $header ~~ Pair
          ?? ($output ~= $header.key ~ ': ' ~ $header.value ~ CRLF)
          !! (warn "invalid PSGI header found")
    }
    $output ~= CRLF;  # Finished with headers

    sub add-to-output($segment --> Nil) {  # convert to Buf on the fly
        $segment ~~ Buf
          ?? $output ~~ Buf
            ?? ($output ~= $segment)
            !! ($output = $output.encode ~ $segment)
          !! $output ~~ Buf
            ?? ($output ~= $segment.Str.encode)
            !! ($output ~= $segment.Str);
    }

    if $body ~~ Supply {
        $body.tap: &add-to-output;
        $body.wait;
    }
    else {
        my @body = $body ~~ List ?? @$body !! $body;
        @body.map: &add-to-output;
    }

    $output
}

# A version that takes a Promise.
multi sub encode-psgi-response(
    Promise:D $p,
    Bool   :$nph,
           :$protocol = DEFAULT_PROTOCOL
) {
    encode-psgi-response $p.result, :$nph, :$protocol
}

# A version that takes the traditional Array of three elements,
# and uses them as the positional parameters for the above version.
multi sub encode-psgi-response (
    @response,
    Bool :$nph, :$protocol=DEFAULT_PROTOCOL
) {
    encode-psgi-response |@response, :$nph, :$protocol
}

# Take an environment hash, and populate the P6SGI/PSGI variables.
sub populate-psgi-env (
        %env, 
        :$input,                      # input stream (if any)
        :$errors,                     # error stream (if any)
        :$input-buffered  = False,    # is input buffered? (P6SGI 0.4 only)
        :$errors-buffered = False,    # are errors buffered? (P6SGI 0.4 only)
        :$url-scheme      = 'http',   # HTTP or HTTPS
        :$multithread     = False,    # Can be multithreaded?
        :$multiprocess    = False,    # Can be multiprocessed?
        :$ready           = Nil,      # A Promise (P6SGI 0.7 only)
        :$protocol        = 'http',   # Protocol being used (P6SGI 0.7 only)
        :$run-once        = False,    # Should only be run once in a process?
        :$encoding        = 'utf8',   # Character encoding (P6SGI only)
        :$nonblocking     = False,    # Non-blocking IO (PSGI Classic only)
        :$streaming       = False;    # Streaming IO (PSGI Classic only)
        :$psgi-classic    = False,    # include PSGI Classic headers
        :$p6sgi           = True,     # include default P6SGI version(s).
) is export {
    my $p6sgi_04 = False;
    my $p6sgi_07 = False;
    if $protocol ~~ List {
        $protocol = set($protocol);
    }
    if $p6sgi ~~ Bool && $p6sgi {
        $p6sgi_04 = True;
        $p6sgi_07 = True;
    }
    elsif $p6sgi ~~ Str {
        my str $sgiver = $p6sgi.lc;
        if $sgiver eq 'all' {
            $p6sgi_04 = True;
            $p6sgi_07 = True;
        }
        elsif $sgiver eq 'default' {
            $p6sgi_04 = True;
            $p6sgi_07 = True;
        }
        elsif $sgiver eq 'latest' {
            $p6sgi_07 = True;
        }
        elsif $sgiver eq '4' || $sgiver eq '0.4' || $sgiver eq '0.4draft' {
            $p6sgi_04 = True;
        }
        elsif $sgiver eq '7' || $sgiver eq '0.7' || $sgiver eq '0.7draft' {
            $p6sgi_07 = True;
        }
    }
    elsif $p6sgi ~~ Numeric {
        if $p6sgi == 4 | 0.4 {
            $p6sgi_04 = True;
        }
        elsif $p6sgi == 7 | 0.7 {
            $p6sgi_07 = True;
        }
    }
    if $p6sgi_07 {
        %env<p6w.version>      = Version.new('0.7.Draft');
        %env<p6w.url-scheme>   = $url-scheme;
        %env<p6w.input>        = $input;
        %env<p6w.errors>       = $errors;
        %env<p6w.multithread>  = $multithread;
        %env<p6w.multiprocess> = $multiprocess;
        %env<p6w.run-once>     = $run-once;
        %env<p6w.protocol>     = $protocol;
        %env<p6w.ready> = $_ with $ready;
    }
    if $p6sgi_04 {
        %env<p6sgi.version>         = Version.new('0.4.Draft');
        %env<p6sgi.url-scheme>      = $url-scheme;
        %env<p6sgi.input>           = $input;
        %env<p6sgi.input.buffered>  = $input-buffered;
        %env<p6sgi.errors>          = $errors;
        %env<p6sgi.errors.buffered> = $errors-buffered;
        %env<p6sgi.multithread>     = $multithread;
        %env<p6sgi.multiprocess>    = $multiprocess;
        %env<p6sgi.run-once>        = $run-once;
        %env<p6sgi.encoding>        = $encoding;
    }
    if $psgi-classic {
        %env<psgi.version>      = [1,0];
        %env<psgi.url_scheme>   = $url-scheme;
        %env<psgi.multithread>  = $multithread;
        %env<psgi.multiprocess> = $multiprocess;
        %env<psgi.input>        = $input;
        %env<psgi.errors>       = $errors;
        %env<psgi.run_once>     = $run-once;
        %env<psgi.nonblocking>  = $nonblocking;
    }
}

=begin pod

=head1 NAME

PSGI - Helper library for creating P6SGI/PSGI compliant frameworks

=head1 SYNOPSIS

=begin code :lang<raku>

use PSGI;

# Using a traditional PSGI response array.
# Headers are an Array of Pairs.
# Body is an Array of Str or Buf.
my $status   = 200;
my $headers  = ['Content-Type'=>'text/plain'];
my $body     = ["Hello world"];
my @response = [ $status, $headers, $body ];
my $string = encode-psgi-response(@response);
#
#   Status: 200 OK
#   Content-Type: text/plain
#
#   Hello world
#

# Passing the elements individually.
# Also, this time, we want to use NPH output.
$string = encode-psgi-response($status, $headers, $body, :nph);
#
#   HTTP/1.0 200 OK
#   Content-Type: text/plain
#
#   Hello world
#

# Now an example using a Hash for headers, and a singleton
# for the body.
my %headers =
  Content-Type => 'text/plain',
;
my $body-text = "Hello world";
$string = encode-psgi-response($code, %headers, $body-text);
#
# Same output as first example
#

# Populate an %env with P6SGI/PSGI variables.
#
my %env;
populate-psgi-env %env, :input($in), :errors($err), :p6sgi<latest>;

=end code

See the tests for further examples.

=head1 DESCRIPTION

Provides functions for encoding P6SGI/PSGI responses, and populating
P6SGI/PSGI environments.

It supports (in order of preference), P6SGI 0.7Draft, P6SGI 0.4Draft,
and a minimal subset of PSGI Classic (from Perl).

If the C<populate-psgi-env> subroutine is called without specifying
a specific version, both P6SGI 0.7Draft and P6SGI 0.4Draft headers
will be included. PSGI Classic headers must be explicitly requested.

=head1 AUTHOR

Timothy Totten

=head1 COPYRIGHT AND LICENSE

Copyright 2013 - 2016 Timothy Totten

Copyright 2017 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify
it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
