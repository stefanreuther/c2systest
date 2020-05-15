#!/usr/bin/perl -w
#
#  Test api/play.cgi
#
use strict;
use c2systest;
use c2service;
use c2cgitest;

# Test user using the demo session
# - Create user
# - Create demo session
# - Verify that we can access data
# - Verify that we can close the session
test 'web/20_playapi/user_demo', sub {
    my $setup = shift;
    prepare($setup);
    my $cookie = create_user($setup, 'uu');

    # Create demo session
    my $new_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'new', dir => 'd/tim', player => 11);
    assert $new_result->{sid};

    # Obtain data
    my $data_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'get', sid => $new_result->{sid}, path => 'obj/main');
    assert_equals $data_result->{data}{main}{TURN}, 117;
    assert_equals $data_result->{data}{main}{'TURN.DATE'}, '01-12-1996';

    # Close session
    setup_post_api($setup, "api/play.cgi", $cookie, action => 'close', sid => $new_result->{sid});

    # This will fail now (result=0).
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", $cookie, action => 'get', sid => $new_result->{sid}, path => 'obj/main'); };
};

# Test anonymous user using the demo session
# - Create demo session without user cookie
# - Verify that we can access data
# - Verify that we can close the session
test 'web/20_playapi/anon_demo', sub {
    my $setup = shift;
    prepare($setup);

    # Create demo session
    my $new_result = setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11);
    assert $new_result->{sid};

    # Obtain data
    my $data_result = setup_post_api($setup, "api/play.cgi", undef, action => 'get', sid => $new_result->{sid}, path => 'obj/main');
    assert_equals $data_result->{data}{main}{TURN}, 117;
    assert_equals $data_result->{data}{main}{'TURN.DATE'}, '01-12-1996';

    # Close session
    setup_post_api($setup, "api/play.cgi", undef, action => 'close', sid => $new_result->{sid});

    # This will fail now (result=0).
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'get', sid => $new_result->{sid}, path => 'obj/main'); };
};

# Test fail-safe mode.
# Create session while ROUTER.SESSIONID=numeric.
# This must fail with error 500.
test 'web/20_playapi/fail_sid', sub {
    my $setup = shift;
    prepare($setup, "router.sessionid" => "numeric");
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11) }, 500;
};

# Test misconfiguration.
# Create session while ROUTER.SERVER points at wrong program.
# This must fail with error 403.
test 'web/20_playapi/fail_misconf', sub {
    my $setup = shift;
    prepare($setup, "router.server" => "asoidu2q309872398asloiu");
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11) }, 403;
};

# Test misconfiguration.
# Create session while ROUTER.SERVER points at wrong program.
# This must fail with error 403.
test 'web/20_playapi/fail_misconf/false', sub {
    my $setup = shift;
    prepare($setup, "router.server" => "/bin/false");
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11) }, 403;
};

# Test misconfiguration.
# Create session while ROUTER.SERVER points at wrong program.
# This must fail with error 403.
test 'web/20_playapi/fail_misconf/true', sub {
    my $setup = shift;
    prepare($setup, "router.server" => "/bin/true");
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11) }, 403;
};

# Test wrong path.
# Create session with path that does not contain game data.
# This must fail with error 403.
test 'web/20_playapi/fail_path', sub {
    my $setup = shift;
    prepare($setup);
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd', player => 11) }, 403;
};

# Test wrong path.
# Create session with path that does not exist.
# This must fail with error 403.
test 'web/20_playapi/fail_path', sub {
    my $setup = shift;
    prepare($setup);
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/nx', player => 11) }, 403;
};

# Test wrong player number.
# Create session with wrong player.
# This must fail with error 404 (player not found).
test 'web/20_playapi/fail_player', sub {
    my $setup = shift;
    prepare($setup);
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 9) }, 404;
};

# Test wrong player number.
# Create session with wrong player.
# This must fail with error 404 (player not found).
test 'web/20_playapi/fail_player2', sub {
    my $setup = shift;
    prepare($setup);
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 99999999) }, 404;
};

# Test close abuse.
# - Create demo session without user cookie
# - Verify that we can access data
# - Verify that we can close the session
test 'web/20_playapi/close_abuse', sub {
    my $setup = shift;
    prepare($setup);

    # Create demo session
    my $new_result = setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'd/tim', player => 11);

    # Bogus close
    eval { setup_post_api($setup, "api/play.cgi", undef, action => 'close', sid => '-WDEMO'); };

    # Data still accessible
    my $data_result = setup_post_api($setup, "api/play.cgi", undef, action => 'get', sid => $new_result->{sid}, path => 'obj/main');
    assert_equals $data_result->{data}{main}{TURN}, 117;

    # Close through router
    service_call_raw(setup_get_service($setup, 'router'), "CLOSE -WDEMO\n");

    # This will fail now (result=0).
    assert_throws sub{ setup_post_api($setup, "api/play.cgi", undef, action => 'get', sid => $new_result->{sid}, path => 'obj/main'); };
};

