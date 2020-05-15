#!/usr/bin/perl -w
#
#  Simulator application test
#
use strict;
use c2systest;
use c2cgitest;
use c2service;

# Test simulator application CGI for a user.
# A: create a user and a ship list
# E: CGI must produce correct output and honor user's language configuration
test 'web/26_sim/user', sub {
    my $setup = shift;
    prepare($setup);

    # Add and configure user
    my $uc = setup_connect_app($setup, 'user');
    my $id = conn_call($uc, 'adduser', 'joe', 'secret');
    my $cookie = setup_make_cookie($setup, $id);
    conn_call($uc, 'set', $id, 'language', 'de');

    # Retrieve list
    my $list = cgi_new($setup, 'play/sim.cgi');
    cgi_add_cookie($list, $cookie);
    my $list_result = cgi_run($list);
    my $list_html = cgi_verify_result($list, $list_result);

    # - needs to have a link to SomeList
    #   Accept "../play/sim.cgi", "/play/sim.cgi", and "sim.cgi"
    assert grep {m!^((..|)/play/)?sim.cgi\?shiplist=SomeList!} keys %{$list_html->{links}};

    # Retrieve app
    my $app = cgi_new($setup, 'play/sim.cgi');
    cgi_set_get_params($app, shiplist => 'SomeList');
    cgi_add_cookie($app, $cookie);
    my $app_result = cgi_run($app);
    my $app_html = cgi_verify_result($app, $app_result);

    assert grep {m!^de\..*js$!} keys %{$app_html->{scripts}};
    assert_contains $app_result->{text}, 'data-shiplist="SomeList"';
};

# Test simulator application CGI for a non-user.
# A: create a ship list
# E: CGI must produce correct output
test 'web/26_sim/anon', sub {
    my $setup = shift;
    prepare($setup);

    # Retrieve list
    my $list = cgi_new($setup, 'play/sim.cgi');
    my $list_result = cgi_run($list);
    my $list_html = cgi_verify_result($list, $list_result);

    # - needs to have a link to SomeList
    #   Accept "../play/sim.cgi", "/play/sim.cgi", and "sim.cgi"
    assert grep {m!^((..|)/play/)?sim.cgi\?shiplist=SomeList!} keys %{$list_html->{links}};

    # Retrieve app
    my $app = cgi_new($setup, 'play/sim.cgi');
    cgi_set_get_params($app, shiplist => 'SomeList');
    my $app_result = cgi_run($app);
    my $app_html = cgi_verify_result($app, $app_result);

    assert grep {m!^en\..*js$!} keys %{$app_html->{scripts}};
    assert_contains $app_result->{text}, 'data-shiplist="SomeList"';
};

# Test simulator application CGI with language auto-detection
# A: create a ship list
# E: CGI must produce correct output
test 'web/26_sim/anon/auto', sub {
    my $setup = shift;
    prepare($setup);

    # Retrieve app
    # Accept-Language header example taken from MDN.
    # As of 20190324, we don't have a French language file, so this detects as German.
    my $app = cgi_new($setup, 'play/sim.cgi');
    cgi_set_get_params($app, shiplist => 'SomeList');
    cgi_set_language($app, 'fr-CH, fr;q=0.9, de;q=0.7, *;q=0.5');
    my $app_result = cgi_run($app);
    my $app_html = cgi_verify_result($app, $app_result);

    assert grep {m!^de\..*js$!} keys %{$app_html->{scripts}};
    assert_contains $app_result->{text}, 'data-shiplist="SomeList"';
};


sub prepare {
    # System setup
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_add_host($setup);
    setup_add_talk($setup);
    setup_start_wait($setup);

    # Add ship list
    my $prog = setup_get_required_system_config($setup, 'programs');
    c2service::setup_db_init($setup);
    c2service::setup_hostfile_add_defaults($setup);
    c2service::setup_hostfile_add_default_scripts($setup);
    c2service::setup_host_add_shiplist($setup, 'SomeList', "$prog/plist-3.2", 'plist');
}
