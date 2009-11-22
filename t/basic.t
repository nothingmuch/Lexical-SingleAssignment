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
    local $Test::Builder::Level = $Test::Builder::Level + 1;
    &is( _eval($code), '', @args );
}

sub eval_nok {
    my ( $code, $re, @args ) = @_;

    $re ||= qr/./;

    local $Test::Builder::Level = $Test::Builder::Level + 1;
    &like( _eval($code), $re, @args );
}

eval_ok q{
    my $x = 4;
};

eval_ok q{
    my $x = 4;
    is( $x, 4, "sassign still works" );
};

eval_ok q{
    my $x = rand;
    ok( defined($x), "sassign still works" );
};

eval_ok q{
    my @y = qw(foo bar);
};

eval_ok q{
    my @y = qw(foo bar);
    is( scalar(@y), 2, "aassign still works" );
};

eval_ok q{
    my ( $x, @y ) = qw(foo bar);

    is( $x, "foo", "compound aasign still works");
    is( $y[0], "bar", "compound aassign still works");
};

eval_nok q{
    my $x = 4;
    $x = 5;
}, qr/declaration/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);
    $x = "bar";
}, qr/declaration/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);
    ( $x, @y ) = qw(bar foo);
}, qr/declaration/;

eval_nok q{
    my $x = "foo";
    my $y = "bar";

    ( $x, $y ) = qw(bar foo);
}, qr/declaration/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);

    local $TODO = "can't detect assignment to subscript over AV/HV yet, runtime error instead";
    fail("caught at compile time");

    $y[0] = "foo";
};

eval_nok q{
    my ( $x, @y ) = qw(foo bar);

    local $TODO = "can't detect assignment to subscript over AV/HV yet, runtime error instead";
    fail("caught at compile time");

    pop @y;
};

eval_nok q{
    my ( $x, %z ) = qw(foo bar baz);

    local $TODO = "can't detect assignment to subscript over AV/HV yet, runtime error instead";
    fail("caught at compile time");

    $z{bar} = "foo";
};

eval_nok q{
    my ( $x, %z ) = qw(foo bar baz);

    local $TODO = "can't detect assignment to subscript over AV/HV yet, runtime error instead";
    fail("caught at compile time");

    $z{new_key} = "foo";
};

eval_nok q{
    my $x = 3;
    my $ref = \$x;
    $$ref = 3;
}, qr/read-only/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);

    my $ref = \$x;
    $$ref = "bar";
}, qr/read-only/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);

    my $ref = \@y;
    pop @$ref;
}, qr/read-only/;

eval_nok q{
    my ( $x, @y ) = qw(foo bar);

    my $ref = \@y;
    $ref->[0] = "foo";
}, qr/read-only/;

eval_nok q{
    my $x;
}, qr/lexical without assignment/;

eval_nok q{
    my @y;
}, qr/lexical without assignment/;

eval_nok q{
    my %h;
}, qr/lexical without assignment/;

eval_nok q{
    my $x = 3;

    BEGIN { die "foo" }
}, qr/foo/;

eval_nok q{
    my $x;

    BEGIN { die "foo" }
}, qr/foo/;

done_testing;

# ex: set sw=4 et:

