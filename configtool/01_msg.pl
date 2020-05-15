#!/usr/bin/perl -w
#
#  Configtool: testing with "msg.ini" file
#
#  Tests various option combinations. msg.ini contains multiple identical assignments.
#
use strict;
use c2systest;

# An actual msg.ini file
my $FILE_CONTENT = '# PCC Message Configuration File
FILTER=Mine Scan (#0)
FILTER=(-h) Sub Space Message
FILTER=(-m) Sub Space Message
FILTER=(-h) Phost v4.0c
FILTER=(-t) Terraform Status
FILTER=(-h) Phost v4.0d
SIG=Greetings,
SIG=  The Imperator
';

test 'console/01_msg', sub {
    my $setup = shift;
    my $file = setup_get_tmpfile_name($setup, 'msg7.ini');
    file_put($file, $FILE_CONTENT);

    # Option '-w' to preserve whitespace on input
    assert_equals call_configtool($setup, $file, '--get=sig'), "The Imperator\n";
    assert_equals call_configtool($setup, '-w', $file, '--get=sig'), "  The Imperator\n";

    # Option '-w' to set whitespace on output (-A)
    assert_equals call_configtool($setup, $file, '-Asig=sag', '--stdout'), $FILE_CONTENT."sig = sag\n";
    assert_equals call_configtool($setup, $file, '-w', '-Asig=sag', '--stdout'), $FILE_CONTENT."sig=sag\n";
    assert_equals call_configtool($setup, '-w', $file, '-Asig=sag', '--stdout'), $FILE_CONTENT."sig=sag\n";

    # Option '-w' vs. option '-D'
    assert_equals call_configtool($setup, $file, '-Dsig=sag', '--stdout'), '# PCC Message Configuration File
FILTER=Mine Scan (#0)
FILTER=(-h) Sub Space Message
FILTER=(-m) Sub Space Message
FILTER=(-h) Phost v4.0c
FILTER=(-t) Terraform Status
FILTER=(-h) Phost v4.0d
SIG=Greetings,
SIG=  sag
';
    assert_equals call_configtool($setup, '-w', $file, '-Dsig=sag', '--stdout'), '# PCC Message Configuration File
FILTER=Mine Scan (#0)
FILTER=(-h) Sub Space Message
FILTER=(-m) Sub Space Message
FILTER=(-h) Phost v4.0c
FILTER=(-t) Terraform Status
FILTER=(-h) Phost v4.0d
SIG=Greetings,
SIG=sag
';

    # Option -U
    assert_equals call_configtool($setup, $file, '-Ufilter', '--stdout'), "SIG=Greetings,\nSIG=  The Imperator\n";
};


sub call_configtool {
    my $setup = shift;
    my $shell = shell_new($setup, 'configtool');
    shell_add_args($shell, @_);
    shell_call($shell);   
}
