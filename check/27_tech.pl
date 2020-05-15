#!/usr/bin/perl -w
#
#  c2check: tech level tests
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

test 'check/27_tech/lower/hull', sub { check_lowered_tech(shift, 'hulltech',   'Hull Tech') };
test 'check/27_tech/lower/eng',  sub { check_lowered_tech(shift, 'enginetech', 'Engine Tech') };
test 'check/27_tech/lower/beam', sub { check_lowered_tech(shift, 'beamtech',   'Beam Tech') };
test 'check/27_tech/lower/torp', sub { check_lowered_tech(shift, 'torptech',   'Torpedo Tech') };


##
##  Canned test
##

# Test lowering tech.
# A: prepare game directory that sells a tech level
# E: check fails
sub check_lowered_tech {
    my ($setup, $property_name, $print_name) = @_;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { $_[0]{6}{money} = 1000; });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { $_[0]{6}{money} = 100; });
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { $_[0]{1}{$property_name} = 9; });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { $_[0]{1}{$property_name} = 10; });
    ct_run_must_fail($setup, $dir, "$print_name has been lowered. This is not permitted.");
}
