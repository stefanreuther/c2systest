#!/usr/bin/perl -w
#
#  c2check: additional ship transporter field checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test empty transfer with existing target.
# In dat/dis mode, these are only reported when not being picky (maketurn ought to suppress them).
# In rst/trn mode, these should be reported.
test 'check/21_shiptransfer/transfer/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{4}{transferid} = 158 });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_fail($setup, $dir, "INVALID: Ship 69: Transfer order is empty but has target.", '-p');
};
test 'check/21_shiptransfer/transfer/trn', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 9, 69, 0, 0, 0, 0, 0, 0, 158)));
    ct_run_must_fail($setup, $dir, "INVALID: Ship 69: Transfer order is empty but has target.", '-r');
};
test 'check/21_shiptransfer/unload/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{unloadid} = 346 });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_fail($setup, $dir, "INVALID: Ship 7: Unload order is empty but has target.", '-p');
};
test 'check/21_shiptransfer/unload/trn', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 8, 7, 0, 0, 0, 0, 0, 0, 346)));
    ct_run_must_fail($setup, $dir, "INVALID: Ship 7: Unload order is empty but has target.", '-r');
};

# Test unloading to wrong planet.
# Ship in free space must not unload to a planet.
test 'check/21_shiptransfer/unload/space', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub 
                 {
                     my $e = shift;
                     $e->{3}{unloadid} = 10;
                     $e->{3}{unloadn} = 4;
                     $e->{3}{n} = 30;
                 });
    ct_run_must_fail($setup, $dir, "RANGE: Ship 34: Unload order has invalid target.");
};
test 'check/21_shiptransfer/unload/planet', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub 
                 {
                     my $e = shift;
                     $e->{1}{unloadid} = 0;
                     $e->{1}{unloadn} = 4;
                     $e->{1}{n} = 35
                 });
    ct_run_must_fail($setup, $dir, "RANGE: Ship 7: Unload order has invalid target.");
};
