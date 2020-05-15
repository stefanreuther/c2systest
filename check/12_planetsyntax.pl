#!/usr/bin/perl -w
#
#  c2check: errors loading planet (pdata) files
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

## Test missing file
# A: remove file
# E: error result
test 'check/12_planetsyntax/missing/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/pdata7.dat";
    ct_run_must_fail($setup, $dir, 'pdata7.dat');
};
test 'check/12_planetsyntax/missing/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/pdata7.dis";
    ct_run_must_fail($setup, $dir, 'pdata7.dis');
};

# Test empty file (truncated counter)
# A: truncate file
# E: error result
test 'check/12_planetsyntax/trunc/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/pdata7.dat", "");
    ct_run_must_fail($setup, $dir, 'pdata7.dat');
};
test 'check/12_planetsyntax/trunc/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/pdata7.dis", "");
    ct_run_must_fail($setup, $dir, 'pdata7.dis');
};

# Test different counter. The counter in both files must agree.
# A: modify file
# E: error result
test 'check/12_planetsyntax/count/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{count}++ });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat and pdata7.dis do not match (count)');
};

# Test large counter.
# A: modify file with out-of-range counter
# E: error result
test 'check/12_planetsyntax/count/large', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{count} = 501 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{count} = 501 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat has too large counter and is probably invalid.');
};
test 'check/12_planetsyntax/count/negative', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{count} = -1 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{count} = -1 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat has too large counter and is probably invalid.');
};

# Test truncated object.
# A: truncate file at an object
# E: error result
test 'check/12_planetsyntax/trunc/datobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/pdata7.dat", substr(file_content("$dir/pdata7.dat"), 0, 300));
    ct_run_must_fail($setup, $dir, 'pdata7.dat');
};
test 'check/12_planetsyntax/trunc/disobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/pdata7.dis", substr(file_content("$dir/pdata7.dis"), 0, 300));
    ct_run_must_fail($setup, $dir, 'pdata7.dis');
};

# Test differing IDs
# A: modify file
# E: error result
test 'check/12_planetsyntax/id/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{id} = 333 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat and pdata7.dis do not match (planet Id).');
};

# Test bad IDs
# A: modify file
# E: error result
test 'check/12_planetsyntax/id/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{id} = 501 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{id} = 501 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat contains invalid planet Id 501.');
};

# Test duplicate IDs
# A: modify file
# E: error result
test 'check/12_planetsyntax/id/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{1}{id} = 14 });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{1}{id} = 14 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: pdata7.dat contains duplicate planet Id 14.');
};

# Test missing signatures
# A: modify file
# E: success (with warning if '-c' is used)
test 'check/12_planetsyntax/sig/none', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{rest} = '' });
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{rest} = '' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: pdata7.dat/.dis do not have a signature block.', '-c');
};

# Test short signatures
# A: remove signature from dat or dis
# E: success (with warning if '-c' is used)
test 'check/12_planetsyntax/sig/1dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{rest} = 'x' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: pdata7.dat signature is only 1 bytes, expecting 10.', '-c');
};
test 'check/12_planetsyntax/sig/1dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{rest} = 'xy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: pdata7.dis signature is only 2 bytes, expecting 10.', '-c');
};

# Test wrong signatures
# A: modify signature
# E: success (with warning if '-c' is used)
test 'check/12_planetsyntax/sig/wrongdat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dat", ct_planet_spec(), sub { shift->{rest} = 'yyyyyyyyyy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: pdata7.dat signature is invalid.', '-c');
};
test 'check/12_planetsyntax/sig/wrongdis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/pdata7.dis", ct_planet_spec(), sub { shift->{rest} = 'xxxxxxxxxx' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: pdata7.dis signature is invalid.', '-c');
};
