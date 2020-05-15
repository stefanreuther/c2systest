#!/usr/bin/perl -w
#
#  c2check: test free-space resource mismatch
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test resource mismatch using dat/dis files.
# Tests all possible resources, including multiple cases for ammo.
test 'check/30_freespace/dat/n',     sub { test_imbalance_dat(shift, 'n',     60, 1); };
test 'check/30_freespace/dat/t',     sub { test_imbalance_dat(shift, 't',     60, 1); };
test 'check/30_freespace/dat/d',     sub { test_imbalance_dat(shift, 'd',     60, 1); };
test 'check/30_freespace/dat/m',     sub { test_imbalance_dat(shift, 'm',     60, 1); };
test 'check/30_freespace/dat/money', sub { test_imbalance_dat(shift, 'money', 60, 1); };
test 'check/30_freespace/dat/sup',   sub { test_imbalance_dat(shift, 'sup',   60, 1); };
test 'check/30_freespace/dat/clans', sub { test_imbalance_dat(shift, 'clans', 60, 1); };
test 'check/30_freespace/dat/t1',    sub { test_imbalance_dat(shift, 'ammo',  60, 1); };
test 'check/30_freespace/dat/t10',   sub { test_imbalance_dat(shift, 'ammo',  60, 10); };
test 'check/30_freespace/dat/ftr',   sub { test_imbalance_dat(shift, 'ammo',  67, 0); };

# Test resource mismatch using RST/TRN file.
# Ship #34 {3} is a MDSF in free space, with 34N, 200c
test 'check/30_freespace/trn/n', sub { test_imbalance_trn(shift, pack("v*", 11, 34, 40)); };
test 'check/30_freespace/trn/t', sub { test_imbalance_trn(shift, pack("v*", 12, 34, 1));  };
test 'check/30_freespace/trn/d', sub { test_imbalance_trn(shift, pack("v*", 13, 34, 1));  };
test 'check/30_freespace/trn/m', sub { test_imbalance_trn(shift, pack("v*", 14, 34, 1));  };

# Test mc/sup mismatch. There is no supply sale in space.
# A: prepare directory where supplies have been converted to money in space
# E: check must fail
test 'check/30_freespace/supply_sale', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);

    # Prepare two ships at the same place
    my $prepare_ships = sub {
        foreach my $s (1, 2) {
            $_[0]{$s}{x} = 900;
            $_[0]{$s}{y} = 950;
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
    ct_run_must_fail($setup, $dir, "Resources appeared in free space");
};


##
##  Canned tests
##

# Check imbalance in game directory
# A: prepare location with two ships, imbalance in one resource
# E: check must fail
sub test_imbalance_dat {
    my ($setup, $property_name, $hull_type, $torp_type) = @_;
    my $dir = ct_prepare_game_unpack($setup);

    # Prepare two ships at the same place
    my $prepare_ships = sub {
        foreach my $s (1, 2) {
            $_[0]{$s}{x} = 900;
            $_[0]{$s}{y} = 950;
            $_[0]{$s}{hull} = $hull_type;
            $_[0]{$s}{torp} = $torp_type;
            $_[0]{$s}{ntubes} = $torp_type ? 1 : 0;
            $_[0]{$s}{nbays} = $torp_type ? 0 : 1;
        }
    };

    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub 
                 {
                     $prepare_ships->(@_);
                     $_[0]{1}{$property_name} = 5;
                     $_[0]{2}{$property_name} = 4;
                 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub 
                 {
                     $prepare_ships->(@_);
                     $_[0]{1}{$property_name} = 6;
                     $_[0]{2}{$property_name} = 2;
                 });
    ct_run_must_fail($setup, $dir, "Resources appeared in free space");
}

# Check imbalance in turn file
# A: apply imbalanced command to turn file
# E: check must fail
sub test_imbalance_trn {
    my ($setup, @commands) = @_;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", @commands));
    ct_run_must_fail($setup, $dir, "Resources appeared in free space", '-r');
}
