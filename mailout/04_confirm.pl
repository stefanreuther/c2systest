#!/usr/bin/perl -w
#
#  Test mail confirmation
#
#  Send a mail to an unconfirmed email address.
#  This must generate a confirmation request.
#  Confirming that must send the queued mail.
#

use strict;
use c2systest;

test 'mailout/04_confirm', sub {
    # Services
    my $setup = shift;
    my $template_dir = setup_get_tmpfile_name($setup, 'tpl');
    setup_add_db($setup);
    setup_add_mailout($setup, 1);
    setup_add_simsmtp($setup);
    setup_add_service_config($setup, 'smtp.from', 'fr@m');
    setup_add_service_config($setup, 'smtp.fqdn', 'fqdn');
    setup_add_service_config($setup, 'mailout.templatedir', $template_dir);
    setup_add_service_config($setup, 'www.url', 'http://url/');
    setup_add_service_config($setup, 'www.key', 'xyzzy');

    # Template
    mkdir $template_dir, 0777 or die;
    file_put("$template_dir/msg", "Subject: \$(subj)\n\n\$(body)\n");
    file_put("$template_dir/confirm", "Subject: confirm\n\nLink: \$(confirmlink)");

    # Start
    setup_start_wait($setup);

    # Configure a user
    my $db = setup_connect_app($setup, 'db');
    conn_call($db, 'sadd', 'user:all', '1209');
    conn_call($db, 'set', 'uid:zz', '1209');
    conn_call($db, 'set', 'user:1209:name', 'zz');
    conn_call($db, 'hset', 'user:1209:profile', 'email', 'zz@yy.xxx');

    # Send a message to the user
    my $mc = setup_connect_app($setup, 'mailout');
    conn_call($mc, 'mail', 'msg');
    conn_call($mc, 'param', 'subj', 'Mail Subject');
    conn_call($mc, 'param', 'body', 'Mail Body');
    conn_call($mc, 'send', 'user:1209');

    # This must produce a confirmation request
    my $file_name = setup_get_tmpfile_name($setup, 'smtp2');
    file_wait($file_name);

    assert_equals file_content($file_name), 
    join ("\n",
          'HELO fqdn',
          'MAIL FROM:<fr@m>',
          'RCPT TO:<zz@yy.xxx>',
          'DATA',
          'Subject: confirm',
          'To: zz@yy.xxx',
          'Content-Type: text/plain; charset=UTF-8',
          'Content-Transfer-Encoding: quoted-printable',
          '',
          'Link: http://url/confirm.cgi?key=3DMTIwOSxrDiuSRbn%2B1fso/SOS/B9T&mail=3Dzz@yy.xxx',
          '.',
          'QUIT',
          '');

    # Confirm the email
    conn_call($mc, 'confirm', 'zz@yy.xxx', 'MTIwOSxrDiuSRbn+1fso/SOS/B9T', 'ok');

    # This must cause the pending mail to be sent
    $file_name = setup_get_tmpfile_name($setup, 'smtp3');
    file_wait($file_name);

    assert_equals file_content($file_name), 
    join ("\n",
          'HELO fqdn',
          'MAIL FROM:<fr@m>',
          'RCPT TO:<zz@yy.xxx>',
          'DATA',
          'Subject: Mail Subject',
          'To: zz@yy.xxx',
          'Content-Type: text/plain; charset=UTF-8',
          'Content-Transfer-Encoding: quoted-printable',
          '',
          'Mail Body',
          '.',
          'QUIT',
          '');
};
