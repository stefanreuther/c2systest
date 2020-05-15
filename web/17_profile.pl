#!/usr/bin/perl -w
#
#  Profile editor (settings) tests
#
use strict;
use c2systest;
use c2cgitest;

# Test "identity" settings.
# A: fetch identity page. Change form and resubmit. Verify results.
# E: form has correct content. Update correctly modifies the database.
test 'web/17_profile/identity', sub {
    my $setup = shift;
    do_test($setup, '/identity',
            [{db => 'infocountry',      form => 'country',         old_db => 'Disneyland',   old_form => 'Disneyland',   new_db => 'Narnia',     new_form => 'Narnia'},
             {db => 'infotown',         form => 'town',            old_db => 'Ducksburg',    old_form => 'Ducksburg',    new_db => 'Wardrobe',   new_form => 'Wardrobe'},
             {db => 'infooccupation',   form => 'occupation',      old_db => 'Eating tacos', old_form => 'Eating tacos', new_db => 'Riding',     new_form => 'Riding'},
             {db => 'infobirthday',     form => 'birthday',        old_db => 'May 35',       old_form => 'May 35',       new_db => 'Monday',     new_form => 'Monday'},
             {db => 'infowebsite',      form => 'website',         old_db => 'http://lol',   old_form => 'http://lol',   new_db => 'http://w.w', new_form => 'http://w.w'},
             {db => 'screenname',       form => 'screenname',      old_db => 'Scrooge',      old_form => 'Scrooge',      new_db => 'Witch',      new_form => 'Witch'},
             {db => 'realname',         form => 'realname',        old_db => 'Mc Duck',      old_form => 'Mc Duck',      new_db => 'White',      new_form => 'White'},
             {db => 'inforealnameflag', form => 'realname_public', old_db => 1,              old_form => 'checked',      new_db => '0',          new_form => ''}]);
};

# Test "forum" settings, enabled settings.
# A: enable settings in database. Fetch forum page. Change form and resubmit. Verify results.
# E: form has correct content. Update correctly modifies the database.
test 'web/17_profile/forum/enabled', sub {
    my $setup = shift;
    do_test($setup, '/forum',
            [{db => 'talkautowatch',       form => 'forum_autowatch',       old_db => 1, old_form => 'checked', new_db => 0, new_form => ''},
             {db => 'joinautowatch',       form => 'forum_joinautowatch',   old_db => 1, old_form => 'checked', new_db => 0, new_form => ''},
             {db => 'talkautolink',        form => 'forum_autolink',        old_db => 1, old_form => 'checked', new_db => 0, new_form => ''},
             {db => 'talkautosmiley',      form => 'forum_autosmiley',      old_db => 1, old_form => 'checked', new_db => 0, new_form => ''},
             {db => 'talkwatchindividual', form => 'forum_watchindividual', old_db => 1, old_form => '1',       new_db => 0, new_form => '0'}]);
};

# Test "forum" settings, disabled checkboxes.
# A: disable settings in database. Fetch forum page. Change form and resubmit. Verify results.
# E: form has correct content. Update correctly modifies the database.
test 'web/17_profile/forum/disabled', sub {
    my $setup = shift;
    do_test($setup, '/forum',
            [{db => 'talkautowatch',       form => 'forum_autowatch',       old_db => 0, old_form => '',  new_db => 1, new_form => 'checked'},
             {db => 'joinautowatch',       form => 'forum_joinautowatch',   old_db => 0, old_form => '',  new_db => 1, new_form => 'checked'},
             {db => 'talkautolink',        form => 'forum_autolink',        old_db => 0, old_form => '',  new_db => 1, new_form => 'checked'},
             {db => 'talkautosmiley',      form => 'forum_autosmiley',      old_db => 0, old_form => '',  new_db => 1, new_form => 'checked'},
             {db => 'talkwatchindividual', form => 'forum_watchindividual', old_db => 0, old_form => '0', new_db => 1, new_form => '1'}]);
};

