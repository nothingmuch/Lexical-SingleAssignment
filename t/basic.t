#!/usr/bin/perl

use strict;
use warnings;

use Test::More;

sub _eval {
    my $code = shift;

    local $@;

    # double eval necessary for cleanup-time bugs
    my $ok = eval qq{
        use Lexical::SingleAssignment;
        $code;
        1;
    };

    return $ok ? '' : ( $@ || "unknown error" );
}

sub eval_ok {
    my ( $code, @args ) = @_;
    &is( _eval($code), '', @args );
}

sub eval_nok {
    my ( $code, $re, @args ) = @_;

    $re ||= qr/./;

    &like( _eval($code), $re, @args );
}

eval_ok q{
    my $x = 4;
};

eval_ok q{
    my $x = 4;
    is( $x, 4 );
};

eval_ok q{
    my $x = rand;
    ok( defined($x) );
};

eval_nok q{
    my $x = 4;
    $x = 5;
};

eval_nok q{
    my $x = 3;
    my $ref = \$x;
    $$ref = 3;
}, qr/read-only/;

eval_nok q{
    my $x;
}, qr/lexical without assignment/;


eval_nok q{
    my $x = 3;

    BEGIN { die "foo" }
}, qr/foo/;

{
    local $TODO = "overwrites errors";
    eval_nok q{
        my $x;

        BEGIN { die "foo" }
    }, qr/foo/;
}

done_testing;

# ex: set sw=4 et:

