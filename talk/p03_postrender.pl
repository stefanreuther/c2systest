#!/usr/bin/perl -w
#
#  Performance test: post rendering (postrender, poststat)
#
#  As of August 2017, we have a huge speed advantage of c2talk-ng over c2talk-classic
#  for long postings (factor 300), probably caused by the different network implementation.
#  This makes it useful to look at long and short postings.
#

use strict;
use c2systest;

# Rendering a long posting
test 'talk/p03_postrender/long', sub {
    # Setup
    my $setup = shift;
    my $talk = setup_add_talk($setup);
    my $db = setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create a forum and a posting
    my $talkc = service_connect($talk);
    my $fid = conn_call($talkc, qw(forumadd name x));
    assert_equals $fid, 1;

    my $pid = conn_call($talkc, 'postnew', 1, 'subj', build_random_text(), 'user', 100);
    assert_equals $pid, 1;

    test_timing 'talk postrender format html', sub {
        conn_call($talkc, qw(postrender 1 format html));
    };
    test_timing 'talk postrender format forum', sub {
        conn_call($talkc, qw(postrender 1 format forum));
    };
    test_timing 'talk poststat', sub {
        conn_call($talkc, qw(poststat 1));
    };
};

# Rendering a short posting
test 'talk/p03_postrender/short', sub {
    # Setup
    my $setup = shift;
    my $talk = setup_add_talk($setup);
    my $db = setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Create a forum and a posting
    my $talkc = service_connect($talk);
    my $fid = conn_call($talkc, qw(forumadd name x));
    assert_equals $fid, 1;

    my $pid = conn_call($talkc, 'postnew', 1, 'subj', 'forum:hi', 'user', 100);
    assert_equals $pid, 1;

    test_timing 'talk postrender format html', sub {
        conn_call($talkc, qw(postrender 1 format html));
    };
    test_timing 'talk postrender format forum', sub {
        conn_call($talkc, qw(postrender 1 format forum));
    };
};


# Build a random, long posting.
# The original posting used to test this manually was a spam posting;
# we're trying to rebuild its characteristic (length, structure) somwhow using lorem ipsum.
sub build_random_text {
    my @sentences = 
        (
         'Suspendisse fermentum. ',
         'Pellentesque et arcu. ',
         'Maecenas viverra. ',
         'In consectetuer, lorem eu lobortis egestas, velit odio imperdiet eros, sit amet sagittis nunc mi ac neque. ',
         'Sed non ipsum. ',
         'Nullam venenatis gravida orci. ',
         'Curabitur nunc ante, ullamcorper vel, auctor a, aliquam at, tortor. ',
         'Etiam sodales orci nec ligula. ',
         'Sed at turpis vitae velit euismod aliquet. ',
         'Usce venenatis ligula in pede. ',
        );
    my $text = 'forum:';
    foreach (1 .. 50) {
        $text .= $sentences[$_ % 10];
        $text .= '[url=http://example.org]Link[/url]' if $_ % 7 == 0;
        $text .= "\n" if $_ % 2 == 0;
        $text .= "\n" if $_ % 6 == 0;
    }
    $text;
}
