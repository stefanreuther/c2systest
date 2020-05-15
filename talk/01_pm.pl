#!/usr/bin/perl -w
#
#  talk: PM check
#

use c2systest;
use strict;

test 'talk/01_pm', sub {
    my $setup = shift;
    my $db = setup_add_db($setup);
    my $talk = setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_start($setup);

    # Create users
    my $dbc = service_connect_wait($db);
    conn_call($dbc, qw(set uid:a 1001));
    conn_call($dbc, qw(set uid:b 1002));
    conn_call($dbc, qw(sadd user:all 1001));
    conn_call($dbc, qw(sadd user:all 1002));
    conn_call($dbc, qw(hset user:1001:profile email a@invalid));
    conn_call($dbc, qw(hset user:1002:profile email b@invalid));
    conn_call($dbc, qw(sadd default:folder:all 1));
    conn_call($dbc, qw(sadd default:folder:all 2));

    # Send PMs
    my $talkc = service_connect_wait($talk);
    conn_call($talkc, qw(user 1001));
    conn_call($talkc, qw(pmnew u:1002 subj text));
    conn_call($talkc, qw(pmnew u:1002 subj text));

    # Verify user 1002's state
    $talkc = service_connect_wait($talk);
    conn_call($talkc, qw(user 1002));
    my %stat = @{ conn_call($talkc, qw(folderstat 1)) };

    assert_num_greater $stat{unread}, 0;
    assert_num_equals  $stat{messages}, 2;
};
