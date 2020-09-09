#!/usr/bin/perl -w
#
#  Test api/host.cgi
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

# cronget       =>
# cronlist      =>
# gamecheckperm =>
# gamegetvc     =>
# gamelist      => ok
# gamelstools   =>
# gamestat      => ok
# gametotals    =>
# hostls        => ok
# masterls      => ok
# playergetdir  =>
# playerjoin    => (21_playapi)
# playerls      => ok
# playerresign  =>
# playersetdir  => (21_playapi)
# playerstat    => ok
# playersubst   =>
# schedulelist  =>
# scheduleshow  =>
# shiplistls    => ok
# toolls        =>
# trn           => 14_uploadturn
# trnmarktemp   =>


# Test gamestat action.
# A: prepare a game. Invoke gamestat action.
# E: correct fully-populated result
test 'web/35_hostapi/gamestat', sub {
    my $setup = shift;
    prepare($setup);

    my $p = setup_post_api($setup, 'api/host.cgi', undef,
                           action => 'gamestat',
                           gid => 15);
    assert_equals $p->{result}, 1;
    assert_equals $p->{name}, 'Fifteen';
    assert_equals $p->{host}, 'H';
    assert_equals $p->{hostDescription}, 'The Host';
    assert_equals $p->{master}, 'M';
    assert_equals $p->{masterDescription}, 'The Master';
    assert_equals $p->{shiplist}, 'S';
    assert_equals $p->{shiplistDescription}, 'The Ship List';
    assert_list_equals $p->{slots}, ['open','open','occupied','open','occupied','open','open','open','occupied','open','open'];
    assert_equals $p->{state}, 'joining';
    assert_equals $p->{turn}, 0;
    assert_equals $p->{joinable}, 1;
    assert_equals $p->{type}, 'public';
    assert_equals $p->{id}, 15;

    assert_equals $p->{currentSchedule}{type}, 3;
    assert_equals $p->{currentSchedule}{condition}, 1;
    assert_equals $p->{currentSchedule}{condTurn}, 20;
};

# Test gamelist action.
# A: prepare a game. Invoke gamelist action.
# E: correct result depending on format parameter
test 'web/35_hostapi/gamelist', sub {
    my $setup = shift;
    prepare($setup);

    # Normal
    my $p = setup_post_api($setup, 'api/host.cgi', undef,
                           action => 'gamelist');
    assert_equals $p->{result}, 1;
    assert_equals $p->{reply}[0]{id}, 15;
    assert_equals $p->{reply}[0]{name}, 'Fifteen';
    assert_equals $p->{reply}[0]{state}, 'joining';
    assert_equals $p->{reply}[0]{currentSchedule}{type}, 3;
    assert_equals $p->{reply}[0]{currentSchedule}{condition}, 1;
    assert_equals $p->{reply}[0]{currentSchedule}{condTurn}, 20;
    assert !exists $p->{slots};

    # ID
    $p = setup_post_api($setup, 'api/host.cgi', undef,
                        action => 'gamelist',
                        'format' => 'id');        # not quoting 'format' confuses emacs' indenter. WTF?
    assert_equals $p->{result}, 1;
    assert_list_equals $p->{reply}, [15];

    # Long
    $p = setup_post_api($setup, 'api/host.cgi', undef,
                        action => 'gamelist',
                        'format' => 'long');
    assert_equals $p->{result}, 1;
    assert_equals $p->{reply}[0]{id}, 15;
    assert_equals $p->{reply}[0]{name}, 'Fifteen';
    assert_equals $p->{reply}[0]{state}, 'joining';
    assert_equals $p->{reply}[0]{currentSchedule}{type}, 3;
    assert_equals $p->{reply}[0]{currentSchedule}{condition}, 1;
    assert_equals $p->{reply}[0]{currentSchedule}{condTurn}, 20;
    assert_list_equals $p->{reply}[0]{slots}, ['open','open','occupied','open','occupied','open','open','open','occupied','open','open'];
};

# Test gamelist action with user filter.
# A: prepare multiple games. Join users. Invoke gamelist action with user filter.
# E: correct result list.
test 'web/35_hostapi/gamelist/user', sub {
    my $setup = shift;
    prepare($setup);

    # Some more games
    my $hc = setup_connect_app($setup, 'host');
    my $g1 = conn_call($hc, 'newgame');
    my $g2 = conn_call($hc, 'newgame');
    foreach ($g1, $g2) {
        conn_call($hc, 'gamesetstate', $_, 'joining');
        conn_call($hc, 'gamesettype', $_, 'public');
    }
    conn_call($hc, 'playerjoin', $g1, 4, 1001);
    conn_call($hc, 'playerjoin', $g2, 4, 1002);

    # List barney's games. Must be [15,$g2]
    my $p = setup_post_api($setup, 'api/host.cgi', undef,
                           action => 'gamelist',
                           user => 'barney',
                           'format' => 'id');
    assert_equals $p->{result}, 1;
    assert_list_equals $p->{reply}, [15,$g2];
};

