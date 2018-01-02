#!/usr/bin/perl -w
#
#  Test message cancellation.
#

use strict;
use c2systest;

test 'mailout/06_cancel', sub {
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

    # Send some messages
    my $mc = setup_connect_app($setup, 'mailout');
    foreach my $i (1 .. 5) {
        conn_call($mc, 'mail', 'msg', "id$i");
        conn_call($mc, 'param', 'subj', "Nr. $i");
        conn_call($mc, 'param', 'body', 'Mail Body');
        conn_call($mc, 'send', 'user:1209');
    }

    # Cancel some message
    conn_call($mc, 'cancel', 'id5');
    conn_call($mc, 'cancel', 'id2');

    # Confirm the email. This causes the remainnig messages to be sent.
    conn_call($mc, 'confirm', 'zz@yy.xxx', 'MTIwOSxrDiuSRbn+1fso/SOS/B9T', 'ok');

    # Verify messages.
    # We have no control over the message order, so gather them in a list and compare that.
    my $list = [];
    foreach (3 .. 5) {
        my $file_name = setup_get_tmpfile_name($setup, 'smtp'.$_);
        file_wait($file_name);
        assert file_content($file_name) =~ /^Subject: Nr\. (\d)/m;
        push @$list, $1;
    }
    assert_set_equals $list, [1,3,4];

    # There must not be more SMTP transactions
    assert ! -f setup_get_tmpfile_name($setup, 'smtp6');
};
