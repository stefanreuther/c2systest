#!/usr/bin/perl -w
#
#  Test ranking lists
#  - userlist.cgi
#  - api/user.cgi
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

##
##  userlist.cgi
##

# Test default user list.
# A: prepare users. Invoke userlist.cgi.
# E: must return user list sorted by rank points.
test 'web/36_ranklist/userlist/default', sub {
    my $setup = shift;
    prepare($setup);

    # Fetch default sort
    my $cgi = cgi_new($setup, 'userlist.cgi');
    my $result = cgi_run($cgi);
    my $html = html_verify('userlist.cgi', $result->{text});

    # Order must be betty > fred > wilma > barney. Match HTML. Screen names are wrapped in tags.
    assert $result->{text} =~ />Betty<.*>Fred<.*>Wilma<.*>Barney</s;

    # Check links
    my $links = normalize_links('userlist.cgi', $html->{links});
    assert $links->{'userlist.cgi/name'};
    assert $links->{'userlist.cgi/rank'};
    assert $links->{'userlist.cgi/skill/rev'};
    assert $links->{'userlist.cgi/reliability'};
    assert $links->{'userlist.cgi/turns'};
    assert $links->{'userinfo.cgi/fred'};
    assert $links->{'userinfo.cgi/wilma'};
    assert $links->{'userinfo.cgi/barney'};
    assert $links->{'userinfo.cgi/betty'};
};

# Test user list by reliability.
# A: prepare users. Invoke userlist.cgi with sort by reliability.
# E: must return user list sorted by reliability.
test 'web/36_ranklist/userlist/reliability', sub {
    my $setup = shift;
    prepare($setup);

    # Fetch default sort
    my $cgi = cgi_new($setup, 'userlist.cgi');
    cgi_set_path($cgi, '/reliability');
    my $result = cgi_run($cgi);
    my $html = html_verify('userlist.cgi', $result->{text});

    # Order must be wilma > fred > betty > barney. Match HTML. Screen names are wrapped in tags.
    assert $result->{text} =~ />Wilma<.*>Fred<.*>Betty<.*>Barney</s;

    # Check links
    my $links = normalize_links('userlist.cgi/reliability', $html->{links});
    assert $links->{'userlist.cgi/name'};
    assert $links->{'userlist.cgi/rank'};
    assert $links->{'userlist.cgi/skill'};             # FIXME: should this be just /userlist.cgi?
    assert $links->{'userlist.cgi/reliability/rev'};
    assert $links->{'userlist.cgi/turns'};
    assert $links->{'userinfo.cgi/fred'};
    assert $links->{'userinfo.cgi/wilma'};
    assert $links->{'userinfo.cgi/barney'};
    assert $links->{'userinfo.cgi/betty'};
};

# Test user list by name.
# A: prepare users. Invoke userlist.cgi with sort by name.
# E: must return user list sorted by name.
test 'web/36_ranklist/userlist/name', sub {
    my $setup = shift;
    prepare($setup);

    # Fetch default sort
    my $cgi = cgi_new($setup, 'userlist.cgi');
    cgi_set_path($cgi, '/name');
    my $result = cgi_run($cgi);
    my $html = html_verify('userlist.cgi', $result->{text});

    assert $result->{text} =~ />Barney<.*>Betty<.*>Fred<.*>Wilma</s;

    my $links = normalize_links('userlist.cgi/reliability', $html->{links});
    assert $links->{'userlist.cgi/name/rev'};
    assert $links->{'userlist.cgi/rank'};
    assert $links->{'userlist.cgi/skill'};
    assert $links->{'userlist.cgi/reliability'};
    assert $links->{'userlist.cgi/turns'};
};

# Test user list by name, reversed (as specimen for reverse sort).
# A: prepare users. Invoke userlist.cgi with sort by name, reversed.
# E: must return user list sorted by name.
test 'web/36_ranklist/userlist/name/rev', sub {
    my $setup = shift;
    prepare($setup);

    # Fetch default sort
    my $cgi = cgi_new($setup, 'userlist.cgi');
    cgi_set_path($cgi, '/name/rev');
    my $result = cgi_run($cgi);
    my $html = html_verify('userlist.cgi', $result->{text});

    assert $result->{text} =~ />Wilma<.*>Fred<.*>Betty<.*>Barney</s;

    my $links = normalize_links('userlist.cgi/reliability', $html->{links});
    assert $links->{'userlist.cgi/name'};
    assert $links->{'userlist.cgi/rank'};
    assert $links->{'userlist.cgi/skill'};
    assert $links->{'userlist.cgi/reliability'};
    assert $links->{'userlist.cgi/turns'};
};

