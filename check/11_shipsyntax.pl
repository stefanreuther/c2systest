#!/usr/bin/perl -w
#
#  c2check: errors loading ship files
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test missing file.
# A: remove file
# E: error result
test 'check/11_shipsyntax/missing/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/ship7.dat";
    ct_run_must_fail($setup, $dir, 'ship7.dat');
};
test 'check/11_shipsyntax/missing/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/ship7.dis";
    ct_run_must_fail($setup, $dir, 'ship7.dis');
};

# Test empty file (truncated counter)
# A: truncate file
# E: error result
test 'check/11_shipsyntax/trunc/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/ship7.dat", "");
    ct_run_must_fail($setup, $dir, 'ship7.dat');
};
test 'check/11_shipsyntax/trunc/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/ship7.dis", "");
    ct_run_must_fail($setup, $dir, 'ship7.dis');
};

# Test different counter. The counter in both files must agree.
# A: modify file
# E: error result
test 'check/11_shipsyntax/count/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{count}++ });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat and ship7.dis do not match (count)');
};

# Test large counter.
# A: modify file with out-of-range counter
# E: error result
test 'check/11_shipsyntax/count/large', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{count} = 1000 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{count} = 1000 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat has too large counter and is probably invalid.');
};
test 'check/11_shipsyntax/count/negative', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_planet_spec(), sub { shift->{count} = -1 });
    ct_edit_file("$dir/ship7.dis", ct_planet_spec(), sub { shift->{count} = -1 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat has too large counter and is probably invalid.');
};

# Test truncated object.
# A: truncate file at an object
# E: error result
test 'check/11_shipsyntax/trunc/datobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/ship7.dat", substr(file_content("$dir/ship7.dat"), 0, 300));
    ct_run_must_fail($setup, $dir, 'ship7.dat');
};
test 'check/11_shipsyntax/trunc/disobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/ship7.dis", substr(file_content("$dir/ship7.dis"), 0, 300));
    ct_run_must_fail($setup, $dir, 'ship7.dis');
};

# Test differing IDs
# A: modify file
# E: error result
test 'check/11_shipsyntax/id/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{id} = 333 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat and ship7.dis do not match (ship Id).');
};

# Test bad IDs
# A: modify file
# E: error result
test 'check/11_shipsyntax/id/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{id} = 1000 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{id} = 1000 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat contains invalid ship Id 1000.');
};

# Test duplicate IDs
# A: modify file
# E: error result
test 'check/11_shipsyntax/id/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{1}{id} = 18 });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{1}{id} = 18 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: ship7.dat contains duplicate ship Id 18.');
};

# Test missing signatures
# A: modify file
# E: success (with warning if '-c' is used)
test 'check/11_shipsyntax/sig/none', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{rest} = '' });
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{rest} = '' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: ship7.dat/.dis do not have a signature block.', '-c');
};

# Test short signatures
# A: remove signature from dat or dis
# E: success (with warning if '-c' is used)
test 'check/11_shipsyntax/sig/1dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{rest} = 'x' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: ship7.dat signature is only 1 bytes, expecting 10.', '-c');
};
test 'check/11_shipsyntax/sig/1dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{rest} = 'xy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: ship7.dis signature is only 2 bytes, expecting 10.', '-c');
};

# Test wrong signatures
# A: modify signature
# E: success (with warning if '-c' is used)
test 'check/11_shipsyntax/sig/wrongdat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dat", ct_ship_spec(), sub { shift->{rest} = 'yyyyyyyyyy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: ship7.dat signature is invalid.', '-c');
};
test 'check/11_shipsyntax/sig/wrongdis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/ship7.dis", ct_ship_spec(), sub { shift->{rest} = 'xxxxxxxxxx' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: ship7.dis signature is invalid.', '-c');
};

# Counter-test: no error (although "shipsyntax", this also checks base/planet)
# A: do not modify files
# E: success (with no warning)
test 'check/11_shipsyntax/sig/ok', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    my $result = ct_run_must_succeed($setup, $dir, '-c');
    assert $result !~ /CHECKSUM:/;
    assert $result !~ /SYNTAX:/;
};
