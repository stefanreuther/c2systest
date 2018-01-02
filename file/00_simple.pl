#!/usr/bin/perl -w
#
#  File: simple test
#
use strict;
use c2systest;

test 'file/00_simple', sub {
    # Setup
    my $setup = shift;
    my $dir = setup_get_tmpfile_name($setup, 'f');
    my $fs = setup_add_app($setup, 'file', 'c2file');
    setup_add_service_config($setup, 'file.basedir', $dir);
    mkdir $dir, 0777 or die "$dir: $!";

    # Start
    setup_start($setup);

    # Operate
    # This is TestServerFileFileBase::testSimple
    my $fc = service_connect_wait($fs);
    conn_call($fc, 'mkdir', 'd');
    conn_call($fc, 'mkdir', 'd/sd');
    conn_call($fc, 'put', 'd/f', 'content...');
    assert_equals(conn_call($fc, 'get', 'd/f'), 'content...');

    my %fi = @{ conn_call($fc, 'stat', 'd') };
    assert_equals($fi{type}, 'dir');

    %fi = @{ conn_call($fc, 'stat', 'd/f') };
    assert_equals($fi{type}, 'file');
    assert_equals($fi{size}, 10);

    assert_throws sub{ conn_call($fc, 'mkdir', 'd') },        409;
    assert_throws sub{ conn_call($fc, 'mkdir', 'd/f') },      409;
    assert_throws sub{ conn_call($fc, 'put', 'd/sd', 'xx') }, qr{409|450};  # ng reports 409, classic reports 450
};