# Test hostls/masterls/shiplistls actions.
# A: invoke hostls/masterls/shiplistls actions.
# E: must return correct list
test 'web/35_hostapi/xls', sub {
    my $setup = shift;
    prepare($setup);

    my $p = setup_post_api($setup, 'api/host.cgi', undef, action => 'hostls');
    assert_equals $p->{result}, 1;
    assert_equals scalar(@{$p->{reply}}), 1;
    assert_equals $p->{reply}[0]{description}, 'The Host';
    assert_equals $p->{reply}[0]{id}, 'H';

    $p = setup_post_api($setup, 'api/host.cgi', undef, action => 'shiplistls');
    assert_equals $p->{result}, 1;
    assert_equals scalar(@{$p->{reply}}), 1;
    assert_equals $p->{reply}[0]{description}, 'The Ship List';
    assert_equals $p->{reply}[0]{id}, 'S';

    $p = setup_post_api($setup, 'api/host.cgi', undef, action => 'masterls');
    assert_equals $p->{result}, 1;
    assert_equals scalar(@{$p->{reply}}), 1;
    assert_equals $p->{reply}[0]{description}, 'The Master';
    assert_equals $p->{reply}[0]{id}, 'M';
};

# Test playerls actions.
# A: prepare game, join players, invoke playerls actions.
# E: must return correct list
test 'web/35_hostapi/playerls', sub {
    my $setup = shift;
    prepare($setup);

    # Invoke as anonymous
    my $p = setup_post_api($setup, 'api/host.cgi', undef, action => 'playerls', gid => 15);
    assert_equals $p->{result}, 1;

    assert_equals $p->{1}{long}, 'Long Race 1';
    assert_equals $p->{1}{joinable}, 1;
    assert_equals $p->{1}{editable}, 0;
    assert_list_equals $p->{1}{users}, [];

    assert_equals $p->{3}{long}, 'Long Race 3';
    assert_equals $p->{3}{joinable}, 0;
    assert_equals $p->{3}{editable}, 0;
    assert_list_equals $p->{3}{users}, ['fred'];

    # Invoke as fred
    $p = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 1001), action => 'playerls', gid => 15);
    assert_equals $p->{result}, 1;

    assert_equals $p->{1}{long}, 'Long Race 1';
    assert_equals $p->{1}{joinable}, 0;
    assert_equals $p->{1}{editable}, 0;
    assert_list_equals $p->{1}{users}, [];

    assert_equals $p->{3}{long}, 'Long Race 3';
    assert_equals $p->{3}{joinable}, 0;
    assert_equals $p->{3}{editable}, 1;
    assert_list_equals $p->{3}{users}, ['fred'];
};

# Test playerstat actions.
# A: prepare game, join players, invoke playerstat actions.
# E: must return correct values
test 'web/35_hostapi/playerstat', sub {
    my $setup = shift;
    prepare($setup);

    # Fetch slot 1 as anonymous
    my $p = setup_post_api($setup, 'api/host.cgi', undef, action => 'playerstat', gid => 15, slot => 1);
    assert_equals $p->{result}, 1;
    assert_equals $p->{long}, 'Long Race 1';
    assert_equals $p->{joinable}, 1;
    assert_equals $p->{editable}, 0;
    assert_list_equals $p->{users}, [];

    # Fetch slot 1 as fred
    $p = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 1001), action => 'playerstat', gid => 15, slot => 1);
    assert_equals $p->{result}, 1;
    assert_equals $p->{long}, 'Long Race 1';
    assert_equals $p->{joinable}, 0;
    assert_equals $p->{editable}, 0;
    assert_list_equals $p->{users}, [];

    # Fetch slot 3 as fred
    $p = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 1001), action => 'playerstat', gid => 15, slot => 3);
    assert_equals $p->{result}, 1;
    assert_equals $p->{long}, 'Long Race 3';
    assert_equals $p->{joinable}, 0;
    assert_equals $p->{editable}, 1;
    assert_list_equals $p->{users}, ['fred'];

    # Fetch slot 3 as wilma
    $p = setup_post_api($setup, 'api/host.cgi', setup_make_cookie($setup, 1002), action => 'playerstat', gid => 15, slot => 3);
    assert_equals $p->{result}, 1;
    assert_equals $p->{long}, 'Long Race 3';
    assert_equals $p->{joinable}, 0;
    assert_equals $p->{editable}, 0;
    assert_list_equals $p->{users}, ['fred'];
};

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

    # Defaults
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);

    # Users
    my $uc = setup_connect_app($setup, 'user');
    assert_equals conn_call($uc, 'adduser', 'fred', 'a'), 1001;
    assert_equals conn_call($uc, 'adduser', 'barney', 'a'), 1002;
    assert_equals conn_call($uc, 'adduser', 'wilma', 'a'), 1003;

    # Host tools
    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'hostadd', 'H', '', '', 'host');
    conn_call($hc, 'hostset', 'H', 'description', 'The Host');
    conn_call($hc, 'masteradd', 'M', '', '', 'master');
    conn_call($hc, 'masterset', 'M', 'description', 'The Master');
    conn_call($hc, 'shiplistadd', 'S', '', '', 'shiplist');
    conn_call($hc, 'shiplistset', 'S', 'description', 'The Ship List');

    # Create a game #15
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'set', 'game:lastid', 14);
    my $gid = conn_call($hc, 'newgame');
    assert_equals $gid, 15;

    conn_call($hc, 'gamesettype', 15, 'public');
    conn_call($hc, 'gamesetstate', 15, 'joining');
    conn_call($hc, 'gamesetname', 15, 'Fifteen');
    conn_call($hc, 'scheduleadd', 15, 'weekly', 1);
    conn_call($hc, 'scheduleadd', 15, 'asap', 'untilturn', 20);

    conn_call($hc, 'playerjoin', 15, 3, 1001);
    conn_call($hc, 'playerjoin', 15, 5, 1002);
    conn_call($hc, 'playerjoin', 15, 9, 1003);
}
