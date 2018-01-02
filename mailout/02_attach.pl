#!/usr/bin/perl -w
#
#  Test basic message sending
#

use strict;
use c2systest;

# Send a simple message. 
# This is basically TestServerMailoutTemplate::testAttachment, but tests not just the templater, but the whole system.
test 'mailout/02_attach', sub {
    # Setup
    my $setup = shift;
    my $template_dir = setup_get_tmpfile_name($setup, 'tpl');
    setup_add_db($setup);
    setup_add_mailout($setup, 1);
    setup_add_simsmtp($setup);
    my $fs = setup_add_userfile($setup);
    setup_add_service_config($setup, 'mailout.templatedir', $template_dir);
    setup_add_service_config($setup, 'smtp.fqdn', 'origin.host');
    setup_add_service_config($setup, 'smtp.from', 'sender@invalid');

    # - Prepare a template
    mkdir $template_dir, 0777 or die;
    file_put("$template_dir/test-tpl", join('',
                                            "Subject: read this!\n",
                                            "\n",
                                            "Body\n"));

    # - Start system
    setup_start_wait($setup);

    # - Add a user
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, qw(sadd uid:all 1023));
    conn_call($db, qw(set uid:zu 1023));
    conn_call($db, qw(set user:1023:name zu));
    conn_call($db, qw(hset user:1023:profile email user@ema.il.invalid));
    conn_call($db, qw(hset email:user@ema.il.invalid:status status/1023 c));

    # - Add a file
    my $fc = service_connect($fs);
    conn_call($fc, qw(mkdiras dir 1023));
    conn_call($fc, 'put', 'dir/file.jpg', 'file content');

    # - Build URL for file
    my $url = sprintf('c2file://127.0.0.1:%d/dir/file.jpg', service_get_port($fs));

    # Send a message
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, qw(MAIL test-tpl));
    conn_call($mc, 'ATTACH', $url);
    conn_call($mc, qw(SEND user:1023));

    # Wait
    my $file_name = setup_get_tmpfile_name($setup, 'smtp2');
    file_wait($file_name);

    # Verify content
    assert_equals(file_content($file_name),
                  join('',
                       "HELO origin.host\n",
                       "MAIL FROM:<sender\@invalid>\n",
                       "RCPT TO:<user\@ema.il.invalid>\n",
                       "DATA\n",
                       "Content-Type: multipart/mixed; boundary=000\n",
                       "Subject: read this!\n",
                       "To: user\@ema.il.invalid\n",
                       "\n",
                       "--000\n",
                       "Content-Type: text/plain; charset=UTF-8\n",
                       "Content-Disposition: inline\n",
                       "Content-Transfer-Encoding: quoted-printable\n",
                       "\n",
                       "Body\n",
                       "--000\n",
                       "Content-Type: image/jpeg\n",
                       "Content-Disposition: attachment; filename=\"file.jpg\"\n",
                       "Content-Transfer-Encoding: base64\n",
                       "\n",
                       "ZmlsZSBjb250ZW50\n",
                       "--000--\n",
                       ".\n",
                       "QUIT\n"));
};
