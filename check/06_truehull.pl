#!/usr/bin/perl -w
#
#  c2check: truehull checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

my $desc = {
    fields => [1 .. 20],
    pattern => 'v20',
    mode => 'auto'
};

# Test missing truehull.
# A: remove file
# E: error result
test 'check/06_truehull/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'truehull.dat');
};

# Test truncated truehull.
# A: truncate file
# E: error result
test 'check/06_truehull/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'truehull.dat', 300);
};

# Test out of range indexes.
# A: prepare out-of-range values
# E: error result for most; success result for -1/"-z" case
test 'check/06_truehull/range', sub {
    my $setup = shift;
    ct_test_edited_spec_file($setup, 'truehull.dat', $desc, 'RANGE: Truehull player 2: Slot 1 out of allowed range',   sub { shift->{2}{1} = -1; });
    ct_test_edited_spec_file($setup, 'truehull.dat', $desc, 'RANGE: Truehull player 1: Slot 20 out of allowed range',  sub { shift->{1}{20} = 106; });
    ct_test_edited_spec_file($setup, 'truehull.dat', $desc, 'RANGE: Truehull player 11: Slot 1 out of allowed range',  sub { shift->{11}{1} = 9999; });
    ct_test_edited_spec_file_m1($setup, 'truehull.dat', $desc, sub { shift->{2}{1} = -1; });
};
