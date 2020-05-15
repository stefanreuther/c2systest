#!/usr/bin/perl -w
#
#  Invoke as 'wrap_check.pl /path/to/check.exe <args>'
#
#  This can be used to verify the MS-DOS version of 'check.exe' against the 'c2check' test suite.
#  Invoke the test with
#     -Dc2check.path="$PWD/wrap_check.pl /path/to/check.exe"
#  to do so.
#
#  Found errors:
#    03_engspec, 04_beamspec, 05_torpspec failed the "-1" test due to a type error (WORD <> INTEGER)
#
#  Errors not fixed:
#    08_gen/player - INVALID is not fatal in check.exe
#    09_rst/badtime - fails with different error message
#    10_trn/trunc2 - truncated turn not detected as such
#    11_shipsyntax/count/negative, 12_planetsyntax/count/negative, 13_basesyntax/count/negative - not fatal in check.exe
#    20_shiptransfer - negative value not detected as error
#


# Remember program
my $prog = shift @ARGV;
if (!defined $prog) { die "Missing program name" }

# Parse args; replace the directory parameters by virtualized paths.
my $player;
my $game;
my $root;
my @args;
foreach (@ARGV) {
    if (m|^-.*|) {
        push @args, $_;
    } elsif (!defined $player && /^\d+$/ && $_ > 0 && $_ <= 11) {
        $player = $_;
        push @args, $_;
    } elsif (!defined $game) {
        push @args, '\game';
        $game = $_;
    } elsif (!defined $root) {
        push @args, '\root';
        $root = $_;
    } else {
        die "Unable to understand your command line: '$_'";
    }
}

# Build tree for dosemu
my $tmp;
my $n = '';
while (1) {
    $tmp = '/tmp/wrap'.$$.$n;
    last if mkdir $tmp;
    ++$n;
}
symlink $prog, "$tmp/check.exe" or die "symlink $prog";
symlink $game, "$tmp/game"      or die "symlink $game" if defined $game;
symlink $root, "$tmp/root"      or die "symlink $root" if defined $root;
open FILE, '>', "$tmp/run.bat"  or die "open run.bat";
print FILE map {"$_\r\n"} ("d:",
                           "check " . join(' ', @args),
                           "if errorlevel 1 goto out",
                           "echo ok > test.ok",
                           ":out");
close FILE;

# Invoke DOSEMU
$ENV{DOSDRIVE_D} = $tmp;
# $ENV{TERM} = 'dumb';      # doesn't work, why? DOSEMU complains 'Your terminal lacks the ability to clear the screen or position the cursor' although that's what we want it to not do?
$ENV{dosemu__layout} = 'us';
system "dosemu", "-dumb", "$tmp/run.bat";

# Evaluate result.
# The tests expect failures to be reported as errorlevel 2, so we just report all failures that way.
# (DOSEMU would have an %errorlevel% variable we could use, but then we'd have to match check.exe's
# exit codes to c2check's, producing more errors.)
my $ok = 2;
if (-f "$tmp/test.ok") {
    $ok = 0;
    print "Returning success.\n";
} else {
    print "Returning error.\n";
}

# Clean up
foreach (qw(check.exe game root run.bat test.ok)) {
    unlink "$tmp/$_";
}
rmdir $tmp;

exit $ok;
