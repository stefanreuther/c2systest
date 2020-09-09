#!/usr/bin/perl -w
#
#  Test host/uploadturn.cgi.
#
#  Exercises host/uploadturn.cgi, api/host.cgi and the HostTurn implementation.
#  Actual turn status is set using a replacement for the checkturn script.
#
use strict;
use c2systest;
use c2cgitest;

my $TURN_TIMESTAMP = "11-06-201603:00:06";
my $TURN_SLOT = 7;

# Test normal turn upload. No schedule given.
# A: submit a turn file with no additional parameters
# E: turn file must be accepted and valid. "Mark temporary" not offered due to no schedule.
test 'web/14_uploadturn/nosched', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrngreen';
    assert_contains $result->{text}, 'game.cgi/32-MyGame';
    assert $result->{text} !~ 'name="marktemp"';
};

test 'web/14_uploadturn/nosched/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 0;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 1;    # green
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};

# Test normal turn upload, normal schedule.
# A: submit a turn file with no additional parameters
# E: turn file must be accepted and valid. "Mark temporary" offered.
test 'web/14_uploadturn/normal', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 early));

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrngreen';
    assert_contains $result->{text}, 'name="marktemp"';
};
test 'web/14_uploadturn/normal/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 early));

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 1;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 1;    # green
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};

# Test normal turn upload. Non-accelerated schedule given.
# A: submit a turn file with no additional parameters
# E: turn file must be accepted and valid. "Mark temporary" not offered due to non-accelerated schedule.
test 'web/14_uploadturn/noearly', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 noearly));

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrngreen';
    assert $result->{text} !~ 'name="marktemp"';
};
test 'web/14_uploadturn/noearly/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 noearly));

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 0;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 1;    # green
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};

# Test normal turn upload. Schedule given with low delay.
# A: submit a turn file with no additional parameters
# E: turn file must be accepted and valid. "Mark temporary" not offered due to low delay.
test 'web/14_uploadturn/quick', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 4 early));

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrngreen';
    assert $result->{text} !~ 'name="marktemp"';
};
test 'web/14_uploadturn/quick/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 0);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 4 early));

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 0;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 1;    # green
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};

# Test normal turn upload. Turn is red.
# A: submit a turn file.
# E: turn file must be rejected.
test 'web/14_uploadturn/red', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 2);   # red

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrnred';
};
test 'web/14_uploadturn/red/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 2);   # red

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 0;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 3;    # red
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};

# Test normal turn upload. Turn is yellow.
# A: submit a turn file.
# E: turn file must be rejected.
test 'web/14_uploadturn/yellow', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 1);   # yellow

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 early));

    my $cgi = cgi_new($setup, 'host/uploadturn.cgi');
    cgi_set_post_params($cgi, file => file_content(cmdl_input_file('empty.trn')));
    cgi_add_cookie($cgi, setup_make_cookie($setup, 'uu'));

    my $result = cgi_run($cgi);
    assert_contains $result->{text}, 'ultrnyellow';
    assert_contains $result->{text}, 'name="marktemp"';
};
test 'web/14_uploadturn/yellow/api', sub {
    my $setup = shift;
    prepare($setup);
    prepare_game($setup, 32, $TURN_TIMESTAMP);
    prepare_user($setup, 32, $TURN_SLOT, 'uu');
    prepare_result($setup, 1);   # yellow

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, qw(scheduleadd 32 daily 5 delay 10 early));

    my $result = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 'uu'),
                                action => 'trn',
                                data => file_content(cmdl_input_file('empty.trn')));

    assert_equals $result->{result}, 1;
    assert_equals $result->{allowtemp}, 1;
    assert_equals $result->{user}, 'uu';
    assert_equals $result->{slot}, 7;
    assert_equals $result->{status}, 2;    # yellow
    assert_equals $result->{game}, 32;
    assert_equals $result->{name}, 'MyGame';
};




# Set up default environment
sub prepare {
    my $setup = shift;
    setup_add_hostfile($setup, 'auto');
    setup_add_userfile($setup, 'auto');
    setup_add_host($setup, '--nocron');
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_usermgr($setup);
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
    my ($setup, $gid, $slot, $user) = @_;

    # Define the user in the database
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, 'set', "uid:$user", $user);
    conn_call($dbc, 'set', "user:$user:name", $user);
    conn_call($dbc, 'hmset', "user:$user:profile", screenname => $user),
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
