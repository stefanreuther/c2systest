#!/usr/bin/perl -w
#
#  Performance test: get, ls
#

use strict;
use c2systest;

test 'file/p01_get', sub {
    # Setup.
    # Use an existing directory (not an internal one) to allow comparisons against c2file-classic.
    my $setup = shift;
    my $file = setup_add_userfile($setup, 'auto');
    setup_start_wait($setup);

    # Upload some files
    my $fc = service_connect($file);
    conn_call($fc, qw(mkdir t));
    foreach (1 .. 30) {
        conn_call($fc, 'put', 't/file'.$_, 'content'.$_);
    }
    foreach (1 .. 10) {
        conn_call($fc, 'mkdir', 't/subdir'.$_);
    }

    # Test
    conn_call($fc, qw(ls t));
    conn_call($fc, qw(get t/file7));

    test_timing 'file ls', sub {
        conn_call($fc, qw(ls t));
    };
    test_timing 'file get', sub {
        conn_call($fc, qw(get t/file7));
    };
};
