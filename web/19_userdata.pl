#!/usr/bin/perl -w
#
#  Test api/user.cgi, data access
#
use strict;
use c2systest;
use c2service;
use c2cgitest;

# Test basic operation of userdata endpoint.
# In particular, verify consistency of the database format.
# A: preload database. Perform operations.
# E: operations are internally consistent, database behaves as expected.
test 'web/19_userdata/1', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create a user using regular mechanism
    conn_call(setup_connect_app($setup, 'file'), 'mkdir', 'u');
    my $cookie = create_user($setup, 'uu');

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    my $id = conn_call($db, qw(get uid:uu));
    assert_differs $id, '';
    assert_differs $id, '0';

    conn_call($db, "set", "user:$id:app:data:one", "First Data");
    conn_call($db, "set", "user:$id:app:data:two", "Second Data");
    conn_call($db, "set", "user:$id:app:size", 10+6+11+6);
    conn_call($db, "rpush", "user:$id:app:list", "one");
    conn_call($db, "rpush", "user:$id:app:list", "two");

    # Access data (get)
    # - first key
    my $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'get', key => 'one');
    assert $result;
    assert_equals $result->{value}, 'First Data';

    # - second key
    $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'get', key => 'two');
    assert $result;
    assert_equals $result->{value}, 'Second Data';

    # - undefined key
    # Difference: initial implementation produces undef, new implementation produces ''
    $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'get', key => 'three');
    assert $result;
    assert !$result->{value} || $result->{value} eq '';

    # Update
    setup_post_api($setup, 'api/user.cgi', $cookie, action => 'set', key => 'one',  value => '');
    setup_post_api($setup, 'api/user.cgi', $cookie, action => 'set', key => 'four', value => 'Final Value');

    # Check
    $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'get', key => 'one');
    assert $result;
    assert_equals $result->{value}, '';

    $result = setup_post_api($setup, 'api/user.cgi', $cookie, action => 'get', key => 'four');
    assert $result;
    assert_equals $result->{value}, 'Final Value';

    # Check database
    assert_equals conn_call($db, "get", "user:$id:app:data:four"), 'Final Value';
};

# Test basic operation of userdata endpoint, second part.
# In particular, verify consistency of the database format.
# A: preload database. Perform operations.
# E: operations are internally consistent, database behaves as expected.
test 'web/19_userdata/2', sub {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);

    # Create a user using regular mechanism
    conn_call(setup_connect_app($setup, 'file'), 'mkdir', 'u');
    my $cookie = create_user($setup, 'uu');

    # Preload database
    my $db = setup_connect_app($setup, 'db');
    my $id = conn_call($db, qw(get uid:uu));
    assert_differs $id, '';
    assert_differs $id, '0';

    conn_call($db, "set", "user:$id:app:data:one", "First Data");
    conn_call($db, "set", "user:$id:app:data:two", "Second Data");
    conn_call($db, "set", "user:$id:app:size", 10+6+11+6);
    conn_call($db, "rpush", "user:$id:app:list", "one");
    conn_call($db, "rpush", "user:$id:app:list", "two");

    # Set value using API
    setup_post_api($setup, 'api/user.cgi', $cookie, action => 'set', key => 'three',  value => 'Third Value');

    assert_equals conn_call($db, "get", "user:$id:app:data:three"), 'Third Value';
    assert_list_equals conn_call($db, "lrange", "user:$id:app:list", 0, -1), ['three', 'one', 'two'];
    assert_equals conn_call($db, "get", "user:$id:app:size"), 10+6+11+6+11+10;
};




# Create a user.
sub create_user {
    my $setup = shift;
    my $username = shift;

    my $cgi = cgi_new($setup, "signup.cgi");
    cgi_set_post_params($cgi, username => $username, realname => $username, pass1 => "a", pass2 => "a", terms => "read", nerf => "ok");
    my $result = cgi_run($cgi);
    my $cookie = '';
    foreach (@{$result->{cookies}}) {
        if (/^(session=[^;]*)/) {
            $cookie = $1;
        }
    }
    assert_differs($cookie, '');

    $cookie;
}