##
##  api/user.cgi
##

# Test default user list.
# A: Invoke user API ranking, no parameters.
# E: Result is list of users in order of internal Id (=creation order).
test 'web/36_ranklist/userapi/default', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking');
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, ['fred', 'barney', 'wilma', 'betty'];
};

# Test default user list, single field request.
# A: Invoke user API ranking, request single field.
# E: Result is list of users in order of internal Id (=creation order), given field only.
test 'web/36_ranklist/userapi/single', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', fields => 'screenname');
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, ['Fred', 'Barney', 'Wilma', 'Betty'];
};

# Test default user list, sort.
# A: Invoke user API ranking, sort by rank points.
# E: Result is list of users in ascending rank point order.
test 'web/36_ranklist/userapi/sort', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', sort => 'rankpoints');
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, ['barney', 'wilma', 'fred', 'betty'];
};

# Test default user list, sort reversed.
# A: Invoke user API ranking, sort by rank points reversed.
# E: Result is list of users in descending rank point order.
test 'web/36_ranklist/userapi/sort/rev', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', sort => 'rankpoints', reverse => 1);
    assert_equals $result->{result}, 1;
    assert_list_equals $result->{reply}, ['betty', 'fred', 'wilma', 'barney'];
};

# Test default user list, multiple field request.
# A: Invoke user API ranking, request multiple fields.
# E: Result is list of objects in desired order, each object containing appropriate fields.
test 'web/36_ranklist/userapi/multi', sub {
    my $setup = shift;
    prepare($setup);

    my $result = setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', sort => 'rankpoints', reverse => 1, fields => 'rank,name');
    assert_equals $result->{result}, 1;
    assert_equals $result->{reply}[0]{name}, 'betty';
    assert_equals $result->{reply}[0]{rank}, 7;
    assert_equals $result->{reply}[1]{name}, 'fred';
    assert_equals $result->{reply}[1]{rank}, 7;
    assert_equals $result->{reply}[2]{name}, 'wilma';
    assert_equals $result->{reply}[2]{rank}, 4;
    assert_equals $result->{reply}[3]{name}, 'barney';
    assert_equals $result->{reply}[3]{rank}, 0;
};

# Test default user list, errors.
# A: Invoke user API ranking with wrong field names.
# E: Must produce '400' error.
test 'web/36_ranklist/userapi/errors', sub {
    my $setup = shift;
    prepare($setup);

    assert_throws sub{ setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', sort => 'email') }, 400;
    assert_throws sub{ setup_post_api($setup, 'api/user.cgi', undef, action => 'ranking', fields => 'rank,email') }, 400;
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

    # Add some users
    my $uc = setup_connect_app($setup, 'user');
    my $db = setup_connect_app($setup, 'db');
    my $id;

    $id = conn_call($uc, 'adduser', 'fred', 'secret');
    assert_equals $id, 1001;
    conn_call($uc, 'set', $id, rankpoints => 3397, rank => 7, turnreliability => 98811, turnsmissed => 1,  turnsplayed => 348, screenname => 'Fred');
    conn_call($db, 'sadd', 'user:active', $id);

    $id = conn_call($uc, 'adduser', 'barney', 'secret');
    assert_equals $id, 1002;
    conn_call($uc, 'set', $id, rankpoints => 37,   rank => 0, turnreliability => 93788, turnsmissed => 1,  turnsplayed => 24, screenname => 'Barney');
    conn_call($db, 'sadd', 'user:active', $id);

    $id = conn_call($uc, 'adduser', 'wilma', 'secret');
    assert_equals $id, 1003;
    conn_call($uc, 'set', $id, rankpoints => 2586, rank => 4, turnreliability => 99137,                    turnsplayed => 81, screenname => 'Wilma');
    conn_call($db, 'sadd', 'user:active', $id);

    $id = conn_call($uc, 'adduser', 'betty', 'secret');
    assert_equals $id, 1004;
    conn_call($uc, 'set', $id, rankpoints => 3536, rank => 7, turnreliability => 94298, turnsmissed => 11, turnsplayed => 182, screenname => 'Betty');
    conn_call($db, 'sadd', 'user:active', $id);
}
