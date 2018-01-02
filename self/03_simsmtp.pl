#!/usr/bin/perl -w
#
#  Test the SMTP simulator
#
use strict;
use c2systest;

test '03_simsmtp', sub {
    my $setup = shift;
    my $smtps = setup_add_simsmtp($setup);
    setup_start_wait($setup);

    my $smtp = setup_connect_app($setup, 'smtp');
    assert_starts_with conn_interact($smtp, undef),      '220';
    assert_starts_with conn_interact($smtp, 'HELO ich'), '250';
    assert_starts_with conn_interact($smtp, 'MAIL FROM:<sender@invalid>'), '250';
    assert_starts_with conn_interact($smtp, 'RCPT TO:<receiver@invalid>'), '250';
    assert_starts_with conn_interact($smtp, 'DATA'), '354';
    assert_starts_with conn_interact($smtp, "content\r\n."), '250';
    assert_starts_with conn_interact($smtp, 'QUIT'), '221';

    # The first real SMTP transaction will be smtp2.
    # smtp1 will be empty, representing the initial connection check by setup_start_wait().
    assert_equals file_content(setup_get_tmpfile_name($setup, 'smtp2')),
        "HELO ich\n".
        "MAIL FROM:<sender\@invalid>\n".
        "RCPT TO:<receiver\@invalid>\n".
        "DATA\n".
        "content\n".
        ".\n".
        "QUIT\n";
};
