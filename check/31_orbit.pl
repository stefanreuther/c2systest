#!/usr/bin/perl -w
#
#  c2check: test in-orbit resource mismatch
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test resource mismatch using dat/dis files.
# Tests all possible resources, including multiple cases for ammo.
test 'check/31_orbit/dat/n',     sub { test_imbalance_dat(shift, 'n',     60, 1); };
test 'check/31_orbit/dat/t',     sub { test_imbalance_dat(shift, 't',     60, 1); };
test 'check/31_orbit/dat/d',     sub { test_imbalance_dat(shift, 'd',     60, 1); };
test 'check/31_orbit/dat/m',     sub { test_imbalance_dat(shift, 'm',     60, 1); };
test 'check/31_orbit/dat/money', sub { test_imbalance_dat(shift, 'money', 60, 1); };
test 'check/31_orbit/dat/sup',   sub { test_imbalance_dat(shift, 'sup',   60, 1); };
test 'check/31_orbit/dat/clans', sub { test_imbalance_dat(shift, 'clans', 60, 1); };
test 'check/31_orbit/dat/t1',    sub { test_imbalance_dat(shift, 'ammo',  60, 1); };
test 'check/31_orbit/dat/t10',   sub { test_imbalance_dat(shift, 'ammo',  60, 10); };
test 'check/31_orbit/dat/ftr',   sub { test_imbalance_dat(shift, 'ammo',  67, 0); };

# Test resource mismatch using turn file.
# Planet 10 {1} is a planet with no ship in orbit.
# Neither an upward change, nor a downward change (=jettison) is allowed.
test 'check/31_orbit/trn/n1',     sub { test_imbalance_trn(shift, pack("vvV", 25, 10, 1)); };
test 'check/31_orbit/trn/n1000',  sub { test_imbalance_trn(shift, pack("vvV", 25, 10, 1000)); };
test 'check/31_orbit/trn/t1',     sub { test_imbalance_trn(shift, pack("vvV", 26, 10, 1)); };
test 'check/31_orbit/trn/t1000',  sub { test_imbalance_trn(shift, pack("vvV", 26, 10, 1000)); };
test 'check/31_orbit/trn/d1',     sub { test_imbalance_trn(shift, pack("vvV", 27, 10, 1)); };
test 'check/31_orbit/trn/d1000',  sub { test_imbalance_trn(shift, pack("vvV", 27, 10, 1000)); };
test 'check/31_orbit/trn/m1',     sub { test_imbalance_trn(shift, pack("vvV", 28, 10, 1)); };
test 'check/31_orbit/trn/m1000',  sub { test_imbalance_trn(shift, pack("vvV", 28, 10, 1000)); };
test 'check/31_orbit/trn/c1',     sub { test_imbalance_trn(shift, pack("vvV", 29, 10, 1)); };
test 'check/31_orbit/trn/c1000',  sub { test_imbalance_trn(shift, pack("vvV", 29, 10, 1000)); };
test 'check/31_orbit/trn/s1',     sub { test_imbalance_trn(shift, pack("vvV", 30, 10, 1)); };
test 'check/31_orbit/trn/s1000',  sub { test_imbalance_trn(shift, pack("vvV", 30, 10, 1000)); };
test 'check/31_orbit/trn/mc1',    sub { test_imbalance_trn(shift, pack("vvV", 31, 10, 1)); };
test 'check/31_orbit/trn/mc1000', sub { test_imbalance_trn(shift, pack("vvV", 31, 10, 1000)); };
test 'check/31_orbit/trn/mine1',  sub { test_imbalance_trn(shift, pack("vvv", 22, 10, 1)); };
test 'check/31_orbit/trn/mine20', sub { test_imbalance_trn(shift, pack("vvv", 22, 10, 20)); };
test 'check/31_orbit/trn/fact1',  sub { test_imbalance_trn(shift, pack("vvv", 23, 10, 1)); };
test 'check/31_orbit/trn/fact20', sub { test_imbalance_trn(shift, pack("vvv", 23, 10, 20)); };
test 'check/31_orbit/trn/def1',   sub { test_imbalance_trn(shift, pack("vvv", 24, 10, 1)); };
test 'check/31_orbit/trn/def20',  sub { test_imbalance_trn(shift, pack("vvv", 24, 10, 20)); };

