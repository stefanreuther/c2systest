#!/usr/bin/perl -w
#
#  Host: test restart behaviour
#
#  If a dependent service restarts, we must transparently reconnect.
#
use strict;
use c2systest;
use c2service;

# Restart talk
test 'host/16_restart/talk', sub {
    my $setup = shift;
    do_test($setup, 1, 0);
};

# Restart file
test 'host/16_restart/file', sub {
    my $setup = shift;
    do_test($setup, 0, 1);
};

# Restart talk and file
test 'host/16_restart/both', sub {
    my $setup = shift;
    do_test($setup, 1, 1);
};


sub do_test {
    my ($setup, $test_talk, $test_hostfile) = @_;
    setup_add_db($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');       # must use 'auto' to make it persistent
    setup_add_userfile($setup);
    my $ts = setup_add_talk($setup);
    setup_add_mailout($setup);
    my $hs = setup_add_host($setup);
    setup_start_wait($setup);
    c2service::setup_hostfile_add_defaults($setup);

    # Create a game. This will use hostfile, talk, db.
    my $hc = service_connect_wait($hs);
    assert_equals conn_call($hc, qw(newgame)), 1;
    conn_call($hc, qw(gamesettype 1 public));
    conn_call($hc, qw(gamesetstate 1 joining));

    # Stop dependent services (cannot stop database; we want to preserve state)
    service_stop($hfs)   if $test_hostfile;
    service_stop($ts)    if $test_talk;

    # Restart
    service_start($hfs)  if $test_hostfile;
    service_start($ts)   if $test_talk;

    # Create another gaem
    assert_equals conn_call($hc, qw(newgame)), 2;
};
