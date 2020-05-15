#!/usr/bin/perl -w
#
#  c2check: test TRN errors
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test missing TRN file.
# A: Prepare directory without TRN file.
# E: Check must fail, error must reference missing TRN file.
test 'check/10_trn/missing', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    unlink "$dir/player7.trn";
    ct_run_must_fail($setup, $dir, 'player7.trn', '-r');
};

# Test truncated TRN file.
# A: Prepare directory with empty TRN file.
# E: Check must fail, error must reference truncated TRN file.
test 'check/10_trn/trunc1', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", "");
    ct_run_must_fail($setup, $dir, 'player7.trn', '-r');
};

# Test truncated TRN file.
# A: Prepare directory with truncated TRN file.
# E: Check must fail, error must reference truncated TRN file.
test 'check/10_trn/trunc2', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", substr(file_content("$dir/player7.trn"), 0, 100));
    ct_run_must_fail($setup, $dir, 'player7.trn', '-r');
};

# Test turn file belonging to wrong player.
# A: Prepare directory with bad TRN file.
# E: Check must fail, with specific error message.
test 'check/10_trn/player', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(9, "07-09-201712:00:03"));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn belongs to player 9, not 7', '-r');
};

# Test turn file belonging to wrong timestamp.
# A: Prepare directory with bad TRN file.
# E: Check must fail, with specific error message.
test 'check/10_trn/player', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-10-201712:00:03"));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn does not belong to same turn as result file', '-r');
};

# Test turn file with unknown command.
# A: Prepare turn file with unknown command.
# E: Check succeeds with warning.
# FIXME: should this fail?
test 'check/10_trn/cmd/0', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 0, 1, 2)));
    ct_run_must_succeed_with_message($setup, $dir, 'WARNING: unknown command with code 0.', '-r');
};
test 'check/10_trn/cmd/1000', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 1000, 1, 2)));
    ct_run_must_succeed_with_message($setup, $dir, 'WARNING: unknown command with code 1000.', '-r');
};

# Test turn file with command referring to an invalid ship.
# A: Prepare turn with ShipChangeMission command (4) on an invalid ship.
# E: Check must fail, with specific error message.
test 'check/10_trn/ship/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 4, 1000, 3)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn contains invalid ship Id 1000', '-r');
};

# Test turn file with command referring to an invalid ship.
# A: Prepare turn with ShipChangeMission command (4) on a missing ship.
# E: Check must fail, with specific error message.
test 'check/10_trn/ship/unknown', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 4, 12, 3)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn refers to ship 12 which is not ours', '-r');
};

# Test turn file with command referring to an invalid planet.
# A: Prepare turn with PlanetColonistTax command (32) on invalid planet.
# E: Check must fail, with specific error message.
test 'check/10_trn/planet/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 32, 501, 3)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn contains invalid planet Id 501', '-r');
};

# Test turn file with command referring to an invalid planet.
# A: Prepare turn with PlanetColonistTax command (32) on missing planet.
# E: Check must fail, with specific error message.
test 'check/10_trn/planet/unknown', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 32, 12, 13)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn refers to planet 12 which is not ours', '-r');
};

# Test turn file with command referring to an invalid base.
# A: Prepare turn with BaseChangeMission command (52) on invalid base.
# E: Check must fail, with specific error message.
test 'check/10_trn/base/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 52, 501, 3)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn contains invalid base Id 501', '-r');
};

# Test turn file with command referring to an invalid base.
# A: Prepare turn with BaseChangeMission command (52) on missing base.
# E: Check must fail, with specific error message.
test 'check/10_trn/base/unknown', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_rst($setup);
    file_put("$dir/player7.trn", c2service::vp_make_turn(7, "07-09-201712:00:03", pack("v*", 52, 12, 2)));
    ct_run_must_fail($setup, $dir, 'SYNTAX: player7.trn refers to base 12 which is not ours', '-r');
};
