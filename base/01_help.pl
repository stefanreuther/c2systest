#!/usr/bin/perl -w
#
#  Test help screens
#

use strict;
use c2systest;

# All console programs are supposed to accept '-h' and '--help'.
# This tests whether the programs accept that option and that the help texts look resonable.
my $year;
my $version;
foreach my $program (qw(check configtool console
                        dbexport
                        export
                        fileclient file format
                        gfxgen
                        host
                        mailin mailout mgrep monitor
                        nntp
                        plugin
                        rater
                        script sweep
                        talk
                        unpack untrn user)) 
{
    test "base/01_help/$program", sub {
        # Obtain "-h" and "--help" output.
        my $setup = shift;
        my $shell1 = shell_new($setup, $program);
        my $shell2 = shell_new($setup, $program);
        shell_add_args($shell1, '-h');
        shell_add_args($shell2, '--help');
        my $result1 = shell_call($shell1);
        my $result2 = shell_call($shell2);

        # Help texts must be identical for "-h" and "--help".
        assert_equals $result1, $result2;

        # There must be a "Usage:" section.
        assert_contains $result1, "Usage:";

        # There must be a reference to bug reporting.
        assert_contains $result1, "Report bugs to <Streu\@gmx.de>";

        # There must be a reference to c2ng which typically is in the version number.
        assert_contains $result1, "c2ng";

        # There must be a copyright year. The final year must be the same one in every program.
        # (trace_process means the result is visible using "-v".)
        assert $result1 =~ /^[^\n]*(\d\d\d\d)\D*\n/s;
        if (!defined($year)) {
            $year = $1;
            trace_process("Year: $year");
        } else {
            assert_equals $year, $1;
        }

        # There must be a version number. This one must be the same in every program.
        assert $result1 =~ /^[^\n]*\sv([\d.]+)/s;
        if (!defined($version)) {
            $version = $1;
            trace_process("Version: $version");
        } else {
            assert_equals $version, $1;
        }
    };
}
