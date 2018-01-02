#!/usr/bin/perl -w
#
#  Host: HostTurn
#
#  Synced with TestServerHostHostTurn, 20170925
#
use strict;
use c2systest;
use c2service;

my $SLOT_NR = 3;
my $DEFAULT_TIMESTAMP = "22-11-199911:22:33";
my $ALTERNATE_TIMESTAMP = "22-11-199912:34:56";

# TestServerHostHostTurn::testSubmit: TRN.
#    This creates a test setup, where the checkturn script produces a hardcoded result.
test 'host/50_turn/submit', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);
    my $hc = setup_connect_app($setup, 'host');

    # Test data
    assert_equals $gid, 1;
    my $dummy_turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);
    my $file_name = "games/0001/in/player$SLOT_NR.trn";
    
    # Upload a simple turn
    my %result = conn_call_list($hc, 'trn', $dummy_turn);

    # - Check result
    assert_equals $result{status}, 1;
    assert_equals $result{game}, $gid;
    assert_equals $result{slot}, $SLOT_NR;
    assert_equals $result{previous}, 0;
    assert_equals $result{user}, '';

    # - Verify that turn is in inbox folder
    my $hfc = setup_connect_app($setup, 'hostfile');
    assert_equals conn_call($hfc, 'get', $file_name), $dummy_turn;

    # Now classify the turn as red
    conn_call($hfc, qw(put bin/checkturn.sh), "exit 2");
    %result = conn_call_list($hc, 'trn', $dummy_turn . 'qqq');

    # - Result must be red
    assert_equals $result{status}, 3;
    assert_equals $result{previous}, 1;

    # - Turn unchanged
    assert_equals conn_call($hfc, 'get', $file_name), $dummy_turn;
};

# TestServerHostHostTurn::testSubmitEmpty: Test submitting an empty file.
#    Must fail with an exception.
test 'host/50_turn/submit/empty', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc, 'trn', '') }, 422;
};

# TestServerHostHostTurn::testSubmitEmptyGame: Test submitting an empty file, with game Id given.
#    Must fail with an exception.
test 'host/50_turn/submit/emptygame', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    my $hc = setup_connect_app($setup, 'host');
    assert_throws sub{ conn_call($hc, 'trn', '', 'game', $gid) }, 422;
};

# TestServerHostHostTurn::testSubmitStale: Test submitting a stale file, no game Id given (game cannot be determined).
#    Must fail with an exception.
test 'host/50_turn/submit/stale', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $ALTERNATE_TIMESTAMP);
    assert_throws sub{ conn_call($hc, 'trn', $turn) }, 404;
};

# TestServerHostHostTurn::testSubmitStaleGame: Test submitting a stale file, with game Id given.
#    Must produce "stale" result.
test 'host/50_turn/submit/stalegame', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Staleness is NOT (currently) determined internally by c2host, even though we could compare timestamps.
    # This is left up to the checkturn script. Hence, give it a script that reports stale.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(put bin/checkturn.sh), 'exit 4');

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $ALTERNATE_TIMESTAMP);

    my %result = conn_call_list($hc, 'trn', $turn, 'game', $gid);
    assert_equals $result{status}, 5;
    assert_equals $result{game}, $gid;
    assert_equals $result{slot}, $SLOT_NR;
    assert_equals $result{previous}, 0;
    assert_equals $result{user}, '';
};

# TestServerHostHostTurn::testSubmitWrongUser: Test submitting as wrong user.
#    Must be rejected.
test 'host/50_turn/submit/wronguser', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);

    conn_call($hc, qw(user z));
    assert_throws sub{ conn_call($hc, 'trn', $turn) }, 403;
    assert_throws sub{ conn_call($hc, 'trn', $turn, 'game', $gid) }, 403;
    assert_throws sub{ conn_call($hc, 'trn', $turn, 'game', $gid, 'slot', $SLOT_NR) }, 403;
};

# TestServerHostHostTurn::testSubmitEmail: Test submitting via email.
#    Must succeed.
test 'host/50_turn/submit/email', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);

    my %result = conn_call_list($hc, 'trn', $turn, 'mail', 'ua@examp.le');
    assert_equals $result{status}, 1;
    assert_equals $result{game}, 1;
    assert_equals $result{slot}, $SLOT_NR;
    assert_equals $result{previous}, 0;
    assert_equals $result{user}, 'ua';
};

# TestServerHostHostTurn::testSubmitEmailCase: Test submitting via email, wrong address.
#    Must succeed.
test 'host/50_turn/submit/emailcase', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);

    my %result = conn_call_list($hc, 'trn', $turn, 'mail', 'UA@Examp.LE');
    assert_equals $result{status}, 1;
    assert_equals $result{game}, 1;
    assert_equals $result{slot}, $SLOT_NR;
    assert_equals $result{previous}, 0;
    assert_equals $result{user}, 'ua';
};

