#!/usr/bin/perl -w
#
#  Simple quick&dirty SMTP simulator
#
#  This takes the parameters
#     smtp.host, smtp.port       network address to bind to
#     simsmtp.dir                directory
#  in the usual way (C2CONFIG, -D).
#
#  It listens on the given network address and speaks the minimum possible protocol
#  to make the other end believe it is speaking SMTP.
#  Everything sent on a connection created by the client is stored in files "smtpN",
#  where N is a counter starting with 1, with linefeeds normalized to "\n".
#
use strict;
use IO::Socket::INET;

# Read configuration
my %config;
if (open CONFIG, "<", $ENV{C2CONFIG}) {
    while (<CONFIG>) {
        if (/^\s*(\S+?)\s*=\s*(.*)/) {
            $config{lc($1)} = $2;
        }
    }
    close CONFIG;
}
foreach (@ARGV) {
    if (/^-D(\S+?)=(.*)/) {
        $config{lc($1)} = $2;
    }
}

# Verify config
foreach (qw(smtp.port smtp.host simsmtp.dir)) {
    exists $config{$_} or die "smtpsim: missing configuration element $_\n";
}

# Simulate SMTP
my $counter = 0;
my $listener = IO::Socket::INET->new(Proto=>"tcp",
                                     Listen=>10,
                                     ReuseAddr=>1,
                                     LocalAddr=>$config{'smtp.host'},
                                     LocalPort=>$config{'smtp.port'})
    or die "listen: $!";
while (my $client = $listener->accept()) {
    # Open
    ++$counter;
    my $logfile_name = $config{'simsmtp.dir'}.'/smtp'.$counter;
    print "smtpsim: new connection, writing to $logfile_name\n";
    open LOG, ">", $logfile_name or die "$logfile_name: $!\n";
    LOG->autoflush(1);

    # Greeting
    print $client "220 hi there\r\n";

    # Transfer
    my $data = 0;
    while (defined(my $line = readline($client))) {
        $line =~ s/[\r\n]//g;
        print LOG "$line\n";
        if ($data) {
            if ($line eq '.') { 
                print $client "250 ok\r\n";
                $data = 0; 
            }
        } else {
            if (uc($line) eq 'DATA') {
                print $client "354 send data\r\n";
                $data = 1;
            } elsif (uc($line) eq 'QUIT') {
                print $client "221 bye\r\n";
                last;
            } else {
                print $client "250 ok\r\n";
            }
        }
    }

    # Finish
    close $client;
    close LOG;
}
