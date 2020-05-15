#!/usr/bin/perl -w
#
#  Router: failure to start
#
use strict;
use c2systest;

# Test failure to start due to misconfigured path.
# Create a router that has ROUTER.SERVER configured wrong.
# Session creation must fail with error 403 (failure cause does not leak to user).
test 'router/03_failure/path', sub {
    # Config
    my $setup = shift;
    setup_add_service_config($setup, 'router.filenotify' => 0);
    setup_add_service_config($setup, 'router.server', '/does/not/exist');

    # Start
    my $rs = setup_add_router($setup);
    setup_start($setup);

    assert_starts_with service_call_raw($rs, "NEW foo\n"), 403;
};

# Test failure to start due to missing game data or wrong command line
# Create a correctly-configured router. Use invalid command lines to create sessions.
# Session creation must fail with error 403 (failure cause does not leak to user).
test 'router/03_failure/game', sub {
    # Config
    my $setup = shift;
    setup_add_service_config($setup, 'router.filenotify' => 0);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));

    # Start
    my $rs = setup_add_router($setup);
    setup_start($setup);

    assert_starts_with service_call_raw($rs, "NEW --help\n"), 403;
    assert_starts_with service_call_raw($rs, "NEW /does/not/exist\n"), 403;
    assert_starts_with service_call_raw($rs, "NEW /does/not/exist 3\n"), 403;
};
