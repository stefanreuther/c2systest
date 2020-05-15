#!/usr/bin/perl -w

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Constants
sub FORUM_ID { 3; }
sub GAME_ID { 1; }


test 'web/37_gamesettings/overview', sub {
    my $setup = shift;
    prepare($setup);
    my $db = setup_connect_app($setup, 'db');

    # Create user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $uid);

    # Join
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'playerjoin', GAME_ID, 7, $uid);

    # Fetch settings page
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game/settings');
        cgi_add_cookie($cgi, $cookie);
        my $result = cgi_run($cgi);
        my $html = cgi_verify_result($cgi, $result);

        assert_contains $result->{text}, 'Default (zipped result)';
        assert_equals $html->{forms_by_name}{mailformatform}{values}{mailformat}, 'default';
    }

    # Change user default
    conn_call($uc, 'set', $uid, 'mailgametype', 'rst');

    # Fetch settings page
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game/settings');
        cgi_add_cookie($cgi, $cookie);
        my $result = cgi_run($cgi);
        my $html = cgi_verify_result($cgi, $result);

        assert_contains $result->{text}, 'Default (raw result)';
        assert_equals $html->{forms_by_name}{mailformatform}{values}{mailformat}, 'default';
    }

    # Change game default
    conn_call($hc, 'playerset', GAME_ID, $uid, 'mailgametype', 'info');

    # Fetch settings page
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game/settings');
        cgi_add_cookie($cgi, $cookie);
        my $result = cgi_run($cgi);
        my $html = cgi_verify_result($cgi, $result);


        assert_contains $result->{text}, 'Default (raw result)';
        assert_equals $html->{forms_by_name}{mailformatform}{values}{mailformat}, 'info';
    }
};

# Test joining with joinautowatch enabled.
# A: set up a game and a user with default settings (=joinautowatch enabled). Join the game.
# E: user must now watch the game.
test 'web/37_gamesettings/join/autowatch', sub {
    my $setup = shift;
    prepare($setup);

    # Verify preconditions
    my $dbc = setup_connect_app($setup, 'db');
    assert_equals conn_call($dbc, 'hget', 'default:profile', 'joinautowatch'), 1;

    # Create user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $uid);

    my $fc = setup_connect_app($setup, 'talk');
    conn_call($fc, 'user', $uid);
    assert_equals conn_call($fc, 'userlswatchedforums', 'contains', FORUM_ID), 0;

    # Use CGI to join
    my $cgi = cgi_new($setup, 'host/game.cgi');
    cgi_set_path($cgi, '/1-The-Game');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, action => 'join', slot => 3);
    my $result = cgi_run($cgi);
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/host/game.cgi/1-The-Game';

    # Verify forum
    assert_equals conn_call($fc, 'userlswatchedforums', 'contains', FORUM_ID), 1;
};

# Test joining with joinautowatch disabled.
# A: set up a game and a user with joinautowatch disabled. Join the game.
# E: user must not watch the game.
test 'web/37_gamesettings/join/noautowatch', sub {
    my $setup = shift;
    prepare($setup);

    # Create user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $uid);
    conn_call($uc, 'set', $uid, 'joinautowatch', 0);

    # Use CGI to join
    my $cgi = cgi_new($setup, 'host/game.cgi');
    cgi_set_path($cgi, '/1-The-Game');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, action => 'join', slot => 3);
    my $result = cgi_run($cgi);
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/host/game.cgi/1-The-Game';

    # Verify forum
    my $fc = setup_connect_app($setup, 'talk');
    conn_call($fc, 'user', $uid);
    assert_equals conn_call($fc, 'userlswatchedforums', 'contains', FORUM_ID), 0;
};

# Test setting the mail format.
# A: set up a game and join a user. Set mail format to non-default and default.
# E: Database key needs to be created/deleted as configured.
test 'web/37_gamesettings/mail', sub {
    my $setup = shift;
    prepare($setup);
    my $db = setup_connect_app($setup, 'db');

    # Create user
    my $uc = setup_connect_app($setup, 'user');
    my $uid = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $uid);

    # Join
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'playerjoin', GAME_ID, 7, $uid);

    # Use CGI to set result format
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game'); 
        cgi_add_cookie($cgi, $cookie); 
        cgi_set_post_params($cgi, action => 'mailsave', mailformat => 'rst');
        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{status}, 302;
        assert_equals $result->{headers}{location}, '/host/game.cgi/1-The-Game';

        # Verify on DB and host
        assert_equals conn_call($hc, 'playerget', GAME_ID, $uid, 'mailgametype'), 'rst';
        assert_equals conn_call($db, 'hget', 'game:'.GAME_ID.':user:'.$uid, 'mailgametype'), 'rst';
    }

    # Use CGI to set default format
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game'); 
        cgi_add_cookie($cgi, $cookie); 
        cgi_set_post_params($cgi, action => 'mailsave', mailformat => 'default');
        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{status}, 302;
        assert_equals $result->{headers}{location}, '/host/game.cgi/1-The-Game';

        # Verify on DB and host
        assert_equals conn_call($hc, 'playerget', GAME_ID, $uid, 'mailgametype'), '';
        assert !defined conn_call($db, 'hget', 'game:'.GAME_ID.':user:'.$uid, 'mailgametype');
    }

    # Use CGI to set info format
    # Until 20190419, host/game.cgi was using 'note' instead of 'info'. settings.cgi and c2host-server used 'info'.
    {
        my $cgi = cgi_new($setup, 'host/game.cgi');
        cgi_set_path($cgi, '/1-The-Game'); 
        cgi_add_cookie($cgi, $cookie); 
        cgi_set_post_params($cgi, action => 'mailsave', mailformat => 'info');
        my $result = cgi_run($cgi);
        assert_starts_with $result->{headers}{status}, 302;
        assert_equals $result->{headers}{location}, '/host/game.cgi/1-The-Game';

        # Verify on DB and host
        assert_equals conn_call($hc, 'playerget', GAME_ID, $uid, 'mailgametype'), 'info';
        assert_equals conn_call($db, 'hget', 'game:'.GAME_ID.':user:'.$uid, 'mailgametype'), 'info';
    }
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    c2service::setup_db_init($setup);
    c2service::setup_talk_init($setup);
    c2service::setup_hostfile_add_defaults($setup);

    # Dummy tools
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    # Add a game
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, GAME_ID;
    conn_call($hc, 'gamesetname', $gid, 'The Game');
    conn_call($hc, 'gamesettype', $gid, 'public');
    conn_call($hc, 'gamesetstate', $gid, 'joining');

    # Check game forum
    my $fid = conn_call($hc, 'gameget', $gid, 'forum');
    assert_equals $fid, FORUM_ID;
}