# Test user using their own data
# - Create user
# - Create file
# - Create session
# Must succeed.
test 'web/20_playapi/user_file', sub {
    my $setup = shift;
    prepare($setup);
    my $cookie = create_user($setup, 'uu');

    my $ufc = setup_connect_app($setup, 'file');
    my $in = c2service::setup_get_init_scripts($setup);
    conn_call($ufc, 'mkdir',   'u/uu/g');
    conn_call($ufc, 'put',     'u/uu/g/player11.rst', file_content("$in/d/tim/player11.rst"));
    conn_call($ufc, 'put',     'u/uu/g/fizz.bin',     file_content("$in/r/unreg/fizz.bin"));

    # Create session
    my $new_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'new', dir => 'u/uu/g', player => 11);
    assert $new_result->{sid};

    # Obtain data
    my $data_result = setup_post_api($setup, "api/play.cgi", $cookie, action => 'get', sid => $new_result->{sid}, path => 'obj/main');
    assert_equals $data_result->{data}{main}{TURN}, 117;
};

# Test user using others' data
# - Create users
# - Create file
# - Create session for other user's data
# Must fail.
test 'web/20_playapi/fail_perm', sub {
    my $setup = shift;
    prepare($setup);
    my $cookie1 = create_user($setup, 'uu');
    my $cookie2 = create_user($setup, 'xx');

    my $ufc = setup_connect_app($setup, 'file');
    my $in = c2service::setup_get_init_scripts($setup);
    conn_call($ufc, 'mkdir',   'u/uu/g');
    conn_call($ufc, 'put',     'u/uu/g/player11.rst', file_content("$in/d/tim/player11.rst"));
    conn_call($ufc, 'put',     'u/uu/g/fizz.bin',     file_content("$in/r/unreg/fizz.bin"));

    assert_throws sub{ setup_post_api($setup, "api/play.cgi", $cookie2, action => 'new', dir => 'u/uu/g', player => 11) }, 403;
};

# Test user with missing registration.
# - Create user
# - Create file
# - Create session
# Must fail.
test 'web/20_playapi/fail_reg', sub {
    my $setup = shift;
    prepare($setup);
    my $cookie = create_user($setup, 'uu');

    my $ufc = setup_connect_app($setup, 'file');
    my $in = c2service::setup_get_init_scripts($setup);
    conn_call($ufc, 'mkdir',   'u/uu/g');
    conn_call($ufc, 'put',     'u/uu/g/player11.rst', file_content("$in/d/tim/player11.rst"));

    assert_throws sub{ setup_post_api($setup, "api/play.cgi", $cookie, action => 'new', dir => 'u/uu/g', player => 11) }, 404;
};

# Test user using their own data, API login.
# - Create user
# - Create file
# - Create session without cookie, but with username and password.
# Must succeed. Data access must also succeed without cookie.
test 'web/20_playapi/user_login', sub {
    my $setup = shift;
    prepare($setup);
    create_user($setup, 'uu');

    my $ufc = setup_connect_app($setup, 'file');
    my $in = c2service::setup_get_init_scripts($setup);
    conn_call($ufc, 'mkdir',   'u/uu/g');
    conn_call($ufc, 'put',     'u/uu/g/player11.rst', file_content("$in/d/tim/player11.rst"));
    conn_call($ufc, 'put',     'u/uu/g/fizz.bin',     file_content("$in/r/unreg/fizz.bin"));

    # Create session
    my $new_result = setup_post_api($setup, "api/play.cgi", undef, action => 'new', dir => 'u/uu/g', player => 11, api_user => "uu", api_password => "a");
    assert $new_result->{sid};

    # Obtain data
    my $data_result = setup_post_api($setup, "api/play.cgi", undef, action => 'get', sid => $new_result->{sid}, path => 'obj/main');
    assert_equals $data_result->{data}{main}{TURN}, 117;
};




################################ Utilities ################################


sub prepare {
    my $setup = shift;

    # Add router first. The framewirk will stop services in the same order as they are added.
    # A stopping router will try to notify the file server; if that one's already gone, it will wait for timeout.
    setup_add_router($setup);
    setup_add_db($setup);
    setup_add_userfile($setup, 'auto');
    setup_add_usermgr($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_add_service_config($setup,
                             'router.server' => setup_get_required_system_config($setup, 'c2server.path'),
                             'router.sessionid' => 'random',
                             @_);
    setup_start_wait($setup);
    c2service::setup_db_init($setup);
    c2service::setup_talk_init($setup);

    # Preload
    my $in = c2service::setup_get_init_scripts($setup);
    my $ufc = setup_connect_app($setup, 'file');
    conn_call($ufc, 'mkdir',   'u');
    conn_call($ufc, 'mkdir',   'd');
    conn_call($ufc, 'mkdir',   'd/tim');
    conn_call($ufc, 'put',     'd/tim/player11.rst', file_content("$in/d/tim/player11.rst"));
    conn_call($ufc, 'put',     'd/tim/fizz.bin',     file_content("$in/r/unreg/fizz.bin"));
    conn_call($ufc, 'setperm', 'd',     '*', 'r');
    conn_call($ufc, 'setperm', 'd/tim', '*', 'r');
}

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
