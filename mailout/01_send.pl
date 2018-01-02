#!/usr/bin/perl -w
#
#  Test basic message sending
#

use strict;
use c2systest;

# Send a simple message. 
# This is basically TestServerMailoutTemplate::testSimple, but tests not just the templater, but the whole service.
test 'mailout/01_send', sub {
    my $setup = shift;
    my $template_dir = setup_get_tmpfile_name($setup, 'tpl');
    setup_add_db($setup);
    setup_add_mailout($setup, 1);
    setup_add_simsmtp($setup);
    setup_add_service_config($setup, 'mailout.templatedir', $template_dir);
    setup_add_service_config($setup, 'smtp.fqdn', 'origin.host');
    setup_add_service_config($setup, 'smtp.from', 'sender@invalid');

    mkdir $template_dir, 0777 or die;
    file_put("$template_dir/test-tpl", join('',
                                            "From: me\n",
                                            "Subject: read this!\n",
                                            "\n",
                                            "Value is \$(v)\n"));

    setup_start_wait($setup);

    # Send a message
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(MAIL test-tpl));
    conn_call($mc, qw(PARAM v 42));
    conn_call($mc, qw(SEND mail:rx@host.invalid));

    # Wait
    my $file_name = setup_get_tmpfile_name($setup, 'smtp2');
    file_wait($file_name);

    # Verify content
    assert_equals(file_content($file_name),
                  join('',
                       "HELO origin.host\n",
                       "MAIL FROM:<sender\@invalid>\n",
                       "RCPT TO:<rx\@host.invalid>\n",
                       "DATA\n",
                       "From: me\n",
                       "Subject: read this!\n",
                       "To: rx\@host.invalid\n",
                       "Content-Type: text/plain; charset=UTF-8\n",
                       "Content-Transfer-Encoding: quoted-printable\n",
                       "\n",
                       "Value is 42\n",
                       ".\n",
                       "QUIT\n"));
};
