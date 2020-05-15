#!/usr/bin/perl -w
#
#  c2check: ship editable field checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test ship editable fields. Each of these tests tests:
# - modification out-of-range must give an error
# - if the value is out-of-range but not modified, it must give an error with "-p"
# Many of these will also give additional BALANCE errors.
test 'check/19_shipedit/warp', sub {
    my $setup = shift;
    ship_editable_test($setup, 'warp', 'Speed', [-1,10]);
};
test 'check/19_shipedit/dx', sub {
    my $setup = shift;
    ship_editable_test($setup, 'dx', 'Waypoint DX', [-10000,10000]);
};
test 'check/19_shipedit/dy', sub {
    my $setup = shift;
    ship_editable_test($setup, 'dy', 'Waypoint DY', [-10000,10000]);
};
test 'check/19_shipedit/ammo', sub {
    my $setup = shift;
    # Ship has 70 room, so 71 is out of range. FIXME: should check whole cargo
    ship_editable_test($setup, 'ammo', 'Ammo', [-1,71]);
};
test 'check/19_shipedit/mission', sub {
    my $setup = shift;
    ship_editable_test($setup, 'mission', 'Mission', [-1,10001]);
};
test 'check/19_shipedit/enemy', sub {
    my $setup = shift;
    ship_editable_test($setup, 'enemy', 'Enemy', [-1,12]);
};
test 'check/19_shipedit/towarg', sub {
    my $setup = shift;
    ship_editable_test($setup, 'towarg', 'Mission Tow arg', [-1,10001]);
};
test 'check/19_shipedit/intarg', sub {
    my $setup = shift;
    ship_editable_test($setup, 'intarg', 'Mission Intercept arg', [-1,10001]);
};
test 'check/19_shipedit/clans', sub {
    my $setup = shift;
    ship_editable_test($setup, 'clans', 'Colonists', [-1,71]);
};
test 'check/19_shipedit/n', sub {
    my $setup = shift;
    ship_editable_test($setup, 'n', 'Neutronium', [-1,201]);
};
test 'check/19_shipedit/t', sub {
    my $setup = shift;
    ship_editable_test($setup, 't', 'Tritanium', [-1,71]);
};
test 'check/19_shipedit/d', sub {
    my $setup = shift;
    ship_editable_test($setup, 'd', 'Duranium', [-1,71]);
};
test 'check/19_shipedit/m', sub {
    my $setup = shift;
    ship_editable_test($setup, 'm', 'Molybdenum', [-1,71]);
};
test 'check/19_shipedit/sup', sub {
    my $setup = shift;
    ship_editable_test($setup, 'sup', 'Supplies', [-1,71]);
};
test 'check/19_shipedit/money', sub {
    my $setup = shift;
    ship_editable_test($setup, 'money', 'Money', [-1,10001]);
};


##
##  Canned test
##
sub ship_editable_test {
    my ($setup, $field_name, $print_name, $values) = @_;

    # Test modification
    foreach my $v (@$values) {
        trace_process("Trying dat value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, "RANGE: Ship 7: $print_name out of allowed range.");
    }

    # Test previously-out-of-range
    foreach my $v (@$values) {
        trace_process("Trying dat+dis value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{$field_name} = $v });
        ct_run_must_succeed($setup, $dir);
        ct_run_must_fail($setup, $dir, "RANGE: Ship 7: $print_name out of allowed range.", '-p');
    }
}
