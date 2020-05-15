#!/usr/bin/perl -w
#
#  c2check: errors loading base (bdata) files
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

## Test missing file
# A: remove file
# E: error result
test 'check/12_basesyntax/missing/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/bdata7.dat";
    ct_run_must_fail($setup, $dir, 'bdata7.dat');
};
test 'check/12_basesyntax/missing/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    unlink "$dir/bdata7.dis";
    ct_run_must_fail($setup, $dir, 'bdata7.dis');
};

# Test empty file (truncated counter)
# A: truncate file
# E: error result
test 'check/12_basesyntax/trunc/dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/bdata7.dat", "");
    ct_run_must_fail($setup, $dir, 'bdata7.dat');
};
test 'check/12_basesyntax/trunc/dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/bdata7.dis", "");
    ct_run_must_fail($setup, $dir, 'bdata7.dis');
};

# Test different counter. The counter in both files must agree.
# A: modify file
# E: error result
test 'check/12_basesyntax/count/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{count}++ });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat and bdata7.dis do not match (count)');
};

# Test large counter.
# A: modify file with out-of-range counter
# E: error result
test 'check/12_basesyntax/count/large', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{count} = 501 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{count} = 501 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat has too large counter and is probably invalid.');
};
test 'check/12_basesyntax/count/negative', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{count} = -1 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{count} = -1 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat has too large counter and is probably invalid.');
};

# Test truncated object.
# A: truncate file at an object
# E: error result
test 'check/12_basesyntax/trunc/datobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/bdata7.dat", substr(file_content("$dir/bdata7.dat"), 0, 300));
    ct_run_must_fail($setup, $dir, 'bdata7.dat');
};
test 'check/12_basesyntax/trunc/disobj', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    file_put("$dir/bdata7.dis", substr(file_content("$dir/bdata7.dis"), 0, 300));
    ct_run_must_fail($setup, $dir, 'bdata7.dis');
};

# Test differing IDs
# A: modify file
# E: error result
test 'check/12_basesyntax/id/differs', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{id} = 333 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat and bdata7.dis do not match (base Id).');
};

# Test bad IDs
# A: modify file
# E: error result
test 'check/12_basesyntax/id/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{id} = 501 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{id} = 501 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat contains invalid planet Id 501.');
};

# Test foreign ID (=base not at planet)
# A: modify file
# E: error result
test 'check/12_basesyntax/id/bad', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{id} = 77 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{id} = 77 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat contains base at foreign planet Id 77.');
};

# Test duplicate IDs
# A: modify file
# E: error result
test 'check/12_basesyntax/id/dup', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{1}{id} = 140 });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{1}{id} = 140 });
    ct_run_must_fail($setup, $dir, 'SYNTAX: bdata7.dat contains duplicate planet Id 140.');
};

# Test missing signatures
# A: modify file
# E: success (with warning if '-c' is used)
test 'check/12_basesyntax/sig/none', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{rest} = '' });
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{rest} = '' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: bdata7.dat/.dis do not have a signature block.', '-c');
};

# Test short signatures
# A: remove signature from dat or dis
# E: success (with warning if '-c' is used)
test 'check/12_basesyntax/sig/1dat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{rest} = 'x' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: bdata7.dat signature is only 1 bytes, expecting 10.', '-c');
};
test 'check/12_basesyntax/sig/1dis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{rest} = 'xy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: bdata7.dis signature is only 2 bytes, expecting 10.', '-c');
};

# Test wrong signatures
# A: modify signature
# E: success (with warning if '-c' is used)
test 'check/12_basesyntax/sig/wrongdat', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dat", ct_base_spec(), sub { shift->{rest} = 'yyyyyyyyyy' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: bdata7.dat signature is invalid.', '-c');
};
test 'check/12_basesyntax/sig/wrongdis', sub {
    my $setup = shift;
    my $dir = ct_prepare_game_unpack($setup);
    ct_edit_file("$dir/bdata7.dis", ct_base_spec(), sub { shift->{rest} = 'xxxxxxxxxx' });
    ct_run_must_succeed($setup, $dir);
    ct_run_must_succeed_with_message($setup, $dir, 'CHECKSUM: bdata7.dis signature is invalid.', '-c');
};