# TestServerHostHostTurn::testSubmitWrongEmail: Test submitting via email, wrong address.
#    Must fail.
test 'host/50_turn/submit/wrongemail', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);
    assert_throws sub{ conn_call($hc, 'trn', $turn, 'mail', 'who@examp.le') }, 407;
};

# TestServerHostHostTurn::testSubmitEmailUser: Test submitting via email, user context.
#    Must fail; this is an admin-only feature.
test 'host/50_turn/submit/useremail', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);
    conn_call($hc, qw(user ua));
    assert_throws sub{ conn_call($hc, 'trn', $turn, 'mail', 'ua@examp.le') }, 403;
};

# TestServerHostHostTurn::testSubmitEmailStale: Test submitting via email, stale file.
#    Must fail.
test 'host/50_turn/submit/stalemail', sub {
    my $setup = shift;
    prepare($setup);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $ALTERNATE_TIMESTAMP);
    assert_throws sub{ conn_call($hc, 'trn', $turn, 'mail', 'ua@examp.le') }, 404;
};

# TestServerHostHostTurn::testStatus: Test statuses.
test 'host/50_turn/status', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Three different contexts
    my $root = setup_connect_app($setup, 'host');
    my $one = setup_connect_app($setup, 'host');
    my $two = setup_connect_app($setup, 'host');
    conn_call($one, qw(user ua));
    conn_call($two, qw(user ub));

    # Test
    # - Submit a correct turn
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);
    conn_call($root, 'trn', $turn);

    # - Read out state in three contexts
    my %i = conn_call_list($root, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;

    %i = conn_call_list($one, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;

    %i = conn_call_list($two, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;

    # - Mark temporary
    conn_call($root, 'trnmarktemp', $gid, $SLOT_NR, 1);

    %i = conn_call_list($root, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 17;

    %i = conn_call_list($one, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 17;

    %i = conn_call_list($two, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;           # does not see temporary flag

    # Submit a yellow turn
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(put bin/checkturn.sh), 'exit 1');
    conn_call($root, 'trn', $turn);

    # - Read out state in three contexts
    %i = conn_call_list($root, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 2;

    %i = conn_call_list($one, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 2;

    %i = conn_call_list($two, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;            # does not see yellow

    # - Mark temporary
    conn_call($root, 'trnmarktemp', $gid, $SLOT_NR, 1);

    %i = conn_call_list($root, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 18;

    %i = conn_call_list($one, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 18;

    %i = conn_call_list($two, 'gamestat', $gid);
    assert_equals $i{turns}[$SLOT_NR-1], 1;           # does not see temporary flag nor yellow
};

# TestServerHostHostTurn::testStatusErrors: Test errors in setTemporary.
test 'host/50_turn/status/errors', sub {
    my $setup = shift;
    prepare($setup);
    my $gid = prepare_game($setup, $DEFAULT_TIMESTAMP);

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my $turn = c2service::vp_make_turn($SLOT_NR, $DEFAULT_TIMESTAMP);

    # Cannot set temporary if there is no turn
    assert_throws sub{ conn_call($hc, 'trnmarktemp', $gid, $SLOT_NR, 1) }, 412;

    # Upload a turn
    conn_call($hc, 'trn', $turn);

    # Cannot set temporary as different user
    conn_call($hc, qw(user z));
    assert_throws sub{ conn_call($hc, 'trnmarktemp', $gid, $SLOT_NR, 1) }, 403;
};



sub prepare {
    my $setup = shift;
    setup_add_host($setup, '-nocron');
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Create 'games'. Required for -classic.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdirhier games));
}

sub add_user {
    my $setup = shift;
    my $user_id = shift;
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'sadd', 'user:all', $user_id);
    conn_call($db, 'set', "uid:$user_id", $user_id);
    conn_call($db, 'hset', "user:$user_id:profile", 'email', "$user_id\@examp.le");
}

sub add_game {
    my $setup = shift;
    my $type = shift;
    my $state = shift;
    my $hc = setup_connect_app($setup, 'host');
    my $gid = conn_call($hc, 'newgame');
    conn_call($hc, 'gamesettype', $gid, $type);
    conn_call($hc, 'gamesetstate', $gid, $state);
    return $gid;
}

sub prepare_game {
    my $setup = shift;
    my $timestamp = shift;
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdirhier bin));
    conn_call($hfc, qw(mkdirhier defaults));

    # Turn upload script. -classic expects the script ot move the turn file from in/new/ to in/.
    conn_call($hfc, qw(put bin/checkturn.sh), 
              'mv "$1/in/new/player$2.trn" "$1/in/player$2.trn"');
    add_user($setup, 'ua');

    my $gid = add_game($setup, 'public', 'running');
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'playerjoin', $gid, $SLOT_NR, 'ua');
    conn_call($hc, 'gameset', $gid, 'timestamp', $timestamp);

    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', "game:bytime:$timestamp", $gid);

    $gid;
}
