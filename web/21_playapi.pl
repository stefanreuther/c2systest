#
#  Test api/play.cgi: Host integration test
#
use strict;
use c2systest;
use c2service;
use c2cgitest;

# Check integration of api/play.cgi with host infrastructure.
# Create a live game and a user.
# Subscribe the user to the game and configure for online play.
# Verify that we can open the game for playing.
# Verify that closing the session results in a turn file being uploaded to host.
test 'web/21_playapi', sub {
    my $setup = shift;
    prepare($setup);

    # Start the game
    my $hc  = setup_connect_app($setup, 'host');
    my $trn = conn_call($hc, qw(gameget 1 turn));
    conn_call($hc, qw(gameset 1 hostRunNow 1));
    wait_for_game($hc, 1, $trn);

    # Add a user and join them
    my $cookie = create_user($setup, 'uu');
    setup_post_api($setup, "api/host.cgi", $cookie, action => 'playerjoin', gid => 1, slot => 3);

    # Configure online play
    setup_post_api($setup, "api/host.cgi", $cookie, action => 'playersetdir', gid => 1, dir => 'u/uu/games/one');

    # Add registration key
    conn_call(setup_connect_app($setup, 'file'), 'put', 'u/uu/games/one/fizz.bin',
              file_content(c2service::setup_get_init_scripts($setup)."/r/unreg/fizz.bin"));

    # Create session
    my $new_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'new', dir => 'u/uu/games/one', player => 3);
    assert $new_result->{sid};

    # Obtain data
    my $data_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'get', sid => $new_result->{sid}, path => 'obj/main,planet433');
    assert_equals $data_result->{data}{main}{'MY.RACE'}, 3;
    assert_equals $data_result->{data}{main}{'TURN'}, 132;
    assert_equals $data_result->{data}{planet433}{'FCODE'}, '779';

    # Give a command
    $data_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'post', sid => $new_result->{sid}, path => 'obj/planet433', data => '[["setfcode","xyz"]]');
    assert_equals $data_result->{data}{planet433}{'FCODE'}, 'xyz';

    # Close session
    my $close_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'close', sid => $new_result->{sid});
    assert_equals $close_result->{result}, 1;          # API confirmation
    assert_equals $close_result->{status}, 1;          # turn status
    assert_equals $close_result->{name}, "MyGame";
    assert_contains $close_result->{output}, 'No errors found';

    # Verify that turn file is present
    my $user_turn = conn_call(setup_connect_app($setup, 'file'),     'get', 'u/uu/games/one/player3.trn');
    my $host_turn = conn_call(setup_connect_app($setup, 'hostfile'), 'get', 'games/0001/in/player3.trn');
    assert_equals $user_turn, $host_turn;
    assert_contains $user_turn, 'xyz';
};


################################ Utilities ################################


sub prepare {
    my $setup = shift;

    # Add router first. The framewirk will stop services in the same order as they are added.
    # A stopping router will try to notify the file server; if that one's already gone, it will wait for timeout.
    setup_add_router($setup);
    setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_usermgr($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup,
                             'router.server' => setup_get_required_system_config($setup, 'c2server.path'),
                             'router.sessionid' => 'random',
                             @_);
    setup_start_wait($setup);

    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    my $dbc = setup_connect_app($setup, 'db');

    # Prepare
    # - default files
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);
    c2service::setup_host_add_phost($setup, 'H', "$prog/phost-4.1h");
    c2service::setup_host_add_amaster($setup, 'M', "$prog/amaster-310g/unix/src");
    c2service::setup_host_add_shiplist($setup, 'S', "$prog/plist-3.2", 'plist');

    # Create a game
    assert_equals conn_call($hc, 'newgame'), 1;
    opendir GAME, "data/game" or die "data/game: $!";
    foreach (readdir(GAME)) {
        conn_call($hfc, 'put', 'games/0001/data/'.$_, file_content('data/game/'.$_))
            unless /^\./;
    }
    closedir GAME;

    # Fix up database
    conn_call($dbc, qw(set game:bytime:06-01-201222:46:01 1));
    conn_call($dbc, qw(set game:1:state running));
    conn_call($dbc, qw(hset game:1:settings turn), get_turn_from_timestampfile(file_content('data/game/nextturn.hst')));
    conn_call($dbc, qw(hset game:1:settings masterHasRun 1));
    conn_call($dbc, qw(smove game:state:preparing game:state:running 1));

    # Prepare a schedule (see host/09_host)
    conn_call($hc, qw(scheduleadd 1 manual));
    conn_call($dbc, qw(hset game:1:settings lastHostTime 1));
    conn_call($dbc, qw(hset game:1:settings lastScheduleChange 0));
    conn_call($hc, qw(gamesetname 1 MyGame));
    conn_call($hc, qw(gamesettype 1 public));

    # Preload: we just need the 'u/' folder to create users.
    conn_call(setup_connect_app($setup, 'file'), 'mkdir', 'u');
}

# Create a user.
sub create_user {
    my $setup = shift;
    my $username = shift;

    my $cgi = cgi_new($setup, "signup.cgi");
    cgi_set_post_params($cgi, username => $username, realname => $username, pass1 => "a", pass2 => "a", terms => "read", nerf => "ok");
    my $result = cgi_run($cgi);
    my $cookie = '';
    foreach (@{$result->{cookies}}) {
        if (/^(session=[^;]*)/) {
            $cookie = $1;
        }
    }
    assert_differs($cookie, '');

    $cookie;
}

sub wait_for_game {
    my ($hc, $gid, $trn) = @_;
    my $loops = 0;
    while (conn_call($hc, 'gameget', $gid, 'turn') eq $trn) {
        sleep 0.25;
        assert ++$loops <= 40;
    }
}

sub get_turn_from_timestampfile {
    my $ts = shift;
    assert defined($ts);
    assert length($ts) >= 20;
    return unpack "v", substr($ts, 18, 2);
};
