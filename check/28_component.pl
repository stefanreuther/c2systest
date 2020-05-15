#!/usr/bin/perl -w
#
#  c2check: component tests
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test component sale.
test 'check/28_component/sold/h1',       sub { check_component_sold(shift, 'h1',          2,  2,  3,  10, 'Hull #15');     };
test 'check/28_component/sold/h10',      sub { check_component_sold(shift, 'h10',        71, 52, 93, 390, 'Hull #61');     };
test 'check/28_component/sold/e1',       sub { check_component_sold(shift, 'e1',          5,  1,  0,   1, 'Engine #1');    };
test 'check/28_component/sold/e9',       sub { check_component_sold(shift, 'e9',          3, 16, 35, 300, 'Engine #9');    };
test 'check/28_component/sold/b1',       sub { check_component_sold(shift, 'b1',          1,  0,  0,   1, 'Beam #1');      };
test 'check/28_component/sold/b10',      sub { check_component_sold(shift, 'b10',         1, 12, 55,  54, 'Beam #10');     };
test 'check/28_component/sold/t1',       sub { check_component_sold(shift, 't1',          1,  1,  1,   1, 'Torpedo #1');   };
test 'check/28_component/sold/t10',      sub { check_component_sold(shift, 't10',         1,  1,  1,  54, 'Torpedo #10');  };
test 'check/28_component/sold/l1',       sub { check_component_sold(shift, 'l1',          1,  1,  0,   1, 'Launcher #1');  };
test 'check/28_component/sold/l10',      sub { check_component_sold(shift, 'l10',         1,  1,  9, 190, 'Launcher #10'); };
test 'check/28_component/sold/fighters', sub { check_component_sold(shift, 'fighters',    3,  0,  2, 100, 'Fighters');     };
test 'check/28_component/sold/basedef',  sub { check_component_sold(shift, 'basedefense', 0,  1,  2,  10, 'Base Defense'); };

# Tech level tests
test 'check/28_component/tech/h10',      sub { check_missing_tech(shift, 'h10', 71, 52, 93, 390, 'Hull #61');     };
test 'check/28_component/tech/e9',       sub { check_missing_tech(shift, 'e9',   3, 16, 35, 300, 'Engine #9');    };
test 'check/28_component/tech/b10',      sub { check_missing_tech(shift, 'b10',  1, 12, 55,  54, 'Beam #10');     };
test 'check/28_component/tech/t10',      sub { check_missing_tech(shift, 't10',  1,  1,  1,  54, 'Torpedo #10');  };
test 'check/28_component/tech/l10',      sub { check_missing_tech(shift, 'l10',  1,  1,  9, 190, 'Launcher #10'); };



##
##  Canned tests
##

# Test selling components
# A: prepare game directory that sells components
# E: check fails
sub check_component_sold {
    my ($setup, $property_name, $t, $d, $m, $mc, $print_name) = @_;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = $t;
                     $_[0]{6}{d} = $d;
                     $_[0]{6}{m} = $m;
                     $_[0]{6}{money} = $mc;
                 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = $_[0]{6}{d} = $_[0]{6}{m} = $_[0]{6}{money} = 0;
                 });
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub
                 {
                     $_[0]{1}{$property_name} = 3;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub
                 {
                     $_[0]{1}{$property_name} = 4;
                 });
    ct_run_must_fail($setup, $dir, "1 $print_name have been sold. This is not permitted");
};

# Test buying components without tech
# A: prepare game directory that buys components without appropriate tech
# E: check fails
sub check_missing_tech {
    my ($setup, $property_name, $t, $d, $m, $mc, $print_name) = @_;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = $_[0]{6}{d} = $_[0]{6}{m} = $_[0]{6}{money} = 0;
                 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub
                 {
                     $_[0]{6}{t} = $t;
                     $_[0]{6}{d} = $d;
                     $_[0]{6}{m} = $m;
                     $_[0]{6}{money} = $mc;
                 });
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub
                 {
                     $_[0]{1}{$property_name} = 4;
                     $_[0]{1}{hulltech} = $_[0]{1}{enginetech} = $_[0]{1}{beamtech} = $_[0]{1}{torptech} = 5;
                 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub
                 {
                     $_[0]{1}{$property_name} = 3;
                     $_[0]{1}{hulltech} = $_[0]{1}{enginetech} = $_[0]{1}{beamtech} = $_[0]{1}{torptech} = 5;
                 });
    ct_run_must_fail($setup, $dir, "$print_name has been built without sufficient tech.");
};
