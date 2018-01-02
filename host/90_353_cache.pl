#!/usr/bin/perl -w
#
#  Host: cache invalidation after turn upload [#353]
#
#  This is a bug in c2host-classic that cannot appear (by construction) in c2host-ng.
#
use strict;
use c2systest;
use c2service;

my $SLOT_NR = 3;
my $TIMESTAMP = "22-11-199911:22:33";


test 'host/90_353_cache', sub {
    my $setup = shift;
    prepare($setup);

    # Upload a turn file
    my $trn = c2service::vp_make_turn($SLOT_NR, $TIMESTAMP);
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'trn', $trn, 'game', 1);

    # Verify presence of file
    my $hfc = setup_connect_app($setup, 'hostfile');
    assert_equals conn_call($hfc, "get", "games/0001/in/player$SLOT_NR.trn"), $trn;

    # "new" folder must be empty
    assert !conn_call_list($hfc, "ls", "games/0001/in/new");

    # "in" folder must not be empty
    assert  conn_call_list($hfc, "ls", "games/0001/in");
};

sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup, '-nocron');
    my $hfs = setup_add_hostfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $hfc = service_connect($hfs);

    # Prepare
    my $uid = c2service::setup_db_add_user($setup, 'u', 'email', 'u@h');

    conn_call($hfc, qw(mkdirhier games));
    conn_call($hfc, qw(mkdirhier bin));
    conn_call($hfc, qw(mkdirhier defaults));
    conn_call($hfc, qw(put bin/checkturn.sh), 'mv "$1/in/new/player$2.trn" "$1/in/player$2.trn"');

    # Create a game and add a user
    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, 'gamesetstate', 1, 'running');
    conn_call($hc, 'playerjoin', 1, $SLOT_NR, $uid);
}
