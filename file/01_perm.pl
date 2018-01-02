#!/usr/bin/perl -w
#
#  File: permission-related tests
#
use strict;
use c2systest;

# Basic test: create a directory as user a, and access files as user b.
# Ownership must prevent b from access.
test 'file/01_perm/base', sub {
    # Setup
    my $setup = shift;
    setup_add_userfile($setup);
    setup_start_wait($setup);
    my $fc = setup_connect_app($setup, 'file');

    # Create a directory as user 'a'
    conn_call($fc, qw(mkdiras base a));

    # Change to user 'a'; access directory
    conn_call($fc, qw(user a));
    conn_call($fc, qw(put base/a t));
    assert_equals conn_call($fc, qw(get base/a)), "t";

    # Change to user 'b'; try to access
    conn_call($fc, qw(user b));
    assert_throws sub{conn_call($fc, qw(put base/b t))}, 403;
    assert_throws sub{conn_call($fc, qw(get base/b))}, 403;
    assert_throws sub{conn_call($fc, qw(get base/a))}, 403;
};

# Test mkdirhier.
# Ownership must prevent b from access.
test 'file/01_perm/mkdirhier', sub {
    # Setup
    my $setup = shift;
    setup_add_userfile($setup);
    setup_start_wait($setup);
    my $fc = setup_connect_app($setup, 'file');
    my $fcadm = setup_connect_app($setup, 'file');

    # Create a directory as user 'a'
    conn_call($fcadm, qw(mkdiras base a));

    # Change to user 'b'; try to access
    conn_call($fc, qw(user b));
    assert_throws sub{conn_call($fc, qw(mkdirhier base/x/y/z))}, 403;

    # Verify
    assert_throws sub{conn_call($fcadm, qw(stat base/x/y/z))}, 404;
};

