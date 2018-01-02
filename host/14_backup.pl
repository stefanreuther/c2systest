#!/usr/bin/perl -w
#
#  Host: test backups invocation
#
#  The setup is based on 06_master.
#  host/14_backup/unpack fails on c2host-classic.
#
use strict;
use c2systest;
use c2service;
use Time::HiRes('sleep');

# Test default config. This will save *.tar.gz files.
test 'host/14_backup/default', sub {
    my $setup = shift;
    prepare($setup);

    # Verify presence of backup files
    my $hfc = setup_connect_app($setup, 'hostfile');
    my %files = conn_call_list($hfc, qw(ls games/0001/backup));
    assert_set_equals [keys %files], ['post-001.tgz', 'pre-001.tgz', 'premaster.tgz', 'trn-001.tgz'];
};

# Test configuration "unpack".
test 'host/14_backup/unpack', sub {
    my $setup = shift;
    setup_add_service_config($setup, "host.backups", "unpack");
    prepare($setup);

    # Verify presence of backup files: post-001, pre-001, premaster must contain spec files, identical in each, and identical to game data
    my $hfc = setup_connect_app($setup, 'hostfile');
    foreach (qw(storm.nm race.nm engspec.dat truehull.dat)) {
        my $a = conn_call($hfc, 'get', "games/0001/data/$_");
        assert_equals $a, conn_call($hfc, 'get', "games/0001/backup/premaster/$_");
        assert_equals $a, conn_call($hfc, 'get', "games/0001/backup/pre-001/$_");
        assert_equals $a, conn_call($hfc, 'get', "games/0001/backup/post-001/$_");
    }

    # Turn file backup is empty
    assert !conn_call_list($hfc, 'ls', 'games/0001/backup/trn-001');
};

sub prepare {
    # Set up, start and connect
    my $setup = shift;
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Prepare files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Add and start a game
    my $hc = setup_connect_app($setup, 'host');
    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 running));

    # Wait until master completed (at most 10 seconds; typical <3 seconds, of which 2 are a tactical sleep)
    my $loops = 0;
    while (conn_call($hc, qw(gameget 1 turn)) eq '') {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}
