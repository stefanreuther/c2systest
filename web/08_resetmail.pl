#!/usr/bin/perl -w
#
#  Test reset.cgi, mail round-trip
#

use strict;
use c2systest;
use c2cgitest;
use Digest::MD5 ('md5_base64');

my $PASS_HASH = '1,Z4NHE+IUBLFtmr8yKWYJcg';  # echo -n 'abcpass' | openssl md5 -binary | base64

# Test password reset, mail round-trip.
# This tests the entire system: reset.cgi > mailout > smtp > reset.cgi, independant of the actual implementation.
# A: request a reset link.
# E: mail must be sent. Link must be valid and usable to log in.
test 'web/08_resetmail', sub {
    my $setup = shift;

    # Create template directory
    my $template_dir = setup_get_tmpfile_name($setup, 'tpl');
    mkdir $template_dir, 0777 or die;
    file_put("$template_dir/reset-password",
             join("\n",
                  'From: simsmtp',     # Header required because mailout adds more headers
                  '',
                  'user=$(user)',
                  'resetlink=$(resetlink)'));

    # Start system
    setup_add_service_config($setup, 'www.key', 'xyz');
    setup_add_service_config($setup, 'user.key', 'abc');
    setup_add_service_config($setup, 'mailout.templatedir', $template_dir);
    setup_add_db($setup);
    setup_add_userfile($setup);
    setup_add_usermgr($setup);
    setup_add_mailout($setup, 1);
    setup_add_simsmtp($setup);
    setup_start_wait($setup);

    # Create a user with email
    my $dbc = setup_connect_app($setup, 'db');
    conn_call($dbc, qw(sadd user:all 1001));
    conn_call($dbc, qw(set uid:joe 1001));
    conn_call($dbc, qw(set user:1001:name joe));
    conn_call($dbc, qw(set user:1001:password), $PASS_HASH);
    conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe email joe@mail.test));
    conn_call($dbc, qw(hmset email:joe@mail.test:status status/1001 c));

    # Send mail
    my $send_cgi = cgi_new($setup, "reset.cgi");
    cgi_set_get_params($send_cgi, action=>'send', username=>'joe');
    my $send_result = cgi_run($send_cgi);
    cgi_verify_result($send_cgi, $send_result);
    assert_starts_with $send_result->{headers}{status}, 200;
    assert_contains $send_result->{text}, 'ui-okdialog';

    # Verify that we got one SMTP transaction
    my $smtp_file = setup_get_tmpfile_name($setup, "smtp2");
    file_wait($smtp_file);
    my $mail = file_content($smtp_file);

    assert_contains $mail, 'Content-Transfer-Encoding: quoted-printable';
    $mail =~ s/=([0-9A-F]{2})/chr hex $1/egi;

    # Fetch and parse link
    assert $mail =~ /^user=joe$/m;
    assert $mail =~ /^resetlink=(.*)$/m;
    my $link = $1;
    assert $link =~ s/^.*reset.cgi\?//;

    my @args;
    foreach (split /&/, $link) {
        assert /^(.*?)=(.*)/;
        my ($key, $value) = ($1, $2);
        $value =~ s/%([0-9A-F]{2})/chr hex $1/egi;
        push @args, $key, $value;
    }

    # Make sure we can log in with that link
    my $use_cgi = cgi_new($setup, 'reset.cgi');
    cgi_set_get_params($use_cgi, @args);
    my $use_result = cgi_run($use_cgi);
    assert_starts_with $use_result->{headers}{status}, 302;
    assert_starts_with $use_result->{cookies_by_name}{session}, '3:';
    assert_equals $use_result->{headers}{location}, '/settings.cgi?action=edit_password';

    # Check who we are
    my $check = cgi_new($setup, 'index.cgi');
    cgi_add_cookie($check, @{$use_result->{cookies}});
    my $check_result = cgi_run($check);
    assert_contains $check_result->{text}, 'data-logged-in="1"';
    assert_contains $check_result->{text}, 'data-user="joe"';
};
