[![Actions Status](https://github.com/raku-community-modules/PSGI/actions/workflows/test.yml/badge.svg)](https://github.com/raku-community-modules/PSGI/actions)

NAME
====

PSGI - Helper library for creating P6SGI/PSGI compliant frameworks

SYNOPSIS
========

```raku
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
```

See the tests for further examples.

DESCRIPTION
===========

Provides functions for encoding P6SGI/PSGI responses, and populating P6SGI/PSGI environments.

It supports (in order of preference), P6SGI 0.7Draft, P6SGI 0.4Draft, and a minimal subset of PSGI Classic (from Perl).

If the `populate-psgi-env` subroutine is called without specifying a specific version, both P6SGI 0.7Draft and P6SGI 0.4Draft headers will be included. PSGI Classic headers must be explicitly requested.

AUTHOR
======

Timothy Totten

COPYRIGHT AND LICENSE
=====================

Copyright 2013 - 2016 Timothy Totten

Copyright 2017 - 2022 Raku Community

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

