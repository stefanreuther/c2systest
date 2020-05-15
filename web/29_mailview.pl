#!/usr/bin/perl -w
#
#  Test mail/view.cgi
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test mail/view.cgi.
# A: prepare a message. List folder and message.
# E: check for key phrases that show that services work together correctly.
test 'web/29_mailview', sub {
    my $setup = shift;
    prepare($setup);

    # Fred's cookie
    my $cookie = setup_make_cookie($setup, '1001');

    # Obtain outbox list
    my $outbox = cgi_new($setup, 'mail/view.cgi');
    cgi_set_path($outbox, "/2");
    cgi_add_cookie($outbox, $cookie);
    my $outbox_result = cgi_run($outbox);
    my $outbox_html = cgi_verify_result($outbox, $outbox_result);
    my $outbox_text = normalize_text($outbox_result->{text});

    # Brute-force check for some key elements
    assert_contains $outbox_text, '<a href="/userinfo.cgi/wilma" class="userlink">Wilma F</a>';
    assert_contains $outbox_text, 'players of <a href="/host/game.cgi/1-The-Game">The Game</a>';
    assert_contains $outbox_text, 'player 5 in <a href="/host/game.cgi/1-The-Game">The Game</a>';
    assert_contains $outbox_text, '>Test Message Subject<';
    assert_contains $outbox_text, '<li class="navtrail-self">Outbox</li>';
    assert_contains $outbox_text, '<p>Sent_messages</p>';                     # Configured by setup_db_init()
    assert exists $outbox_html->{links}{'/mail/view.cgi/2/1'};

    # Obtain individual message from outbox
    my $msg = cgi_new($setup, 'mail/view.cgi');
    cgi_set_path($msg, "/2/1");
    cgi_add_cookie($msg, $cookie);
    my $msg_result = cgi_run($msg);
    my $msg_html = cgi_verify_result($msg, $msg_result);
    my $msg_text = normalize_text($msg_result->{text});

    # Brute-force check for some key elements
    assert_contains $msg_text, '<a href="/userinfo.cgi/wilma" class="userlink">Wilma F</a>';
    assert_contains $msg_text, 'players of <a href="/host/game.cgi/1-The-Game">The Game</a>';
    assert_contains $msg_text, 'player 5 in <a href="/host/game.cgi/1-The-Game">The Game</a>';
    assert_contains $msg_text, '>Test Message Subject<';
    assert_contains $msg_text, '<p>Test Message Content</p>';
    assert_contains $msg_text, '<li class="navtrail-parent"><a href="/mail/view.cgi/2">Outbox</a></li>';
};







sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_start_wait($setup);

    # Create two users
    c2service::setup_db_init($setup);

    my $uc = setup_connect_app($setup, 'user');
    assert_equals conn_call($uc, 'adduser', 'fred', 'secret', 'screenname', 'Fred F'), '1001';
    assert_equals conn_call($uc, 'adduser', 'wilma', 'secret', 'screenname', 'Wilma F'), '1002';

    # Create a game
    my $hc = setup_connect_app($setup, 'host');
    c2service::setup_hostfile_add_defaults($setup);
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');

    assert_equals conn_call($hc, 'newgame'), 1;
    conn_call($hc, 'gamesetstate', 1, 'joining');
    conn_call($hc, 'gamesettype', 1, 'public');
    conn_call($hc, 'gamesetname', 1, 'The Game');

    conn_call($hc, 'playerjoin', 1, 3, 1001);
    conn_call($hc, 'playerjoin', 1, 5, 1002);

    # Send one mail
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', 1001);
    assert_equals conn_call($tc, 'pmnew', 'u:1002,g:1,g:1:5', 'Test Message Subject', 'forum:Test Message Content'), 1;
}

sub normalize_text {
    my $text = shift;
    $text =~ s|<a class="(.*?)" href="(.*?)">|<a href="$2" class="$1">|g;
    $text;
}
