#!/usr/bin/perl -w
#
#  Host: test game/tool management commands
#

use strict;
use c2systest;
use c2service;

# Initial test, also tests gameaddtool
test 'host/11_gametool/add', sub {
    my $setup = shift;
    prepare($setup);

    # Define some tools
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd',     'H', '', '', 'htype');
    conn_call($hc, 'masteradd',   'M', '', '', 'mtype');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'stype');
    conn_call($hc, 'tooladd',     'T', '', '', 'ttype');

    # Create a game
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    assert_equals conn_call($hc, 'gameget', $gid, 'host'),     'H';
    assert_equals conn_call($hc, 'gameget', $gid, 'master'),   'M';
    assert_equals conn_call($hc, 'gameget', $gid, 'shiplist'), 'S';
    my @t = @{ conn_call($hc, 'gamelstools', $gid) };
    assert_equals scalar(@t), 0;

    # Verify database
    my $dbc = setup_connect_app($setup, 'db');
    assert_equals conn_call($dbc, qw(hget game:1:settings host)),     'H';
    assert_equals conn_call($dbc, qw(hget game:1:settings master)),   'M';
    assert_equals conn_call($dbc, qw(hget game:1:settings shiplist)), 'S';

    # Add a tool
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T'), 1;
    @t = @{ conn_call($hc, 'gamelstools', $gid) };
    assert_equals scalar(@t), 1;
    my %tool = @{$t[0]};
    assert_equals $tool{id}, 'T';

    assert_equals conn_call($dbc, qw(scard game:1:tools)), 1;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T)), 1;

    # Add again
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T'), 0;
    assert_equals conn_call($dbc, qw(scard game:1:tools)), 1;
};

# Test gamermtool
test 'host/11_gametool/rm', sub {
    my $setup = shift;
    prepare($setup);

    # Define some tools
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($hc, 'hostadd',     'H', '', '', 'htype');
    conn_call($hc, 'masteradd',   'M', '', '', 'mtype');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'stype');
    conn_call($hc, 'tooladd',     'T', '', '', 'ttype');

    # Create a game and add a tool
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T'), 1;
    assert_equals conn_call($dbc, qw(scard game:1:tools)), 1;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T)), 1;

    # Remove the tool
    assert_equals conn_call($hc, 'gamermtool', $gid, 'T'), 1;
    assert_equals conn_call($dbc, qw(scard game:1:tools)), 0;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T)), 0;

    # Remove again
    assert_equals conn_call($hc, 'gamermtool', $gid, 'T'), 0;
};

# Test multiple tools and implicit replacement
test 'host/11_gametool/multi', sub {
    my $setup = shift;
    prepare($setup);

    # Define some tools
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($hc, 'hostadd',     'H',   '', '', 'htype');
    conn_call($hc, 'masteradd',   'M',   '', '', 'mtype');
    conn_call($hc, 'shiplistadd', 'S',   '', '', 'stype');
    conn_call($hc, 'tooladd',     'T1a', '', '', 't1');
    conn_call($hc, 'tooladd',     'T1b', '', '', 't1');
    conn_call($hc, 'tooladd',     'T2',  '', '', 't2');

    # Create a game and add two tools
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T1a'), 1;
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T2'),  1;
    assert_equals conn_call($dbc, qw(scard game:1:tools)), 2;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T1a)), 1;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T2)),  1;

    # Add T1b. This removes T1a.
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'T1b'), 1;
    assert_equals conn_call($dbc, qw(scard game:1:tools)), 2;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T1b)), 1;
    assert_equals conn_call($dbc, qw(sismember game:1:tools T2)),  1;
};

# Test referee tool. This affects the gamegetvc command.
test 'host/11_gametool/ref', sub {
    my $setup = shift;
    prepare($setup);

    # Define some tools
    my $hc = setup_connect_app($setup, 'host');
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($hc, 'hostadd',     'H', '', '', 'htype');
    conn_call($hc, 'masteradd',   'M', '', '', 'mtype');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'stype');
    conn_call($hc, 'tooladd',     'R', '', '', 'referee');
    conn_call($hc, 'toolset', 'R', 'description', 'Cool Referee');

    # Create a game and add two tools
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 1;
    assert_equals conn_call($hc, 'gameaddtool', $gid, 'R'), 1;

    my %vc = @{ conn_call($hc, 'gamegetvc', $gid) };

    assert_equals $vc{referee}, 'R';
    assert_equals $vc{refereeDescription}, 'Cool Referee';
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
    c2service::setup_hostfile_add_defaults($setup);
}
