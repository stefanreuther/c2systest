#!/usr/bin/perl -w
#
#  Test accessibility of important pages if microservices are missing.
#
#  Some pages need to be available at all times. Since the introduction of c2user tokens,
#  we need a microservice to validate user's cookies. This exercises the fallback code.
#  (Not handling this separately will cause all pages including index and contact to just
#  show an error message which is probably in violation of quite a bunch of laws.)
#

use strict;
use c2systest;
use c2cgitest;

# Test index.cgi, no cookie.
test 'web/12_noservice/index', sub {
    load_page($_[0], 'index.cgi', Text => "Welcome to PlanetsCentral");
};

# Test index.cgi, with cookie.
test 'web/12_noservice/index+c', sub {
    load_page($_[0], 'index.cgi', Text => "Welcome to PlanetsCentral", Cookie => "session=3:123:x");
};

# Test terms.cgi, no cookie.
test 'web/12_noservice/terms', sub {
    load_page($_[0], 'terms.cgi', Text => "Terms Version");
};

# Test terms.cgi, with cookie.
test 'web/12_noservice/terms+c', sub {
    load_page($_[0], 'terms.cgi', Text => "Terms Version", Cookie => "session=3:123:x");
};

# Test concact.cgi, no cookie.
test 'web/12_noservice/contact', sub {
    load_page($_[0], 'contact.cgi', Text => "Winterberg");
};

# Test contact.cgi, with cookie.
test 'web/12_noservice/contact+c', sub {
    load_page($_[0], 'contact.cgi', Text => "Winterberg", Cookie => "session=3:123:x");
};

# Test help.cgi, no cookie.
# (Help needs a "/" path argument, otherwise it will redirect.)
test 'web/12_noservice/help', sub {
    load_page($_[0], 'help.cgi', Text => "About this site", Path => '/');
};

# Test help.cgi, with cookie.
test 'web/12_noservice/help+c', sub {
    load_page($_[0], 'help.cgi', Text => "About this site", Path => '/', Cookie => "session=3:123:x");
};

sub load_page {
    my ($setup, $name, %args) = @_;
    my $cgi = cgi_new($setup, $name);
    cgi_add_cookie($cgi, $args{Cookie})
        if exists $args{Cookie};
    cgi_set_path($cgi, $args{Path})
        if exists $args{Path};

    my $result = cgi_run($cgi);
    assert_starts_with $result->{headers}{status}, 200;
    assert $result->{text} !~ /errordialog/;

    assert_contains $result->{text}, $args{Text}
        if exists $args{Text};
}
