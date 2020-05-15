#!/usr/bin/perl -w
#
#  c2check: xyplan checks
#

use strict;
use c2systest;
use c2service;

do 'check/common.pi';

# Test missing xyplan file
# A: remove file
# E: error result
test 'check/07_xyplan/missing', sub {
    my $setup = shift;
    ct_test_missing_file($setup, 'xyplan.dat');
};

# Test truncated xyplan file.
# A: truncate file
# E: error result
test 'check/07_xyplan/trunc', sub {
    my $setup = shift;
    ct_test_truncated_file($setup, 'xyplan.dat', 155);
};
