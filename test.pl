#!/usr/bin/perl -w
#
#  Main test driver
#
#  Invoke as
#     test.pl [options] [tests]
#
#  Options:
#     -k             Keep going after failing test
#     --perf         Run performance tests (if none given)
#     DIR/FILE.pl    Run this test (if none given: all NN_XXX.pl, where NN is a number).
#
#  Options accepted by individual tests can also be given:
#     -v / -q        Increase/decrease verbosity
#     -Dkey=value    Set system configuration
#     --config=X     Set system configuration file name (default: system.conf)
#     --[no-]colors  Enable/disable colored output
#

use strict;
use c2systest;
use Time::HiRes ('time');

# Command line parser
my @tests;
my $opt_keep_going = 0;
my $opt_perf = 0;
parse_command_line();

# Find list of tests
if (@tests == 0) {
    @tests = find_tests('.');
}

# Run them
my $failures = 0;
my $successes = 0;
my $i = 0;
my $n = scalar(@tests);
my $startTime = time();
foreach (@tests) {
    ++$i;
    trace(0, trace_color(36, "Running test $i/$n: $_"));
    my $err = system "perl", "-I.", $_, @ARGV;
    if ($err != 0) {
        trace(0, trace_color(35, "Test failed: $_, error code is $err"));
        ++$failures;
        last if !$opt_keep_going;
    } else {
        ++$successes;
    }
}
my $endTime = time();

trace(0, trace_color('32;1', sprintf("Elapsed time: %.2fs", $endTime - $startTime)));
if ($failures && !$opt_keep_going) {
    trace(0, trace_color('32;1', "Test failed; stopped."));
    exit 1;
} else {
    trace(0, trace_color($failures ? '31;1' : '32;1', "Total: $failures failures, $successes successes."));
    exit $failures ? 1 : 0;
}


# find_tests(root): Find all tests.
# Returns: list of tests (*.pl).
sub find_tests {
    my @todo = @_;
    my @result = ();
    while (defined(my $dir = shift @todo)) {
        if (length($dir) > 1) { $dir =~ s|/$|| }
        opendir DIR, $dir or die "$dir: $!\n";
        while (defined(my $e = readdir(DIR))) {
            if ($e =~ /^\./ || $e eq 'CVS') {
                # skip
            } elsif (-d "$dir/$e") {
                # subdirectory
                push @todo, "$dir/$e";
            } elsif ($opt_perf
                     ? $e =~ /^p\d.*\.pl$/
                     : $e =~ /^\d.*\.pl$/) 
            {
                # test
                my $t = "$dir/$e";
                $t =~ s|^\./||;
                push @result, $t;
            } else {
                # skip
            }
        }
    }
    sort @result;
}

# parse_command_line(). Parses "our" command-line options and removes them from @ARGV,
# leaving unparsed options there.
sub parse_command_line {
    my $i = 0;
    while ($i < @ARGV) {
        my $e = $ARGV[$i];
        if ($e eq '-k') {
            $opt_keep_going = 1;
            splice @ARGV, $i, 1;
        } elsif ($e =~ /^--?perf$/) {
            $opt_perf = 1;
            splice @ARGV, $i, 1;
        } elsif ($e !~ /^-/) {
            if (-d $e) {
                my @found = find_tests($e);
                if (!@found) { die "$e: no tests found" }
                push @tests, @found;
            } else{
                push @tests, $e;
            }
            splice @ARGV, $i, 1;
        } else {
            ++$i;
        }
    }
    cmdl_parse();
}
