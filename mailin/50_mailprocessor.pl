#!/usr/bin/perl -w
#
#  Mailin: MailProcessor
#
#  Synced with TestServerMailinMailProcessor, 20170928
#  Fails with c2mailin-classic:
#  - mailin/50_mailprocessor/nested: message/rfc822 support not in classic
#  - mailin/50_mailprocessor/deep: depth limit not in classic
#
use strict;
use c2systest;
use c2service;

# The timestamp of mail_turn.txt
my $TURN_TIMESTAMP = "06-02-201219:07:04";
my $TURN_SLOT = 2;

# Other timestamp
my $OTHER_TIMESTAMP = "22-11-199911:22:33";


# TestServerMailinMailProcessor::testSimple: Test simple mail without attachment.
test 'mailin/50_mailprocessor/simple', sub {
    my $setup = shift;
    prepare($setup);

    process_file($setup, 'mail_simple.txt');

    my @list = fetch_mail_queue($setup);
    assert !@list;
};

# TestServerMailinMailProcessor::testTurn: Test successful turn submission.
#    "Successful" means I have extracted the turn file and sent it to host.
#    There is no difference between different results.
#    That is solved using mail templates.
test 'mailin/50_mailprocessor/turn', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'stefan@localhost');
    prepare_result($setup, 0);

    process_file($setup, 'mail_turn.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn';
    assert_equals $list[0]{to}, 'user:uu';
    assert_equals $list[0]{args}{trn_status}, 1;
    assert_equals $list[0]{args}{gameid}, 32;
    assert_equals $list[0]{args}{mail_subject}, 'test';
    assert_equals $list[0]{args}{gamename}, 'MyGame';
    assert_equals $list[0]{args}{gameturn}, 42;
};


# TestServerMailinMailProcessor::testError407: Test turn submission with a 407 error.
#    This happens if host cannot associate an email address with the game.
test 'mailin/50_mailprocessor/407', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'other@localhost');  # <- note change
    prepare_result($setup, 0);

    process_file($setup, 'mail_turn.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn-mismatch';
    assert_equals $list[0]{to}, 'mail:stefan@localhost';
    assert_equals $list[0]{args}{mail_subject}, 'test';
};

# TestServerMailinMailProcessor::testError404: Test turn submission with a 404 error.
#    This happens if the timestamp in the turn ist not known to the system.
test 'mailin/50_mailprocessor/404', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $OTHER_TIMESTAMP);                    # <- note change
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'stefan@localhost');
    prepare_result($setup, 0);

    process_file($setup, 'mail_turn.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn-stale';
    assert_equals $list[0]{to}, 'mail:stefan@localhost';
    assert_equals $list[0]{args}{mail_subject}, 'test';
};

# TestServerMailinMailProcessor::testError412: Test turn submission with a 412 error.
#    This happens if a turn is submitted for a game that is not running.
test 'mailin/50_mailprocessor/412', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'stefan@localhost');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(gamesetstate 32 finished));

    process_file($setup, 'mail_turn.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn-stale';
    assert_equals $list[0]{to}, 'mail:stefan@localhost';
    assert_equals $list[0]{args}{mail_subject}, 'test';
};

# TestServerMailinMailProcessor::testError422: Test turn submission with a 422 error.
#    This happens if the turn fails to parse.
test 'mailin/50_mailprocessor/422', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'stefan@localhost');
    prepare_result($setup, 0);

    process_file($setup, 'mail_damaged.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn-error';
    assert_equals $list[0]{to}, 'mail:stefan@localhost';
    assert_equals $list[0]{args}{mail_subject}, 'test';
};

# TestServerMailinMailProcessor::testErrorOther: Test turn submission with another error.
test 'mailin/50_mailprocessor/other', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu', 'stefan@localhost');
    prepare_result($setup, 0);

    # We want to trigger an error other than the explicit errors.
    # The unit test triggered a "game in use" error which hard to trigger in a system test.
    # Removing the directories will trigger an internal error in c2host-ng, because it fails to export.
    # NOTE: This is not contractual. This call may succeed instead.
    # However, the problem must not be interpreted as a "stale turn" error.
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(rmdir defaults));
    conn_call($hfc, qw(rmdir games));

    process_file($setup, 'mail_turn.txt');

    my @list = fetch_mail_queue($setup);
    assert !@list;
};
    
