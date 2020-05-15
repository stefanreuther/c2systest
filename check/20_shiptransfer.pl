#!/usr/bin/perl -w
#
#  c2check: ship transporter field checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';


# Test regular fields. Each of these tests tests:
# - modification out-of-range must give an error
# - if the value is out-of-range but not modified, it must give an error with "-p"
# These will also give additional BALANCE errors.
# - Transfer
test 'check/20_shiptransfer/transfer/n', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transfern', 'Transfer Neutronium', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/t', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transfert', 'Transfer Tritanium', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/d', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transferd', 'Transfer Duranium', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/n', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transferm', 'Transfer Molybdenum', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/clans', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transferclans', 'Transfer Colonists', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/sup', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transfersup', 'Transfer Supplies', [-1,10001]);
};
test 'check/20_shiptransfer/transfer/target', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'transferid', 'Transfer Target', [-1,10001]);
};
# - Unload
test 'check/20_shiptransfer/unload/n', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadn', 'Unload Neutronium', [-1,10001]);
};
test 'check/20_shiptransfer/unload/t', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadt', 'Unload Tritanium', [-1,10001]);
};
test 'check/20_shiptransfer/unload/d', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadd', 'Unload Duranium', [-1,10001]);
};
test 'check/20_shiptransfer/unload/n', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadm', 'Unload Molybdenum', [-1,10001]);
};
test 'check/20_shiptransfer/unload/clans', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadclans', 'Unload Colonists', [-1,10001]);
};
test 'check/20_shiptransfer/unload/sup', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadsup', 'Unload Supplies', [-1,10001]);
};
test 'check/20_shiptransfer/unload/target', sub {
    my $setup = shift;
    ship_transfer_test($setup, 'unloadid', 'Unload Target', [-1,10001]);
};


##
##  Canned test
##
sub ship_transfer_test {
    my ($setup, $field_name, $print_name, $values) = @_;

    # The third ship is #34; it is in free space.

    # Test modification
    foreach my $v (@$values) {
        trace_process("Trying dat value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{3}{$field_name} = $v });
        ct_run_must_fail($setup, $dir, "RANGE: Ship 34: $print_name out of allowed range.");
    }

    # Test previously-out-of-range
    foreach my $v (@$values) {
        trace_process("Trying dat+dis value $v");
        my $dir = ct_prepare_game_unpack($setup);
        ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{3}{$field_name} = $v });
        ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{3}{$field_name} = $v });
        ct_run_must_succeed($setup, $dir);
        ct_run_must_fail($setup, $dir, "RANGE: Ship 34: $print_name out of allowed range.", '-p');
    }
}