# Test "email" settings.
# A: fetch email page. Change form and resubmit. Verify results.
# E: form has correct content. Update correctly modifies the database. Confirmation requested.
test 'web/17_profile/email', sub {
    my $setup = shift;
    do_test($setup, '/email',
            [{db => 'email',         form => 'email',        old_db => 'sp@m', old_form => 'sp@m',    new_db => 'm@il', new_form => 'm@il'},
             {db => 'infoemailflag', form => 'email_public', old_db => 1,      old_form => 'checked', new_db => 0,      new_form => ''},
             {db => 'mailgametype',  form => 'mailgametype', old_db => 'zip',  old_form => 'zip',     new_db => 'rst',  new_form => 'rst'},
             {db => 'mailpmtype',    form => 'mailpmtype',   old_db => 'info', old_form => 'info',    new_db => 'msg',  new_form => 'msg'}]);

    # There must be a confirmation mail for 'm@il' in the queue
    my $db = setup_connect_app($setup, 'db');
    my @mqueue = conn_call_list($db, 'smembers', 'mqueue:sending');
    assert_equals scalar(@mqueue), 1;

    my $mid = $mqueue[0];
    assert_equals conn_call($db, 'hget', "mqueue:msg:$mid:data", 'template'), 'confirm';
    assert_set_equals conn_call($db, 'smembers', "mqueue:msg:$mid:to"), ['mail:m@il'];
};

# Test "preferences" settings.
# A: fetch preferences page. Change form and resubmit. Verify results.
# E: form has correct content. Update correctly modifies the database. Confirmation requested.
test 'web/17_profile/prefs', sub {
    my $setup = shift;

    # This needs to be done differently from the other tests because it uses a <select>/<option>
    # which our simple-minded parser cannot handle.
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create stuff
    my $uc = setup_connect_app($setup, 'user');
    my $id = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $id);

    # Set values
    conn_call($uc, 'set', $id, 'language', 'en');

    # Load "edit" form
    my $cgi = cgi_new($setup, 'settings.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_path($cgi, '/prefs');
    my $result = cgi_run($cgi);
    my $html = html_verify('settings.cgi', $result->{text});
    my $form = $html->{forms}[0];
    assert $form;
    assert_contains $result->{text}, 'value="en" selected';

    # Update and save the form
    $form->{values}{prefs_language} = 'de';

    # Verify the update
    my $update = cgi_new_form($setup, $form);
    cgi_add_cookie($update, $cookie);
    my $update_result = cgi_run($update);
    assert_starts_with $update_result->{headers}{status}, 302;
    assert_equals $update_result->{headers}{location}, '/settings.cgi';

    # Verify updated content
    assert_equals conn_call($uc, 'get', $id, 'language'), 'de';
};


# Common test logic
sub do_test {
    my ($setup, $page, $list) = @_;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create stuff
    my $uc = setup_connect_app($setup, 'user');
    my $id = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $id);

    # Set values
    conn_call($uc, 'set', $id, map {($_->{db}, $_->{old_db})} @$list);

    # Load "edit" form
    my $cgi = cgi_new($setup, 'settings.cgi');
    cgi_add_cookie($cgi, $cookie);
    cgi_set_path($cgi, $page);
    my $result = cgi_run($cgi);
    my $html = html_verify('settings.cgi', $result->{text});

    # Verify form content
    my $form = $html->{forms}[0];
    assert $form;
    foreach (@$list) {
        assert_equals $form->{values}{$_->{form}}, $_->{old_form};
    }

    # Update and save the form
    foreach (@$list) {
        $form->{values}{$_->{form}} = $_->{new_form};
    }

    # Verify the update
    my $update = cgi_new_form($setup, $form);
    cgi_add_cookie($update, $cookie);
    my $update_result = cgi_run($update);
    assert_starts_with $update_result->{headers}{status}, 302;
    assert_equals $update_result->{headers}{location}, '/settings.cgi';

    # Verify updated content
    foreach (@$list) {
        assert_equals conn_call($uc, 'get', $id, $_->{db}), $_->{new_db};
    }
}
