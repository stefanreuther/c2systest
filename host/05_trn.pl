#!/usr/bin/perl -w
#
#  Host: test "trn" command
#
use strict;
use c2systest;
use c2service;

my $TRN = file_content(cmdl_input_file('player3.trn'));

test 'host/05_trn/admin', sub {
    # Set up, start and connect
    my $setup = shift;
    my ($hc, $hfc, $dbc, $uid) = prepare($setup);

    # Test: upload a turn file as admin
    assert_throws sub {conn_call($hfc, qw(get games/0001/in/player3.trn))}, 404;  # no turn file present
    my %result = @{ conn_call($hc, 'trn', $TRN) };
    assert_equals $result{status}, 1;
    assert_equals $result{user}, '';
    assert_equals conn_call($hfc, qw(get games/0001/in/player3.trn)), $TRN;       # turn file now present and ok
};

test 'host/05_trn/user', sub {
    # Set up, start and connect
    my $setup = shift;
    my ($hc, $hfc, $dbc, $uid) = prepare($setup);

    # Test: upload a turn file as user
    conn_call($hc, 'user', $uid);
    my %result = @{ conn_call($hc, 'trn', $TRN) };
    assert_equals $result{status}, 1;
    assert_equals $result{user}, $uid;
    assert_equals conn_call($hfc, qw(get games/0001/in/player3.trn)), $TRN;

    # Turn file tracked as user
    my @keys = @{conn_call($dbc, "smembers", "user:$uid:key:all")};
    assert_equals scalar(@keys), 1;
    assert_equals conn_call($dbc, "hget", "user:$uid:key:id:$keys[0]", "lastGame"), 1;
};

test 'host/05_trn/mail', sub {
    # Set up, start and connect
    my $setup = shift;
    my ($hc, $hfc, $dbc, $uid) = prepare($setup);

    # Test: upload a turn file as admin, using email
    my %result = @{ conn_call($hc, 'trn', $TRN, 'mail', 'u@h') };
    assert_equals $result{status}, 1;
    assert_equals $result{user}, $uid;
    assert_equals conn_call($hfc, qw(get games/0001/in/player3.trn)), $TRN;

    # Turn file tracked as user
    my @keys = @{conn_call($dbc, "smembers", "user:$uid:key:all")};
    assert_equals scalar(@keys), 1;
    assert_equals conn_call($dbc, "hget", "user:$uid:key:id:$keys[0]", "lastGame"), 1;
};

test 'host/05_trn/mismatch', sub {
    # Set up, start and connect
    my $setup = shift;
    my ($hc, $hfc, $dbc, $uid) = prepare($setup);

    # Test: upload a turn file as admin, using email
    my %result = @{ conn_call($hc, 'trn', $TRN, 'slot', 7, 'game', 1) };
    assert_equals $result{status}, 4;
    assert_throws sub{conn_call($hfc, qw(get games/0001/in/player3.trn))}, 404;   # no turn uploaded
};

test 'host/05_trn/empty', sub {
    # Set up, start and connect
    my $setup = shift;
    my ($hc, $hfc, $dbc, $uid) = prepare($setup);

    # Test: upload an empty file
    assert_throws sub{conn_call($hc, 'trn', '')}, 422;      # Bad file format
};



sub prepare {
    my $setup = shift;
    my $hs = setup_add_host($setup);
    my $hfs = setup_add_hostfile($setup, 'auto');
    my $dbs = setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);
    my $hc = service_connect($hs);
    my $hfc = service_connect($hfs);
    my $dbc = service_connect($dbs);

    # Prepare
    # - default files
    c2service::setup_db_init($setup);
    my $uid = c2service::setup_db_add_user($setup, 'u', 'email', 'u@h');
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);

    # - host
    c2service::setup_host_add_phost($setup, 'H', setup_get_required_system_config($setup, 'programs').'/phost-4.1h');

    # - default tools
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # Create a game and add a user
    assert_equals conn_call($hc, 'newgame'), 1;

    # Verify filesystem content
    foreach (qw(games/0001 games/0001/backup games/0001/in games/0001/out games/0001/data)) {
        my %stat = @{ conn_call($hfc, 'stat', $_) };
        assert_equals $stat{type}, 'dir';
    }

    # Populate the game
    opendir GAME, "data/game" or die "data/game: $!";
    foreach (readdir(GAME)) {
        conn_call($hfc, 'put', 'games/0001/data/'.$_, file_content('data/game/'.$_))
            unless /^\./;
    }
    closedir GAME;

    # Fix up database
    conn_call($dbc, qw(set game:bytime:06-01-201222:46:01 1));
    conn_call($dbc, qw(set game:1:state running));
    conn_call($dbc, qw(smove game:state:preparing game:state:running 1));
    conn_call($hc, 'playerjoin', 1, 3, $uid);

    return ($hc, $hfc, $dbc, $uid);
}
