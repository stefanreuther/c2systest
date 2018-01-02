#!/usr/bin/perl -w
#
#  Router: test file server notification
#
#  The point of this test is to test the router <=> filer coupling,
#  especially when different generations are talking together.
#
#  One possible troubling point is that c2router-classic expects only a single-line reply
#  from the filer, whereas c2file-ng will always send bulk replies.
#  It happens to work anyway but causes c2router-classic to print a warning on each notification.
#  "Work" here means: the update to the filespace (created by c2router/c2server) is visible on the filer.
#
use strict;
use c2systest;

test 'router/01_notify', sub {
    my $setup = shift;

    # Add router
    my $rs = setup_add_app($setup, 'router', 'c2router');
    service_set_pingable($rs, 0);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));

    # Add user filer
    my $ufroot = setup_get_tmpfile_name($setup, 'ufroot');
    mkdir $ufroot, 0777 or die;
    my $ufs = setup_add_userfile($setup, $ufroot);

    # Start
    setup_start($setup);

    # Upload results to filer
    my $rst = file_content('data/game/player3.rst');
    my $ufc = service_connect_wait($ufs);
    foreach (qw(a b)) {
        conn_call($ufc, 'mkdir', $_);
        conn_call($ufc, 'put', "$_/player3.rst", $rst);
    }

    # Open a session
    my $session1 = parse_session(service_call_raw($rs, "NEW -WDIR=a $ufroot/a 3\n"));
    my $session2 = parse_session(service_call_raw($rs, "NEW -WDIR=b $ufroot/b 3\n"));

    # Close sessions
    service_call_raw($rs, "CLOSE $session1\n");
    service_call_raw($rs, "CLOSE $session2\n");

    # Turn files must be in filespace and filer
    foreach (qw(a b)) {
        assert -f "$ufroot/$_/player3.trn";
        conn_call($ufc, 'get', "$_/player3.trn");
    }
};


sub parse_session {
    my $x = shift;
    assert $x =~ /^201 (\d+) /;
    $1;
}
