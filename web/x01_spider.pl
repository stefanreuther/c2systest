#!/usr/bin/perl -w
#
#  Spider tests.
#
#  This simulates a web spider that follows all links to websites, scripts, images
#  reachable from the index page. It will validate all HTML pages and thus report
#  markup errors, bad links, etc.
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Spidering with no services.
test 'web/x01_spider/none', sub {
    my $setup = shift;
    spider_config($setup);
    setup_start($setup);
    spider($setup);
};

# Spidering with all services, but not logged in (and empty DB).
test 'web/x01_spider/anon_empty', sub {
    my $setup = shift;
    spider_config($setup);
    setup_add_db($setup);
    setup_add_talk($setup);
    setup_add_mailout($setup);
    setup_add_host($setup);
    setup_add_userfile($setup);
    setup_add_hostfile($setup);
    setup_start_wait($setup);
    spider($setup);
};

# Spidering with all services, but not logged in (and populated DB).
test 'web/x01_spider/anon_pop', sub {
    my $setup = shift;
    spider_config($setup);
    setup_add_db($setup);
    my $talks    = setup_add_talk($setup);
    my $mailouts = setup_add_mailout($setup);
    my $hosts    = setup_add_host($setup);
    my $ufs      = setup_add_userfile($setup);
    my $hfs      = setup_add_hostfile($setup);
    setup_start_wait($setup);

    c2service::setup_db_init($setup);
    c2service::setup_talk_init($setup);

    # Add a posting
    my $uid = c2service::setup_db_add_user($setup, 'admin', 'allowadmin', 1);
    my $talkc = service_connect($talks);
    conn_call($talkc, 'postnew', 1, 'Subject', 'text:The text', 'USER', $uid);

    # Add tools and a game
    c2service::setup_hostfile_add_defaults($setup);
    my $hostc = service_connect($hosts);
    conn_call($hostc, 'hostadd', 'H', '', '', 'hk');
    conn_call($hostc, 'masteradd', 'M', '', '', 'mk');
    conn_call($hostc, 'tooladd', 'T', '', '', 'tk');
    conn_call($hostc, 'shiplistadd', 'S', '', '', 'sk');
    my $gid = conn_call($hostc, 'newgame');
    conn_call($hostc, 'gamesetstate', $gid, 'joining');
    conn_call($hostc, 'gamesettype', $gid, 'public');

    spider($setup);
};


# Perform a spidering test.
# Starting at index.cgi, spiders everything that is reachable.
sub spider {
    my $setup = shift;
    my @todo = ([Root => 'index.cgi']);
    my %done;
    my $base_path = setup_get_required_system_config($setup, 'c2web');
    my $num_scripts = 0;
    my $num_files = 0;
    while (@todo) {
        # Fetch absolute URL containing parameters and path
        my $job = shift @todo;
        my $url = $job->[1];
        my $trigger = $job->[0];
        $url =~ s|#.*||;
        next if exists $done{$url};
        $done{$url} = 1;

        # Parse URL
        trace_detail("Checking URL: $url");
        my $script = $url;
        my $path = '';
        my $query = '';
        if ($script =~ s|\?(.*)||) {
            $query = $1;
        }
        if ($script =~ s|\.cgi(/.*)|.cgi|) {
            $path = $1;
        }
        if ($script =~ m|/$|) {
            foreach (qw(index.html index.cgi)) {
                if (-e $base_path.'/'.$script.$_) {
                    $script .= $_;
                    last;
                }
            }
        }

        # Is it a CGI after all?
        if ($script =~ /\.cgi$/) {
            # Build CGI request
            trace_detail("Parsed as CGI: script=$script, path=$path, query=$query");
            my $cgi = cgi_new($setup, $script);
            if ($path ne '') { cgi_set_path($cgi, $path); }
            if ($query ne '') { cgi_set_raw_query_string($cgi, $query); }

            # Pre-verify
            if (!-x $base_path.'/'.$script) { assert_failure("Link '$url' referenced by '$trigger' points to non-existant script"); }

            # Run
            my $result = cgi_run($cgi);

            # Verify result
            cgi_verify_result($cgi, $result);

            # Verify HTML
            if ($result->{headers}{"content-type"} =~ m|^text/html|) {
                my $html = html_verify($url, $result->{text});
                foreach (sort (keys %{$html->{links}}, keys %{$html->{scripts}}, keys %{$html->{styles}})) {
                    if ($_ eq '') {
                        # huh?
                        assert_failure("Null link in '$url'");
                    } elsif (m|^/(.*)|) {
                        # absolute path
                        push @todo, [$url, $1];
                        trace_detail("Found link: '$todo[-1][1]'");
                    } elsif (/^(https?|mailto|ftp):/) {
                        # ignore absolute links
                    } else {
                        # relative path
                        my $x = $_;
                        my $p = $url; $p =~ s|\?.*||; $p =~ s|[^/]*$||;
                        while ($x =~ s|^\.\./|| && $p =~ s|[^/]*/$||) { }
                        push @todo, [$url, $p.$x];
                        trace_detail("Found link: '$todo[-1][1]'");
                    }
                }
            }
            ++$num_scripts;
        } else {
            # Not a CGI
            trace_detail("Parsed as non-CGI: script=$script, query=$query");
            if ($query ne '') { assert_failure("Link '$url' referenced by '$trigger' includes query but does not point at script"); }
            if (!-r $base_path.'/'.$script) { assert_failure("Link '$url' referenced by '$trigger' points to non-existant file"); }
            ++$num_files;
        }
        trace_detail(sprintf("%d to go", scalar(@todo)));
    }
    trace_test(sprintf("%d scripts, %d files processed", $num_scripts, $num_files));
}


# Configure a setup for spidering.
sub spider_config {
    my $setup = shift;

    # The spider will verify that links are not empty.
    # Therefore, we must configure the links to external sites which normally are configured using c2config.txt.
    setup_add_service_config($setup, "link.vgap", "http://egal");
    setup_add_service_config($setup, "link.pcc2", "http://egal");
}
