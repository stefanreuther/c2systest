#!/usr/bin/perl -w
use strict;
use c2cgitest;
use c2service;
use c2systest;

# Test normal initialisation.
# A: Invoke editor.
# E: Form correctly prepared.
test 'web/33_talkedit/init', sub {
    my $setup = shift;
    prepare($setup);

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'talk/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'new', forum => 1); 
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_equals $html->{forms_by_name}{postform}{values}{forum}, 1;
    assert_equals $html->{forms_by_name}{postform}{values}{subject}, '';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_links}, '1';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_smileys}, '1';
};

# Test normal initialisation, profile config.
# A: Invoke editor.
# E: Form correctly prepared.
test 'web/33_talkedit/init/config', sub {
    my $setup = shift;
    prepare($setup);

    conn_call(setup_connect_app($setup, 'user'), 'set', 1001, talkautolink => 0, talkautosmiley => 0);

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'talk/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'new', forum => 1); 
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_equals $html->{forms_by_name}{postform}{values}{forum}, 1;
    assert_equals $html->{forms_by_name}{postform}{values}{subject}, '';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_links}, '';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_smileys}, '';
};

# Test initialisation for reply.
# A: Invoke editor in reply mode.
# E: Form correctly prepared.
test 'web/33_talkedit/init/reply', sub {
    my $setup = shift;
    prepare($setup);

    # Post something
    my $tc = setup_connect_app($setup, 'talk');
    my $mid = conn_call($tc, 'postnew', 1, 'subj', 'text:body', 'user', 1002);

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'talk/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $mid); 
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # Verify content
    assert_equals $html->{forms_by_name}{postform}{values}{id}, 1;
    assert_equals $html->{forms_by_name}{postform}{values}{mode}, 'reply';
    assert_equals $html->{forms_by_name}{postform}{values}{subject}, 'Re: subj';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_links}, '1';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_smileys}, '1';
    assert_contains $result->{text}, ">[quote=wilma;$mid]\nbody[/quote]<";
};

# Test post submission.
# A: Submit a reply.
# E: Post must be submitted, redirect to thread.
test 'web/33_talkedit/submit', sub {
    my $setup = shift;
    prepare($setup);

    # Post something
    my $tc = setup_connect_app($setup, 'talk');
    my $mid = conn_call($tc, 'postnew', 1, 'subj', 'text:body', 'user', 1002);
    assert_equals $mid, 1;

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'talk/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $mid, text => "[quote=wilma;$mid]\nbody[/quote]", action_submit => 'Send!', enable_links => 1);
    my $result = cgi_run($cgi);

    # Verify posting
    my $new_mid = $mid+1;
    assert_list_equals conn_call($tc, 'postlsnew', 5), [$new_mid, $mid];
    assert_equals conn_call($tc, 'postrender', $new_mid, 'format', 'raw'), "forumL:[quote=wilma;$mid]\nbody[/quote]";

    # Verify response
    assert_starts_with $result->{headers}{status}, 302;
    assert_equals $result->{headers}{location}, "/talk/thread.cgi/1-subj#p$new_mid";
};

# Test preview submission.
# A: Submit a preview.
# E: Post must be submitted, redirect to thread.
test 'web/33_talkedit/preview', sub {
    my $setup = shift;
    prepare($setup);

    # Post something
    my $tc = setup_connect_app($setup, 'talk');
    my $mid = conn_call($tc, 'postnew', 1, 'subj', 'text:body', 'user', 1002);
    assert_equals $mid, 1;

    # Load form as fred
    my $cookie = setup_make_cookie($setup, 1001);
    my $cgi = cgi_new($setup, 'talk/edit.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_post_params($cgi, mode => 'reply', id => $mid, text => "[quote=wilma;$mid]\nbody[/quote]\nanswer", action_preview => 'Preview', enable_links => 1);
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);

    # No new posting
    assert_list_equals conn_call($tc, 'postlsnew', 5), [1];

    # Verify response
    assert_contains $result->{text}, 'href="/userinfo.cgi/wilma"';               # appears in preview
    assert_equals $html->{forms_by_name}{postform}{values}{mode}, 'reply';
    assert_equals $html->{forms_by_name}{postform}{values}{id}, 1;
    assert_equals $html->{forms_by_name}{postform}{values}{enable_smileys}, '';
    assert_equals $html->{forms_by_name}{postform}{values}{enable_links}, '1';
};


sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create two users
    c2service::setup_db_init($setup);

    my $uc = setup_connect_app($setup, 'user');
    assert_equals conn_call($uc, 'adduser', 'fred', 'secret', 'screenname', 'Fred F'), '1001';
    assert_equals conn_call($uc, 'adduser', 'wilma', 'secret', 'screenname', 'Wilma F'), '1002';

    # Create a forum
    my $tc = setup_connect_app($setup, 'talk');
    my $fid = conn_call($tc, 'forumadd', 'readperm', 'all', 'writeperm', 'all', 'answerperm', 'all');
}
