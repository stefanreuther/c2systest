#!/usr/bin/perl -w
#
#  Performance test: postnew
#
#  This tests a performance bottleneck in the RESP client.
#  Whereas the "small" test takes <1ms in -ng and -classic, the "large" version took around 40ms.
#  The fixed version brings both down to <1ms.
#
#  We must make sure that the RESP client sends a request in one request.
#  Otherwise, it may receive a 40 ms penalty/late ack.
#
#  That problem mostly troubles the copy-in/out host implementation which is harder to performance-test.
#
use strict;
use c2systest;

test 'talk/p08_post/large', sub {
    my $setup = shift;
    do_test($setup, 'talk post large', 'Lorem ipsum dolor sit amet, consectetuer adipiscing elit. ' x 60);
};

test 'talk/p08_post/small', sub {
    my $setup = shift;
    do_test($setup, 'talk post small', 'a');
};

sub do_test {
    my ($setup, $title, $text) = @_;

    # Setup
    setup_add_talk($setup);
    setup_add_db($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);

    # Add a forum
    my $tc = setup_connect_app($setup, 'talk');
    my $fid = conn_call($tc, qw(forumadd name First));

    # Repeatedly post 100 postings into a thread and remove them again
    test_timing $title, sub {
        conn_call($tc, 'postrm', conn_call($tc, 'postnew', $fid, 'subj', $text, 'USER', 'a'));
    };
}
