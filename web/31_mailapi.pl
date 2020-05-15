#!/usr/bin/perl -w
use strict;
use c2systest;
use c2service;
use c2cgitest;

# Test folderlspm
test 'web/31_mailapi/folderlspm', sub {
    my $setup = shift;
    prepare($setup);

    # Send mail from fred to wilma
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1001');
    my $pmid = conn_call($tc, 'pmnew', 'u:1002', 'greeting', 'text:good morning');
    assert_equals $pmid, 1;

    # List outbox (2) as fred
    my $token = setup_make_api_token($setup, 1001);
    my $result = setup_post_api($setup, 'api/mail.cgi', undef,
                                api_token => $token,
                                action => 'folderlspm',
                                ufid => 2);
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, [1];
};

# Test pmstat
test 'web/31_mailapi/pmstat', sub {
    my $setup = shift;
    prepare($setup);

    # Send mail from fred to wilma and others
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1001');
    conn_call($tc, 'pmnew', 'u:1002,g:1,g:1:3', 'greeting', 'text:good morning');

    # Fetch from wilma's inbox
    my $token = setup_make_api_token($setup, 1002);
    my $result = setup_post_api($setup, 'api/mail.cgi', undef,
                                api_token => $token,
                                action => 'pmstat',
                                ufid => 1,
                                pmid => 1);
    assert_equals $result->{result}, 1;
    assert_equals $result->{author}, 'fred';
    assert_equals $result->{to}, 'wilma,g:1,g:1:3';
    assert_equals $result->{subject}, 'greeting';
};

# Test pmmstat
test 'web/31_mailapi/pmmstat', sub {
    my $setup = shift;
    prepare($setup);

    # Send mail from fred to wilma and others
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1001');
    conn_call($tc, 'pmnew', 'u:1002,g:1,g:1:3', 'greeting', 'text:good morning');

    # Fetch from wilma's inbox
    my $token = setup_make_api_token($setup, 1002);
    my $result = setup_post_api($setup, 'api/mail.cgi', undef,
                                api_token => $token,
                                action => 'pmmstat',
                                ufid => 1,
                                pmids => "3,1");
    assert_equals $result->{result}, 1;
    assert !defined $result->{reply}[0];
    assert ref $result->{reply}[1];
    assert_equals $result->{reply}[1]{author}, 'fred';
    assert_equals $result->{reply}[1]{to}, 'wilma,g:1,g:1:3';
    assert_equals $result->{reply}[1]{subject}, 'greeting';
};

# Test verifyreceiver
test 'web/31_mailapi/verifyreceiver', sub {
    my $setup = shift;
    prepare($setup);

    # Invoke as wilma
    my $token = setup_make_api_token($setup, 1002);
    my $result = setup_post_api($setup, 'api/mail.cgi', undef,
                                api_token => $token,
                                action => 'verifyreceiver',
                                to => 'fred,g:1,wilma,g:3,barney,g:1:3');
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, [1,1,1,0,0,1];

    # Invoke as anon
    $result = setup_post_api($setup, 'api/mail.cgi', undef,
                             action => 'verifyreceiver',
                             to => 'fred,wilma,g:3,barney,g:1:3,g:1');
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, [1,1,0,0,1,1];
};

# Test pmnew, success case
test 'web/31_mailapi/pmnew/ok', sub {
    my $setup = shift;
    prepare($setup);

    # Preload system with some PMs
    my $talk = setup_connect_app($setup, 'talk');
    conn_call($talk, 'user', '1001');
    foreach (1..10) {
        conn_call($talk, 'pmnew', 'u:1002', 'sub', 'text:text');
    }

    # Send PM as wilma. Will be pmid=11 because we generated 10 messages above.
    my $token = setup_make_api_token($setup, 1002);
    my $result = setup_post_api($setup, 'api/mail.cgi', undef,
                                api_token => $token,
                                action => 'pmnew',
                                to => 'fred,g:1',
                                subject => 'hi',
                                text => 'text:Hi');
    assert_equals $result->{result}, 1;
    assert_equals $result->{pmid}, 11;

    # Verify DB content
    my %stat = conn_call_list($talk, 'pmstat', 1, 11);
    assert_equals $stat{to}, 'u:1001,g:1';
    assert_equals $stat{author}, '1002';
    assert_equals $stat{subject}, 'hi';
    assert_equals conn_call($talk, 'pmrender', 1, 11, 'format', 'html'), "<p>Hi</p>\n";
};

# Test pmnew, error cases
test 'web/31_mailapi/pmnew/bad', sub {
    my $setup = shift;
    prepare($setup);

    my $token = setup_make_api_token($setup, 1002);

    # Not logged in
    assert_throws sub{ setup_post_api($setup, 'api/mail.cgi', undef,
                                      action => 'pmnew',
                                      to => 'fred',
                                      subject => 'hi',
                                      text => 'text:Hi') }, '401';

    # Bad receiver
    assert_throws sub{ setup_post_api($setup, 'api/mail.cgi', undef,
                                      api_token => $token,
                                      action => 'pmnew',
                                      to => 'fred,g:1,wilma,g:3,barney,g:1:3',
                                      subject => 'hi',
                                      text => 'text:Hi') }, '400';

    # Bad text
    assert_throws sub{ setup_post_api($setup, 'api/mail.cgi', undef,
                                      api_token => $token,
                                      action => 'pmnew',
                                      to => 'fred',
                                      subject => 'hi',
                                      text => 'Hi') }, '400';
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
}

