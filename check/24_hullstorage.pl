#!/usr/bin/perl -w
#
#  c2check: check hull storage
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test hull storage owner validation.
# This used to fail (segv) when accessing truehull.
test 'check/24_hullstorage/owner', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{baseowner} = 9000 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{baseowner} = 9000 });
    ct_run_must_fail($setup, $dir, "Base Owner out of allowed range");
};

# Test that invalid changes are listed as Unused.
test 'check/24_hullstorage/storage', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub
                 {
                     my $e = shift;
                     $e->{1}{baseowner} = 9000;
                     $e->{1}{h1} = -1;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{baseowner} = 9000 });
    ct_run_must_fail($setup, $dir, "Unused hull storage #1 out of allowed range");
};