# TestServerMailinMailProcessor::testMultiple: Test turn submission with multiple turns in one mail.
test 'mailin/50_mailprocessor/multi', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 97, $TURN_TIMESTAMP);
    prepare_user($setup, 97, $TURN_SLOT, 'uu', 'a@b');
    prepare_user($setup, 97, 4, 'xx', 'a@b');
    prepare_result($setup, 0);

    process_file($setup, 'mail_multi.txt');

    my @list = fetch_mail_queue($setup);
    assert scalar(@list), 2;

    assert_equals $list[0]{tpl}, 'turn';
    assert_equals $list[0]{to}, 'user:uu';
    assert_equals $list[0]{args}{gameid}, 97;
    assert_equals $list[0]{args}{mail_subject}, 'multi';
    assert_equals $list[0]{args}{mail_path}, '/part1/player2.trn';

    assert_equals $list[1]{tpl}, 'turn';
    assert_equals $list[1]{to}, 'user:xx';
    assert_equals $list[1]{args}{gameid}, 97;
    assert_equals $list[1]{args}{mail_subject}, 'multi';
    assert_equals $list[1]{args}{mail_path}, '/part3/player4.trn';
};

# TestServerMailinMailProcessor::testNested: Test turn submission, nested attachments.
test 'mailin/50_mailprocessor/nested', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'aa', 'stefan@rocket.streu.home');
    prepare_result($setup, 0);

    process_file($setup, 'mail_nested.txt');

    my @list = fetch_mail_queue($setup);
    assert_equals scalar(@list), 1;
    assert_equals $list[0]{tpl}, 'turn';
    assert_equals $list[0]{to}, 'user:aa';
    assert_equals $list[0]{args}{trn_status}, 1;
    assert_equals $list[0]{args}{gameid}, 32;
    assert_equals $list[0]{args}{mail_subject}, '3';
    assert_equals $list[0]{args}{mail_path}, '/part2/part1/part2/part1/part2/part1/part2/player2.trn';
};

# TestServerMailinMailProcessor::testDeep: Test deep nesting.
#    This exercises the DoS (maximum nesting) protection.
test 'mailin/50_mailprocessor/deep', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'aa', 'stefan@localhost');
    prepare_result($setup, 0);

    process_file($setup, 'mail_deep.txt');

    my @list = fetch_mail_queue($setup);
    assert !@list;
};


################################ Utilities ################################

# Set up default environment
sub prepare {
    my $setup = shift;
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_host($setup, '-nocron');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, qw(mkdir games));
    conn_call($hfc, qw(mkdir defaults));
    conn_call($hfc, qw(mkdir bin));
}

# Add a game, given game Id and timestamp
sub prepare_game {
    my ($setup, $gid, $timestamp) = @_;

    # Set game:id so newgame will create the ID we want
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(set game:lastid), $gid-1);

    # Create game using regular mechanisms
    my $hc = setup_connect_app($setup, 'host');
    assert_equals conn_call($hc, 'newgame'), $gid;
    conn_call($hc, 'gamesetname', $gid, 'MyGame');
    conn_call($hc, 'gameset', $gid, masterHasRun => 1, timestamp => $timestamp, turn => 42);
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'running');

    conn_call($dbc, 'set', 'game:bytime:'.$timestamp, $gid);
}

# Add a user, given user Id and email address, and join it to a game
sub prepare_user {
    my ($setup, $gid, $slot, $user, $mail) = @_;

    # Define the user in the database
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', "uid:$user", $user);
    conn_call($dbc, 'set', "user:$user:name", $user);
    conn_call($dbc, 'hmset', "user:$user:profile", screenname => $user, email => $mail),
    conn_call($dbc, 'sadd', 'user:all', $user);

    # Join them to the game
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'playerjoin', $gid, $slot, $user);
}

# Arrange for the checkturn result to be a given value.
sub prepare_result {
    my ($setup, $result) = @_;
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, 'put', 'bin/checkturn.sh', "exit $result");
}

# Process a file.
sub process_file {
    my ($setup, $file) = @_;
    my $prog = setup_get_required_system_config($setup, 'c2mailin.path');
    my $mail = cmdl_input_file($file);
    assert_execution_succeeds "$prog < $mail";
}

# Fetch mail queue and return it as a list-of-hashes.
sub fetch_mail_queue {
    my $setup = shift;
    my $dbc = setup_connect_app($setup, 'db');
    my @id = conn_call_list($dbc, qw(sort mqueue:sending));
    my @list;
    foreach (@id) {
        my @to = conn_call_list($dbc, 'smembers', "mqueue:msg:$_:to");
        assert_equals scalar(@to), 1;
        push @list, { tpl  => conn_call($dbc, 'hget', "mqueue:msg:$_:data", 'template'),
                      args => {conn_call_list($dbc, 'hgetall', "mqueue:msg:$_:args")},
                      to   => $to[0] };
    }
    @list;
}
