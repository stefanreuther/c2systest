#!/usr/bin/perl -w
#
#  c2check: test duplicate ship
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test ship seen twice.
# A ship is seen twice if an owned planet is seen twice.
# We own planets 10 {1} and 14 {2}, as well as ship 7 {1}.
# A: prepare situation with two planets at one location, ship in orbit
# E: succeeds with warning
test 'check/32_dupship', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/xyplan.dat", { mode=>'fixed', count=>500, pattern=>'v3', fields=>['x','y','z'] },
                 sub {
                     $_[0]{10}{x} = $_[0]{14}{x} = 999;
                     $_[0]{10}{y} = $_[0]{14}{y} = 998;
                 });
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(),
                 sub {
                     $_[0]{1}{x} = 999;
                     $_[0]{1}{y} = 998;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(),
                 sub {
                     $_[0]{1}{x} = 999;
                     $_[0]{1}{y} = 998;
                 });
    ct_run_must_succeed_with_message($setup, $dir, "WARNING: Ship 7 seen again during orbits check.");
};