# Same thing, using a starbase.
test 'check/31_orbit/trn/e1',     sub { test_imbalance_trn(shift, pack("vvv", 44, 63, 1, 1)); };
test 'check/31_orbit/trn/e9',     sub { test_imbalance_trn(shift, pack("vvv", 44, 63, 9, 1)); };
test 'check/31_orbit/trn/h1',     sub { test_imbalance_trn(shift, pack("vvv", 45, 63, 1, 1)); };
test 'check/31_orbit/trn/h20',    sub { test_imbalance_trn(shift, pack("vvv", 45, 63, 20, 1)); };
test 'check/31_orbit/trn/b1',     sub { test_imbalance_trn(shift, pack("vvv", 46, 63, 1, 1)); };
test 'check/31_orbit/trn/b10',    sub { test_imbalance_trn(shift, pack("vvv", 46, 63, 10, 1)); };
test 'check/31_orbit/trn/l1',     sub { test_imbalance_trn(shift, pack("vvv", 47, 63, 1, 1)); };
test 'check/31_orbit/trn/l10',    sub { test_imbalance_trn(shift, pack("vvv", 47, 63, 10, 1)); };
test 'check/31_orbit/trn/t1',     sub { test_imbalance_trn(shift, pack("vvv", 48, 63, 1, 1)); };
test 'check/31_orbit/trn/t10',    sub { test_imbalance_trn(shift, pack("vvv", 48, 63, 10, 1)); };
test 'check/31_orbit/trn/ftr1',   sub { test_imbalance_trn(shift, pack("vvv", 49, 63, 1)); };
test 'check/31_orbit/trn/ftr30',  sub { test_imbalance_trn(shift, pack("vvv", 49, 63, 30)); };


# Test mc/sup mismatch resolved by supply sale.
# This is the same test case as check/31_orbit/supply_sale, but taking place over a planet.
test 'check/31_orbit/supply_sale', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);

    # Prepare two ships at the same place
    my $prepare_ships = sub {
        foreach my $s (1, 2) {
            $_[0]{$s}{x} = 2239;
            $_[0]{$s}{y} = 2651;
            $_[0]{$s}{hull} = 16;
            $_[0]{$s}{torp} = $_[0]{$s}{ntubes} = $_[0]{$s}{nbays} = 0;
        }
    };

    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub 
                 {
                     $prepare_ships->(@_);
                     $_[0]{1}{sup} = 0;
                     $_[0]{2}{money} = 10;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub 
                 {
                     $prepare_ships->(@_);
                     $_[0]{1}{sup} = 10;
                     $_[0]{2}{money} = 0;
                 });
    ct_run_must_succeed($setup, $dir);
};



##
##  Canned tests
##

sub test_imbalance_dat {
    my ($setup, $property_name, $hull_type, $torp_type) = @_;
    my $dir = ct_prepare_game_unpack($setup);

    # Ship #7 {1} is at a planet that has no base
    my $prepare_ship = sub {
        $_[0]{1}{hull} = $hull_type;
        $_[0]{1}{torp} = $torp_type;
        $_[0]{1}{ntubes} = $torp_type ? 1 : 0;
        $_[0]{1}{nbays} = $torp_type ? 0 : 1;
    };

    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub 
                 {
                     $prepare_ship->(@_);
                     $_[0]{1}{$property_name} = 5;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub 
                 {
                     $prepare_ship->(@_);
                     $_[0]{1}{$property_name} = 3;
                 });
    ct_run_must_fail($setup, $dir, "Resources do not match");
}

sub test_imbalance_trn {
    my ($setup, @commands) = @_;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", @commands));
    ct_run_must_fail($setup, $dir, "Resources do not match", '-r');
}
