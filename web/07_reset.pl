#!/usr/bin/perl -w
#
#  Test reset.cgi (classic, hash-based)
#
#  Retained for documentatory purposes. As of 20190402, no longer passes because classic reset
#  keys have been removed. Live site no longer generates hash-based keys since 20190324;
#  we only generate token-based keys from now on.
#

use strict;
use c2systest;
use c2cgitest;
use Digest::MD5 ('md5_base64');

# my $PASS_HASH = '1,Z4NHE+IUBLFtmr8yKWYJcg';  # echo -n 'abcpass' | openssl md5 -binary | base64
#
# # Test password reset, classic version.
# # A: present a hand-crafted reset link
# # E: link must correctly be parsed and user redirected
# test 'web/07_reset/classic/ok', sub {
#     my $setup = shift;
#
#     # Compute a key. Cannot hardcode this guy because it contains a time
#     my $time = int(time()/60+100);
#     my $raw_key = 'abc,reset,joe,'.$time.','.$PASS_HASH;
#
#     # Call CGI
#     my $result = call_cgi($setup, Query => [username => 'joe',
#                                             time => $time,
#                                             key => md5_base64($raw_key)]);
#
#     assert_starts_with $result->{headers}{status}, 302;
#     assert_equals $result->{headers}{location}, '/settings.cgi?action=edit_password';
#     assert_starts_with $result->{cookies_by_name}{session}, "3:";
# };
#
# # Test password reset, classic version, expired link
# # A: present a hand-crafted reset link
# # E: link must correctly be rejected; reset form presented
# test 'web/07_reset/classic/expired', sub {
#     my $setup = shift;
#
#     # Compute a key. Cannot hardcode this guy because it contains a time
#     my $time = int(time()/60-100);
#     my $raw_key = 'abc,reset,joe,'.$time.','.$PASS_HASH;
#
#     # Call CGI
#     my $result = call_cgi($setup, Query => [username => 'joe',
#                                             time => $time,
#                                             key => md5_base64($raw_key)]);
#
#     assert_starts_with $result->{headers}{status}, 200;
#     assert !exists $result->{cookies_by_name}{session};
#     assert_contains $result->{text}, 'expired';
# };
#
# # Test password reset, classic version, wrong key
# # A: present a hand-crafted reset link
# # E: link must correctly be rejected; reset form presented
# test 'web/07_reset/classic/invalid', sub {
#     my $setup = shift;
#
#     # Compute a key. Cannot hardcode this guy because it contains a time
#     my $time = int(time()/60+100);
#     my $raw_key = 'xyz,reset,joe,'.$time.','.$PASS_HASH;
#     #              ^^^ wrong key
#
#     # Call CGI
#     my $result = call_cgi($setup, Query => [username => 'joe',
#                                             time => $time,
#                                             key => md5_base64($raw_key)]);
#
#     assert_starts_with $result->{headers}{status}, 200;
#     assert !exists $result->{cookies_by_name}{session};
#     assert_contains $result->{text}, 'invalid';
# };
#
# # Test password reset, classic version, wrong time
# # A: present a hand-crafted reset link
# # E: link must correctly be rejected; reset form presented
# test 'web/07_reset/classic/invalid2', sub {
#     my $setup = shift;
#
#     # Compute a key. Cannot hardcode this guy because it contains a time
#     my $time = int(time()/60-100);
#     my $raw_key = 'abc,reset,joe,'.$time.','.$PASS_HASH;
#
#     # Call CGI
#     my $result = call_cgi($setup, Query => [username => 'joe',
#                                             time => $time+200,
#                                             key => md5_base64($raw_key)]);
#
#     assert_starts_with $result->{headers}{status}, 200;
#     assert !exists $result->{cookies_by_name}{session};
#     assert_contains $result->{text}, 'invalid';
# };
#
#
# # call_cgi($setup, opts=>value....)
# sub call_cgi {
#     my $setup = shift;
#     my %opts = @_;
#
#     setup_add_service_config($setup, 'www.key', 'xyz');
#     setup_add_service_config($setup, 'user.key', 'abc');
#     setup_add_db($setup);
#     setup_add_userfile($setup);
#     setup_add_usermgr($setup);
#     setup_start_wait($setup);
#
#     # Create a user
#     my $dbc = setup_connect_app($setup, 'db');
#     conn_call($dbc, qw(sadd user:all 1001));
#     conn_call($dbc, qw(set uid:joe 1001));
#     conn_call($dbc, qw(set user:1001:name joe));
#     conn_call($dbc, qw(set user:1001:password), $PASS_HASH);
#     conn_call($dbc, qw(hmset user:1001:profile realname Joseph screenname Joe));
#
#     my $cgi = cgi_new($setup, "reset.cgi");
#     cgi_set_get_params($cgi, @{$opts{Query}})
#         if $opts{Query};
#     my $result = cgi_run($cgi);
#     cgi_verify_result($cgi, $result);
#
#     $result;
# }
