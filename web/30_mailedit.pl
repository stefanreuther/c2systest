#!/usr/bin/perl -w
#
#  Test mail/edit.cgi
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test normal initialisation.
# A: Invoke editor with 'to' parameter.
# E: Form correctly prepared.
test 'web/30_mailedit/init', sub {
    my $setup = shift;
    prepare($setup);

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, to => 'wilma, g:1'); 
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma, g:1';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, '';
    assert_equals $html->{forms_by_name}{mailform}{values}{enable_links}, '1';
    assert_equals $html->{forms_by_name}{mailform}{values}{enable_smileys}, '1';
    assert $result->{text} !~ /The receivers .* are invalid./;
};

# Test initialisation with flags.
# A: Submit form.
# E: Mail submitted and retrievable via talk service.
test 'web/30_mailedit/init_flags', sub {
    my $setup = shift;
    prepare($setup);

    # Set user profile for fred
    my $uc = setup_connect_app($setup, 'user');
    conn_call($uc, 'set', 1001, talkautolink => 1, talkautosmiley => 0);

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, to => 'wilma');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, '';
    assert_equals $html->{forms_by_name}{mailform}{values}{enable_links}, '1';
    assert_equals $html->{forms_by_name}{mailform}{values}{enable_smileys}, '';
    assert $result->{text} !~ /The receivers .* are invalid./;
};

# Test reply to message.
# A: Invoke editor with 'reply' parameter.
# E: Form uses correct addressee.
test 'web/30_mailedit/reply', sub {
    my $setup = shift;
    prepare($setup);

    # Create one message from wilma to fred
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1002');
    my $pmid = conn_call($tc, 'pmnew', 'u:1001', 'subj', 'text:content');

    # Reply to that message as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $pmid, folder => 1);
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify form content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, 'Re: subj';
    assert_contains $result->{text}, "[quote=wilma]\ncontent[/quote]";
};

# Test reply to message with multiple receivers.
# A: Invoke editor with 'reply' parameter.
# E: Form uses correct addressee.
test 'web/30_mailedit/reply_multi', sub {
    my $setup = shift;
    prepare($setup);

    # Create one message from wilma to fred and others
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1002');
    my $pmid = conn_call($tc, 'pmnew', 'u:1001,g:1,u:1002', 'subj', 'text:content');

    # Reply to that message as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $pmid, folder => 1);
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify form content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma, g:1';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, 'Re: subj';
    assert_contains $result->{text}, "[quote=wilma]\ncontent[/quote]";
};

# Test reply to forum posting.
# A: Invoke editor with 'reply_post' parameter.
# E: Form uses correct addressee.
test 'web/30_mailedit/reply_post', sub {
    my $setup = shift;
    prepare($setup);

    # Create a forum posting as wilma
    my $tc = setup_connect_app($setup, 'talk');
    my $fid = conn_call($tc, 'forumadd', 'readperm', 'all');
    my $mid = conn_call($tc, 'postnew', $fid, 'post subj', 'text:post text', 'user', '1002');

    # Reply to posting as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply_post', id => $mid);
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify form content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, 'Re: post subj';
    assert_contains $result->{text}, "[quote=wilma;$mid]\npost text[/quote]";
};

# Test reply to message written by ourselves.
# A: Invoke editor with 'reply' parameter.
# E: Form uses correct addressee.
test 'web/30_mailedit/reply_self', sub {
    my $setup = shift;
    prepare($setup);

    # Create message as fred
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1001');
    my $pmid = conn_call($tc, 'pmnew', 'u:1001', 'subj', 'text:content');

    # Reply to message as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $pmid, folder => 1);
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify form content
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'fred';
    assert_equals $html->{forms_by_name}{mailform}{values}{subject}, 'Re: subj';
    assert_contains $result->{text}, "[quote=fred]\ncontent[/quote]";
};

# Test form submission with correct parameters.
# A: Submit form.
# E: Mail submitted and retrievable via talk service.
test 'web/30_mailedit/submit', sub {
    my $setup = shift;
    prepare($setup);

    # Submit form
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi,
                        text => 'Hi there',
                        action => 'submit',
                        subject => 'subj',
                        to => 'wilma');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Successful submission generates a redirect
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/mail/';

    # Verify message
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1002');

    # - We have one message
    my @pms = conn_call_list($tc, 'folderlspm', 1);
    assert_equals scalar(@pms), 1;

    # - Verify content
    assert_equals conn_call($tc, 'pmrender', 1, $pms[0], 'format', 'raw'), 'forum:Hi there';
};

# Test form submission with correct parameters, variant.
# A: Submit form.
# E: Mail submitted and retrievable via talk service.
test 'web/30_mailedit/submit2', sub {
    my $setup = shift;
    prepare($setup);

    # Submit form
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi,
                        text => 'Hi there',
                        action => 'submit',
                        subject => 'subj',
                        to => ' , wilma, fred ');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Successful submission generates a redirect
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/mail/';

    # Verify message
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1002');

    # - We have one message
    my @pms = conn_call_list($tc, 'folderlspm', 1);
    assert_equals scalar(@pms), 1;

    # - Verify content
    assert_equals conn_call($tc, 'pmrender', 1, $pms[0], 'format', 'raw'), 'forum:Hi there';
};

# Test form submission with flags.
# A: Submit form.
# E: Mail submitted and retrievable via talk service.
test 'web/30_mailedit/submit_flags', sub {
    my $setup = shift;
    prepare($setup);

    # Submit form
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi,
                        text => 'Hi there',
                        action => 'submit',
                        subject => 'subj',
                        enable_links => 1,
                        enable_smileys => 1,
                        to => 'wilma');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Successful submission generates a redirect
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, '/mail/';

    # Verify message
    my $tc = setup_connect_app($setup, 'talk');
    conn_call($tc, 'user', '1002');

    # - We have one message
    my @pms = conn_call_list($tc, 'folderlspm', 1);
    assert_equals scalar(@pms), 1;

    # - Verify content
    assert_equals conn_call($tc, 'pmrender', 1, $pms[0], 'format', 'raw'), 'forumLS:Hi there';
};

# Test form submission with bad 'to' parameter.
# A: Submit form.
# E: Error form correctly prepared.
test 'web/30_mailedit/submit_wrong', sub {
    my $setup = shift;
    prepare($setup);

    # Submit form
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'mail/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi,
                        text => 'Hi there',
                        action => 'submit',
                        to => 'wilma, g:1, barney, g:20');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Receivers are NOT removed from form, but shown as invalid
    assert_equals $html->{forms_by_name}{mailform}{values}{to}, 'wilma, g:1, barney, g:20';
    assert_contains $result->{text}, 'The receivers "<tt>barney, g:20</tt>" are invalid.';
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

