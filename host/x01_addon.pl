#!/usr/bin/perl -w
#
#  Host: test add-on integration
#
#  These tests set up a server instance populated with the pcc-programs structure
#  and check some basic properties of add-on integration.
#
use strict;
use c2systest;
use POSIX(qw(getcwd));
use Time::HiRes('sleep');

# Test Starbase Reloaded integration
# A: create a game with Starbase Reloaded. Host it.
# E: playerfiles must include psbplus config file
test 'host/x01_addon/sbreload', sub {
    test_sbreload(shift, 'sbreload');
};
test 'host/x01_addon/sbreload-0.42', sub {
    test_sbreload(shift, 'sbreload');
};

sub test_sbreload {
    my $setup = setup(shift);
    my $tool_id = shift;

    # Create game
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gameaddtool', $gid, $tool_id);
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'running');

    # Master it
    wait_for_turn($hc, $gid, 1);

    # Check playerfiles
    my $config = conn_call($hc, 'get', "game/$gid/psbplus.src");
    assert_contains $config, "TransportComp";
};


# Test ExploreMap integration
# A: create a game with ExploreMap. Host it.
# E: playerfiles must include xyplanN.dat file, but no xyplan.dat.
test 'host/x01_addon/explmap', sub {
    my $setup = setup(shift);

    # Create game
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gameaddtool', $gid, 'explmap-2.5');
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'running');

    # Master it
    wait_for_turn($hc, $gid, 1);

    # Check playerfiles
    assert_differs conn_call($hc, 'get', "game/$gid/3/xyplan3.dat"), '';
    assert_throws sub{ conn_call($hc, 'get', "game/$gid/xyplan.dat"); };

    my $config = conn_call($hc, 'get', "game/$gid/map.ini");
    $config =~ s/\s+//g;
    assert_contains $config, "Explore=Yes";
};


sub setup {
    my $setup = shift;
    my $console_tool = setup_get_required_system_config($setup, 'c2console.path');
    my $prog_path = setup_get_required_system_config($setup, 'programs');
    my $root_dir = setup_get_required_system_config($setup, 'c2ng');
    if ($console_tool !~ m|^/|) {
        $console_tool = POSIX::getcwd() . '/' . $console_tool;
    }

    # Pre-verify
    assert -f "$root_dir/../share/server/scripts/init.con";
    assert -f "$prog_path/install.con";

    # Start it
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Installation routine
    assert_execution_succeeds "cd $root_dir/../share/server/scripts && $console_tool load init.con";
    assert_execution_succeeds "cd $prog_path && $console_tool load install.con";

    $setup;
}


sub wait_for_turn {
    my $hc = shift;
    my $gid = shift;
    my $turn = shift;
    my $loops = 0;

    while (conn_call($hc, 'gameget', $gid, 'turn') ne $turn) {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}
