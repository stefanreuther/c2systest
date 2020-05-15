#!/usr/bin/perl -w
#
#  Test RANKLIST command
#  - userlist.cgi
#  - api/user.cgi
#
use strict;
use c2systest;
use c2service;

# Test default result.
# A: Call RANKLIST without parameters.
# E: Returns list in user Id (creation) order.
test 'host/23_ranklist/default', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', 'anon');

    my @list = conn_call_list($hc, 'ranklist');
    assert_equals scalar(@list), 8;
    assert_equals      $list[0], 1001;
    assert_list_equals $list[1], [];
    assert_equals      $list[2], 1002;
    assert_list_equals $list[3], [];
    assert_equals      $list[4], 1003;
    assert_list_equals $list[5], [];
    assert_equals      $list[6], 1004;
    assert_list_equals $list[7], [];
};

# Test sorting by field.
# A: Call RANKLIST with SORT clause.
# E: Returns list in sorted order.
test 'host/23_ranklist/sort', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', 'anon');

    my @list = conn_call_list($hc, 'ranklist', 'sort', 'rankpoints');
    assert_equals scalar(@list), 8;
    assert_equals $list[0], 1002;
    assert_equals $list[2], 1003;
    assert_equals $list[4], 1001;
    assert_equals $list[6], 1004;
};

# Test sorting by field, reversed.
# A: Call RANKLIST with SORT, REVERSE clauses.
# E: Returns list in reverse-sorted order.
test 'host/23_ranklist/sort/rev', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', 'anon');

    my @list = conn_call_list($hc, 'ranklist', 'sort', 'rankpoints', 'reverse');
    assert_equals scalar(@list), 8;
    assert_equals $list[0], 1004;
    assert_equals $list[2], 1001;
    assert_equals $list[4], 1003;
    assert_equals $list[6], 1002;
};

# Test field request.
# A: Call RANKLIST with FIELDS clause.
# E: Returns list with populated attribute sub-lists.
test 'host/23_ranklist/fields', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', 'anon');

    my @list = conn_call_list($hc, 'ranklist', 'sort', 'rankpoints', 'fields', 'name', 'screenname');
    assert_equals scalar(@list), 8;

    assert_equals      $list[0], 1002;
    assert_list_equals $list[1], ['barney', 'Barney'];
    assert_equals      $list[2], 1003;
    assert_list_equals $list[3], ['wilma', 'Wilma'];
    assert_equals      $list[4], 1001;
    assert_list_equals $list[5], ['fred', 'Fred'];
    assert_equals      $list[6], 1004;
    assert_list_equals $list[7], ['betty', 'Betty'];
};

# Test error cases.
# A: Call RANKLIST with invalid field names.
# E: Must produce '400' error.
test 'host/23_ranklist/errors', sub {
    my $setup = shift;
    prepare($setup);

    my $hc = setup_connect_app($setup, 'host');
    conn_call($hc, 'user', 'anon');

    assert_throws sub{ conn_call($hc, 'ranklist', 'sort', 'email') }, 400;
    assert_throws sub{ conn_call($hc, 'ranklist', 'fields', 'email') }, 400;
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
