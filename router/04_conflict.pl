#!/usr/bin/perl -w
#
#  Router: conflict resolution
#
use strict;
use c2systest;

# Test ROUTER.NEWSESSIONSWIN = 0.
# Create conflicting sessions. Conflicts must be resolved in a way that the old session stays.
test 'router/04_conflict/old', sub {
    # Config
    my $setup = shift;
    setup_add_service_config($setup, 'router.filenotify' => 0);
    setup_add_service_config($setup, 'router.newsessionswin' => 0);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));

    # Prepare directory
    my $gamedir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $gamedir, 0777 or die;
    file_put("$gamedir/player3.rst", file_content('data/game/player3.rst'));

    # Start
    my $rs = setup_add_router($setup);
    setup_start($setup);

    # Create two reader sessions which must be able to coexist
    my $s1 = parse_session(service_call_raw($rs, "NEW -RMARK $gamedir 3\n"));
    my $s2 = parse_session(service_call_raw($rs, "NEW -RMARK $gamedir 3\n"));
    assert_differs $s1, $s2;
    assert_starts_with service_call_raw($rs, "S $s1\nGET obj/main\n"), 200;
    assert_starts_with service_call_raw($rs, "S $s2\nGET obj/main\n"), 200;

    # Try to create writer session. Must fail; old sessions remain.
    assert_starts_with service_call_raw($rs, "NEW -WMARK $gamedir 3\n"), 453;
    assert_starts_with service_call_raw($rs, "S $s1\nGET obj/main\n"), 200;
    assert_starts_with service_call_raw($rs, "S $s2\nGET obj/main\n"), 200;

    # Close readers using bulk op. Must now be gone.
    assert_starts_with service_call_raw($rs, "CLOSE -WMARK\n"), 200;
    assert_starts_with service_call_raw($rs, "S $s1\nGET obj/main\n"), 452;
    assert_starts_with service_call_raw($rs, "S $s2\nGET obj/main\n"), 452;

    # Create writer session. Must now succeed, but a second writer or another reader must fail.
    my $s3 = parse_session(service_call_raw($rs, "NEW -WMARK $gamedir 3\n"));
    assert_starts_with service_call_raw($rs, "NEW -WMARK $gamedir 3\n"), 453;
    assert_starts_with service_call_raw($rs, "NEW -RMARK $gamedir 3\n"), 453;
};

# Test ROUTER.NEWSESSIONSWIN = 1.
# Create conflicting sessions. Conflicts must be resolved in a way that the new session is opened.
test 'router/04_conflict/new', sub {
    # Config
    my $setup = shift;
    setup_add_service_config($setup, 'router.filenotify' => 0);
    setup_add_service_config($setup, 'router.newsessionswin' => 1);
    setup_add_service_config($setup, 'router.server', setup_get_required_system_config($setup, 'c2server.path'));

    # Prepare directory
    my $gamedir = setup_get_tmpfile_name($setup, 'gd');
    mkdir $gamedir, 0777 or die;
    file_put("$gamedir/player3.rst", file_content('data/game/player3.rst'));

    # Start
    my $rs = setup_add_router($setup);
    setup_start($setup);

    # Create two reader sessions which must be able to coexist
    my $s1 = parse_session(service_call_raw($rs, "NEW -RMARK $gamedir 3\n"));
    my $s2 = parse_session(service_call_raw($rs, "NEW -RMARK $gamedir 3\n"));
    assert_differs $s1, $s2;
    assert_starts_with service_call_raw($rs, "S $s1\nGET obj/main\n"), 200;
    assert_starts_with service_call_raw($rs, "S $s2\nGET obj/main\n"), 200;

    # Try to create writer session. Must succeed and kill the old sessions.
    my $s3 = parse_session(service_call_raw($rs, "NEW -WMARK $gamedir 3\n"));

    assert_starts_with service_call_raw($rs, "S $s1\nGET obj/main\n"), 452;
    assert_starts_with service_call_raw($rs, "S $s2\nGET obj/main\n"), 452;
    assert_starts_with service_call_raw($rs, "S $s3\nGET obj/main\n"), 200;

    # Create another writer session. Must succeed.
    my $s4 = parse_session(service_call_raw($rs, "NEW -WMARK $gamedir 3\n"));
    assert_starts_with service_call_raw($rs, "S $s3\nGET obj/main\n"), 452;
    assert_starts_with service_call_raw($rs, "S $s4\nGET obj/main\n"), 200;

    # Creating a reader also succeeds and kicks the writer.
    my $s5 = parse_session(service_call_raw($rs, "NEW -RMARK $gamedir 3\n"));
    assert_starts_with service_call_raw($rs, "S $s4\nGET obj/main\n"), 452;
    assert_starts_with service_call_raw($rs, "S $s5\nGET obj/main\n"), 200;
};


sub parse_session {
    my $x = shift;
    assert $x =~ /^201 (\S+) /;
    $1;
}
