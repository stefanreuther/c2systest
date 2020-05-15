#!/usr/bin/perl -w
#
#  Host: HostCron
#
#  Synced with TestServerHostHostCron, 20170925
#
use strict;
use c2systest;

# For now, we can only adapt testNull() which uses a null scheduler.
# The null scheduler is accessible using the command line option "-nocron".
# Other tests used a mocked scheduler which we cannot do in the final system.

test 'host/50_cron/null', sub {
    # Start
    my $setup = shift;
    setup_add_db($setup);
    setup_add_hostfile($setup);
    setup_add_userfile($setup);
    setup_add_mailout($setup);
    setup_add_talk($setup);
    setup_add_host($setup, '-nocron');
    setup_start_wait($setup);

    # Database
    # - Game 39 is broken (for the kickstart test)
    # - Games 12,39,99 must exist for the commands to go through
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd game:broken 39));
    conn_call($db, qw(sadd game:all 12));
    conn_call($db, qw(sadd game:all 39));
    conn_call($db, qw(sadd game:all 99));

    # Test
    my $hc = setup_connect_app($setup, 'host');
    my %e = conn_call_list($hc, qw(cronget 99));
    assert_equals $e{game}, 99;
    assert_equals $e{time}, 0;

    assert !conn_call_list($hc, qw(cronlist));

    # Kickstart
    assert_equals conn_call($hc, qw(cronkick 12)), 0;
    assert_equals conn_call($hc, qw(cronkick 39)), 1;
    assert_equals conn_call($db, qw(sismember game:broken 3)), 0;
};
