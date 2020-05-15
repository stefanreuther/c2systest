#!/usr/bin/perl -w
#
#  PlanetsCentral CGI tests
#
#  This module provides the CGI object to test a CGI script. It uses a SETUP as provided
#  by c2systest.
#
#  To test a CGI,
#  - create a CGI object using `cgi_new`
#  - change parameters using `cgi_set_XXX` (default is to do a plain GET)
#  - run it using `cgi_run` which produces a result object
#  - optionally, do `cgi_verify_result` to perform generic tests
#
#  Finally, you can test HTML output using `html_verify`, which will perform basic
#  HTML validation (balanced tags) and extract links for further processing.
#
use strict;
use c2systest;
use IO::Socket::INET;

# Magic to just export everything
# (https://stackoverflow.com/questions/732133/how-can-i-export-all-subs-in-a-perl-package)
sub import {
    no strict 'refs';
    my $caller = caller;
    while (my ($name, $symbol) = each %c2systest::) {
        next if      $name eq 'BEGIN';   # don't export BEGIN blocks
        next if      $name eq 'import';  # don't export this sub
        next if      $name =~ /^_/;      # don't export privates
        next unless *{$symbol}{CODE};    # export subs only

        *{$caller.'::'.$name } = \*{$symbol};
    }
}

##
##  CGI
##

# cgi_new($setup, $script): create new CGI test
# Returns: test handle
sub cgi_new {
    my $setup = shift;
    my $script = shift;
    test_failure('Missing $script') if !defined($script) || $script eq '';

    my $path = setup_get_required_system_config($setup, 'c2web');

    my $origScript = $script;
    if ($script =~ s|(.*)/||) {
        $path = "$path/$1";
    }

    return {
        path => $path,
        script => $script,
        setup => $setup,
        input => '/dev/null',
        env => {
            CONTENT_LENGTH => '',
            CONTENT_TYPE => '',
            HTTP_ACCEPT => 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            HTTP_ACCEPT_CHARSET => '',
            HTTP_ACCEPT_ENCODING => '',
            HTTP_ACCEPT_LANGUAGE => 'en-US,en;q=0.5',
            HTTP_COOKIE => '',
            HTTP_HOST => 'pcc.com',
            HTTP_USER_AGENT => 'c2systest/0.0',
            PATH_INFO => '',
            QUERY_STRING => '',
            REMOTE_ADDR => '32.16.8',
            REMOTE_PORT => 32168,
            REQUEST_METHOD => 'GET',
            REQUEST_SCHEME => 'http',
            SCRIPT_FILENAME => "$path/$script",
            SCRIPT_NAME => "/$origScript",
            SERVER_NAME => 'pcc.com',
            SERVER_PORT => '80',
            C2SYSTEST => 1
        }
    };
}

# cgi_new_form($setup, $form): Create CGI from form data.
# Form data contains keys action (=script), method (=get/post), values; as parsed from html_verify().
# Returns: test handle (like cgi_new).
sub cgi_new_form {
    my $setup = shift;
    my $form = shift;
    test_failure('Missing/invalid $form') if !$form || !ref($form) || !defined $form->{action} || !defined $form->{method} || !defined $form->{values};

    # The form might request being posted to things like foo.cgi/blah
    my $path = setup_get_required_system_config($setup, 'c2web');
    my $script = $form->{action};
    my $path_arg = '';
    while (! -f "$path/$script" && $script =~ s|(/[^/]*)$||) {
        $path_arg = $1.$path_arg;
    }

    my $cgi = cgi_new($setup, $script);
    if ($path_arg ne '') {
        cgi_set_path($cgi, $path_arg);
    }
    if (lc($form->{method}) eq 'post') {
        cgi_set_post_params($cgi, %{$form->{values}});
    } else {
        cgi_set_get_params($cgi, %{$form->{values}});
    }
    $cgi;
}

# cgi_run($cgi): Run the test
# Returns: result
#    result->{headers} = {a=>, b=>}       Headers
#    result->{cookies} = [a,b,c]          Cookies
#    result->{cookies_by_name} = {a=>,b=>} Cookies
#    result->{text}    = 'xxx'            Response body
sub cgi_run {
    # Entry
    my $cgi = shift;
    _cgi_verify($cgi);
    trace_process("Executing CGI: $cgi->{path}/$cgi->{script}");

    # Pipe for capturing output
    pipe READER, WRITER or die "pipe: $!";

    # Go multithreaded
    my $pid = fork();
    die "fork: $!" if !defined $pid;
    if ($pid == 0) {
        # Environment
        foreach (sort keys %{$cgi->{env}}) {
            if ($cgi->{env}{$_} eq '') {
                delete $ENV{$_};
            } else {
                $ENV{$_} = $cgi->{env}{$_};
            }
            trace_detail("Environment: $_=$cgi->{env}{$_}");
        }

        # File handles
        open STDIN, '<', $cgi->{input} or die "$cgi->{input} (open stdout): $!";
        open STDOUT, '>&WRITER'        or die "dup stdout: $!";
        close WRITER;
        close READER;
        if (!trace_is_enabled(2)) {
            open STDERR, '>', '/dev/null';
        }

        # Directory
        chdir $cgi->{path} or die "$cgi->{path} (chdir): $!";

        # Run it
        exec "./$cgi->{script}" or die "$cgi->{script} (exec): $!";
        exit 1;
    }

    # Read result
    close WRITER;
    my $text = '';
    my $chunk;
    while (read(READER, $chunk, 4096)) {
        $text .= $chunk;
    }
    close READER;
    waitpid $pid, 0;
    if ($? != 0) { assert_failure("CGI produced exit code $?") }
    trace(2, sprintf("CGI produced %d bytes of output", length($text)));

    # Parse result
    my $result = {
        cookies => [],
        cookies_by_name => { },
        headers => { }
    };
    while (1) {
        # Fetch a line
        my $n = index($text, "\r\n");
        if ($n < 0) { assert_failure("End of headers not found [missing CRLF]") }
        my $line = substr($text, 0, $n);
        $text = substr($text, $n+2);

        # Process line
        if ($line eq '') {
            last;
        } elsif ($line =~ "\n") {
            # "\n" in line is bad
            assert_failure(sprintf("Unescaped newline in line starting '%s'", substr($line, 0, 20)));
        } elsif ($line =~ /^(\S+):\s*(.*)/) {
            # Regular line
            my $hdr = lc($1);
            my $val = $2;
            if ($hdr eq 'set-cookie') {
                push @{$result->{cookies}}, $val;
                trace_detail("Received cookie: $val");
                if ($val =~ /^(.*?)=([^;]*)/) {
                    if (exists($result->{cookies_by_name}{$1})) {
                        assert_failure("Duplicate cookie: '$1'");
                    }
                    $result->{cookies_by_name}{$1} = $2;
                }
            } else {
                trace_detail("Received header: $hdr: $val");
                if (exists($result->{headers}{$hdr})) {
                    assert_failure("Duplicate header: '$hdr'");
                }
                $result->{headers}{$hdr} = $val;
            }
        } else {
            # Irregular line (could be attempted continuation)
            assert_failure("Invalid header '$line'");
        }
    }
    $result->{text} = $text;
    if (!exists $result->{headers}{status}) {
        $result->{headers}{status} = 200;
        trace_detail("Setting status to 200");
    }
    if ($text =~ /[\0-\11\13\14\16-\37]/) {
        trace(5, "Received binary content");
    } else {
        trace(5, "Received content: <<$text>>");
    }
    trace(2, sprintf("CGI produced %d bytes of content", length($text)));
    $result;
}

# cgi_set_path($cgi, $path): set path, as if CGI were accessed as http://path/to/file.cgi/extra/path
# $path must include the leading slash, i.e. '/extra/path'.
# Default is invocation without path.
sub cgi_set_path {
    # Fetch parameters and verify
    my $cgi = shift;
    my $path = shift;
    _cgi_verify($cgi);
    if (!defined($path) || $path !~ m|^/|) { test_failure('Bad or missing $path') }

    $cgi->{env}{PATH_INFO} = $path;
}

# cgi_set_ua($cgi, $ua): set user-agent.
sub cgi_set_ua {
    my $cgi = shift;
    my $ua = shift;
    _cgi_verify($cgi);
    if (!defined($ua)) { test_failure('Bad or missing $ua') }

    $cgi->{env}{HTTP_USER_AGENT} = $ua;
}

# cgi_set_language($cgi, $lang): set Accept-Language.
sub cgi_set_language {
    my $cgi = shift;
    my $lang = shift;
    _cgi_verify($cgi);
    if (!defined($lang)) { test_failure('Bad or missing $lang') }

    $cgi->{env}{HTTP_ACCEPT_LANGUAGE} = $lang;
}

# cgi_set_post($cgi, $content, $contentType): make this a POST request (default is GET).
# $content and $contentType specify the posted entity.
sub cgi_set_post {
    # Fetch parameters and verify
    my $cgi = shift;
    my $content = shift;
    my $ctype = shift;
    _cgi_verify($cgi);
    if (!defined($content)) { test_failure('Missing content') }
    if ($content eq '' && !defined($ctype)) {
        # This happens if someone does xhr.open('POST') without configuring data/content-type.
        # PCC2 Web legacy does this. Fix it here instead of fixing legacy to avoid the test to proceed.
        trace_test("$cgi->{script}: warning: no content-type provided for empty POST; fixing");
        $ctype = 'application/octet-stream'
    }
    if (!defined($ctype) || $ctype !~ m|/|) { test_failure('Bad content type') }

    # Stash away data
    my $fname = setup_get_tmpfile_name($cgi->{setup}, 'post.dat');
    open FILE, '>', $fname or die "$fname: $!";
    binmode FILE;
    print FILE $content;
    close FILE;

    # Set headers
    $cgi->{input} = $fname;
    $cgi->{env}{CONTENT_TYPE} = $ctype;
    $cgi->{env}{CONTENT_LENGTH} = length($content);
    $cgi->{env}{REQUEST_METHOD} = 'POST';
}

# cgi_set_upload_params($cgi, {...}, {...}): make this a POST request using upload
# Each {...} has keys 'name' and 'value', additional parameters can be given (i.e. 'filename').
sub cgi_set_upload_params {
    my $cgi = shift;
    _cgi_verify($cgi);

    my $result = "";
    my $boundary = "alksjdasoidaui";
    foreach my $e (@_) {
        if (!exists $e->{name}) { test_failure('Missing {name}') }
        if (!exists $e->{value}) { test_failure('Missing {value}') }

        $result .= "--$boundary\n";
        $result .= "Content-Disposition: form-data";
        foreach my $k (sort keys %$e) {
            $result .= "; $k=\"$e->{$k}\""
                unless $k eq 'value';
        }
        $result .= "\n\n";
        $result .= $e->{value};
        $result .= "\n";
    }
    $result .= "--$boundary--\n";

    cgi_set_post($cgi, $result, 'multipart/form-data; boundary="'.$boundary.'"');
}

# cgi_set_post_params($cgi, k, v, k, v, ...): make this a POST request using key/value pairs.
# Default is GET with no parameters.
sub cgi_set_post_params {
    my $cgi = shift;
    _cgi_verify($cgi);

    cgi_set_post($cgi, _cgi_urlencode_params(@_), 'application/x-www-form-urlencoded');
}

# cgi_set_get_params($cgi, k, v, k, v, ...): make this a GET request using key/value pairs,
# as if the CGI were accessed as http://path/to/file.cgi?k=v&k=v
# Default is no parameters.
sub cgi_set_get_params {
    my $cgi = shift;
    _cgi_verify($cgi);

    $cgi->{env}{QUERY_STRING} = _cgi_urlencode_params(@_);
}

# cgi_set_raw_query_string($cgi, s): set raw query string (without escaping etc.).
sub cgi_set_raw_query_string {
    my $cgi = shift;
    _cgi_verify($cgi);
    my $str = shift;
    if (!defined($str)) { test_failure('Missing $str'); }

    $cgi->{env}{QUERY_STRING} = $str;
}

# cgi_add_cookie($cgi, @cookies): add cookies.
sub cgi_add_cookie {
    my $cgi = shift;
    _cgi_verify($cgi);
    my @x = @_;
    foreach (@x) {
        s/;.*//;
        $cgi->{env}{HTTP_COOKIE} .= '; ' if $cgi->{env}{HTTP_COOKIE} ne '';
        $cgi->{env}{HTTP_COOKIE} .= $_;
    }
}

# cgi_verify_result($cgi, result, Flag=>value...): verify the result produced by CGI.
# Performs a set of generic tests (which are specific to our domain).
# Flags:
#   NoCheckHTML=>1     do not verify HTML output
#   NoCheckText=>1     do not verify text output
# Returns the value of html_verify unless flag NoCheckHTML is given.
sub cgi_verify_result {
    # Fetch result
    my $cgi = shift;
    my $result = shift;
    my %flags = map {$_=>1} @_;
    _cgi_verify($cgi);
    if (!defined($result) || !ref $result) { assert_failure("Result is invalid"); }

    # Validate content type
    my $ct = $result->{headers}{"content-type"};
    if (!defined($ct)) { assert_failure("Result has no Content-Type"); }
    if ($ct =~ m|^text/|) {
        if ($ct =~ m|; charset=utf-8|i) {
            # ok
        } else {
            # no charset (or unknown charset) given, verify that there is no non-ASCII
            if ($result->{text} =~ /[\x80-\xFF]/) {
                assert_failure("Content contains non-ASCII characters but is not declared as UTF-8");
            }
        }
    }

    # Validate content
    my $html;
    if ($ct =~ m|^text/html| && !$flags{NoCheckHTML}) {
        $html = html_verify($cgi->{script}, $result->{text});
        my %modules;
        foreach (keys %{$html->{scripts}}) {
            if (m|/([^/]+)\.js$|) { $modules{$1} |= 1 }
        }
        foreach (keys %{$html->{styles}}) {
            if (m|/([^/]+)\.css$|) { $modules{$1} |= 2 }
        }
        foreach (sort keys %modules) {
            if ($modules{$_} == 1) { assert_failure("Script '$_' used but no accompanying style"); }
            if ($modules{$_} == 2) { assert_failure("Style '$_' used but no accompanying script"); }
        }
    }
    if ($ct =~ m|^text/plain| && !$flags{NoCheckText}) {
        # We only expect short messages here ("alert, I'm broken") and everything else use the nice error reporters.
        # However, redirect URLs may exceed the limit.
        # Thus, if this is a redirect, allow a little more.
        my $limit = 100;
        if (exists $result->{headers}{location}) {
            $limit += length $result->{headers}{location};
        }
        if (length($result->{text}) > $limit) {
            assert_failure("Plaintext result larger than $limit characters, should be HTML");
        }
    }
    $html;
}

# setup_post_api($setup, $endpoint, $cookie, @args...): post something into an API endpoint.
# Call $endpoint (e.g. api/user.cgi) using the given @args (key/value pairs).
# Passes a cookie if defined.
# Returns the resulting parsed JSON object.
sub setup_post_api {
    my $setup = shift;
    my $endpoint = shift;
    my $cookie = shift;

    # Prepare
    my $cgi = cgi_new($setup, $endpoint);
    cgi_set_post_params($cgi, @_);
    cgi_add_cookie($cgi, $cookie) if defined($cookie) && $cookie ne '';

    # Call. Must answer JSON.
    my $result = cgi_run($cgi);
    assert_starts_with $result->{headers}{"content-type"}, "text/json";

    # Process result
    my $parsed = json_parse($result->{text});
    if (!$parsed->{result}) {
        my $ec = $parsed->{errorCode} || 777;
        my $er = $parsed->{error} || 'No error message given';
        die "$ec $er";
    }
    $parsed;
}

# setup_make_cookie($setup, $uid, [$type]): make a login cookie
# The result can be passed to cgi_add_cookie().
# $type is 'session' (default) or 'autologin'.
# This is a short-cut method to avoid having to script a login each time.
sub setup_make_cookie {
    my $setup = shift;
    my $uid = shift;
    my $type = shift;

    my $uc = setup_connect_app($setup, 'user');
    my $name = conn_call($uc, 'NAME', $uid);
    my $token = conn_call($uc, 'MAKETOKEN', $uid, 'login');

    $type ||= 'session';
    "$type=3:$token:$name";
}

# setup_make_api_token($setup, $uid): make an API token,
# This is a short-cut method to avoid having to script a login each time.
sub setup_make_api_token {
    my $setup = shift;
    my $uid = shift;

    my $uc = setup_connect_app($setup, 'user');
    my $name = conn_call($uc, 'NAME', $uid);
    my $token = conn_call($uc, 'MAKETOKEN', $uid, 'api');

    "3:$token:$name";
}

sub _cgi_verify {
    my $cgi = shift;
    test_failure('Missing $cgi') if !$cgi || !ref($cgi) || !defined $cgi->{script} || !defined $cgi->{env};
}

sub _cgi_urlencode_params {
    my $result = '';
    while (@_) {
        $result .= _cgi_urlencode_single(shift);
        $result .= '=';
        $result .= _cgi_urlencode_single(shift);
        $result .= '&' if @_;
    }
    $result;
}

sub _cgi_urlencode_single {
    my $x = shift;
    $x =~ s/([^-a-zA-Z0-9_.])/sprintf("%%%02X", ord($1))/eg;
    $x;
}

##
##  HTML
##

my %_html_entity_map =
    (
     lt => '<',
     gt => '>',
     amp => '&',
     quot => '"',
     nbsp => ' ',
     trade => '(tm)',
     shy => '-',
     raquo => '>>',
     copy => '(c)',
     szlig => 'sz',
     auml => 'ae',
     ouml => 'ou',
     uuml => 'uu',
     Auml => 'Ae',
     Ouml => 'Oe',
     Uuml => 'Ue',
     mdash => '--'
    );

# html_verify($id, $text, opt $keep): verify HTML $text. Produces errors and warnings.
# $id is used in errors/warnings to identify the test case.
# If $keep is not given or false, presence of an error is an assertion failure.
# Returns: hash with
#  - num_warnings, num_errors: message counts
#  - links: outgoing links ("<a href>") as a hash (key=URL)
#  - images: images ("<img src>") as a hash (key=URL)
#  - scripts: referenced scripts ("<script href>") as a hash (key=URL)
#  - styles: referenced styles ("<link rel="stylesheet" href>") as a hash (key=URL)
#  - forms: list of forms
#  - forms_by_name: forms by name. Each form has {name=>, action=>, method=>, values=>{k...}}
sub html_verify {
    my $id = shift;
    my $text = shift;
    my $keep = shift;

    my $state = {
        id => $id,
        num_warnings => 0,
        num_errors => 0,
        stack => [],
        form_stack => [],
        links => {},
        images => {},
        scripts => {},
        styles => {},
        ids => {},
        forms => [],
        forms_by_name => {}
    };

    # Parser loop
    $text =~ s/\r//g;
    pos($text) = 0;
    while (pos($text) < length($text)) {
        my $nm = $state->{num_errors} + $state->{num_warnings};
        my $pos = pos($text);
        if ($text =~ /\G\s+/sgc) {
            # ok
        } elsif ($text =~ /\G<!(DOCTYPE.*?)>/sgci) {
            # doctype
            if (@{$state->{stack}}) {
                _html_err($state, "doctype declaration not at outer scope");
            }
            if ($1 ne 'DOCTYPE html') {
                _html_warn($state, "doctype declaration is not '<!DOCTYPE html>'");
            }
        } elsif ($text =~ /\G<!--(.*?)-->/sgc) {
            # comment
            my $c = $1;
            if ($c !~ /user [\d.]+ ms/ && $c !~ /^\[if IE/) {
                _html_warn($state, "unexpected comment '$c'");
            }
        } elsif ($text =~ /\G([^<]+)/sgc) {
            # text; ok
            _html_decode_string($state, $1);
            if (!@{$state->{stack}}) {
                _html_warn($state, "text at top-level");
            } elsif ($state->{stack}[-1] eq 'script') {
                _html_warn($state, "inline script text");
            } elsif ($state->{stack}[-1] eq 'style') {
                _html_warn($state, "inline stylesheet");
            }
        } elsif ($text =~ /\G<\s*([\w-]+)\s*/sgc) {
            # <tag
            my $tag = $1;
            if (lc($tag) ne $tag) {
                _html_warn($state, "tag <$tag> not in lower-case");
                $tag = lc($tag);
            }
            my %atts;
            my $close = 0;
            while (1) {
                if ($text =~ /\G>/sgc) {
                    last;
                } elsif ($text =~ /\G\/\s*>/sgc) {
                    $close = 1;
                    last;
                } elsif ($text =~ /\G([\w-]+)\s*=\s*"(.*?)"\s*/sgc
                         || $text =~ /\G([\w-]+)\s*=\s*'(.*?)'\s*/sgc
                         || $text =~ /\G([\w-]+)\s*=\s*([\w-]+)\s*/sgc
                         || $text =~ /\G((checked|selected))\b\s*/sgc)
                {
                    my $att = $1;
                    my $val = $2;
                    if (lc($att) ne $att) {
                        _html_warn($state, "attribute <$tag $att> not in lower-case");
                        $att = lc($att);
                    }
                    if (exists $atts{$att}) {
                        _html_err($state, "duplicate attribute <$tag $att>");
                    }
                    $atts{$att} = _html_decode_string($state, $val);
                } else {
                    _html_err($state, "parse error while expecting attributes");
                    last;
                }
            }

            # Verify
            _html_verify_tag($state, $tag, \%atts);

            # Update state
            if (!(grep {$tag eq $_} qw(img link meta br hr input)) && !$close) {
                push @{$state->{stack}}, $tag;
            }
        } elsif ($text =~ /\G<\s*\/\s*([\w-]+)\s*>/sgc) {
            # </tag>
            my $tag = $1;
            if (lc($tag) ne $tag) {
                _html_warn($state, "tag </$tag> not in lower-case");
            }
            if (!@{$state->{stack}}) {
                _html_err($state, "unexpected closing tag '</$tag>'");
            } else {
                if ($state->{stack}[-1] ne lc($tag)) {
                    _html_err($state, "mismatched tag: got '</$tag>', expected '</$state->{stack}[-1]>'");
                } else {
                    pop @{$state->{stack}};
                }
                if (lc($tag) eq 'form') {
                    pop @{$state->{form_stack}};
                }
            }
        } else {
            # what?
            _html_err($state, "parse error at '".substr($text, pos($text), 20)."'");
            last;
        }
        if ($nm != $state->{num_errors} + $state->{num_warnings}) {
            my $start = $pos;
            while ($start > 0 && substr($text, $start-1, 1) ne "\n") { --$start; }
            my $end = $pos;
            while ($end < length($text) && substr($text, $end, 1) ne "\n") { ++$end; }
            trace_test("\t|".substr($text, $start, $end-$start));
            trace_test("\t|".(' ' x ($pos - $start)).'^ ('.$pos.')');
        }
    }

    if (@{$state->{stack}}) {
        _html_err($state, "unbalanced tags, still open: <$state->{stack}[-1]>");
    }

    if ($state->{num_errors} && !$keep) {
        assert_failure("HTML has errors");
    }

    $state;
}

sub _html_verify_tag {
    my ($state, $tag, $atts) = @_;
    if ($tag eq 'img') {
        # img: needs src and alt attributes
        if (!exists $atts->{src}) {
            _html_err($state, "missing '<$tag src=XX>'");
        } else {
            ++$state->{images}{$atts->{src}};
        }
        if (!exists $atts->{alt}) {
            _html_warn($state, "missing '<$tag alt=XX>'");
        }
    } elsif ($tag eq 'script') {
        # script: needs src attribute
        if (!exists $atts->{src}) {
            _html_err($state, "missing '<$tag src=XX>'");
        } else {
            ++$state->{scripts}{$atts->{src}};
        }
    } elsif ($tag eq 'link' && exists $atts->{rel}) {
        # link: if <link rel>, needs href attribute
        if (!exists $atts->{href}) {
            _html_err($state, "missing '<$tag src=href>'");
        } else {
            if ($atts->{rel} eq 'icon' || $atts->{rel} eq 'apple-touch-icon') {
                $state->{icons}{$atts->{href}}++;
            }
            if ($atts->{rel} eq 'stylesheet') {
                $state->{styles}{$atts->{href}}++;
            }
        }
    } elsif ($tag eq 'a' && exists $atts->{href}) {
        # a: may have href attribute; count that
        $state->{links}{$atts->{href}}++;
    } elsif ($tag eq 'form') {
        # form: must have name, action; remember it on form stack
        my $name = exists $atts->{name} ? $atts->{name} :
            exists $atts->{id} ? $atts->{id} : '';
        if ($name eq '') {
            # Anonymous forms are actually allowed and used, so this is not an error.
            # _html_err($state, "missing '<form id=XX>'");
        }
        if (!exists $atts->{action}) {
            _html_err($state, "missing '<form action=XX>'");
        }
        if (!exists $atts->{method}) {
            _html_warn($state, "missing '<$tag method=XX>'");
        }

        if (exists $state->{forms_by_name}{$name} && $name ne '') {
            _html_warn($state, "duplicate form '$name'");
        }

        my $form = {
            name => $name,
            action => $atts->{action},
            method => exists $atts->{method} ? lc($atts->{method}) : 'get',
            values => { }
        };
        push @{$state->{form_stack}}, $form;
        push @{$state->{forms}}, $form;
        $state->{forms_by_name}{$name} = $form;
    } elsif ($tag eq 'input') {
        # input
        if (@{$state->{form_stack}} && exists $atts->{name}) {
            my $name = $atts->{name};
            my $form_values = $state->{form_stack}[-1]{values};
            my $type = exists $atts->{type} ? lc($atts->{type}) : 'input';
            my $value = exists $atts->{value} ? $atts->{value} : '';
            if ($type eq 'checkbox' || $type eq 'radio') {
                # Clicky thing: take value only if checked, default to blank
                if ((exists $atts->{checked} && $atts->{checked} eq 'checked')) {
                    $form_values->{$name} = $value;
                }
                if (!exists $form_values->{$name}) {
                    $form_values->{$name} = '';
                }
            } else {
                # Normal input: just set value
                $form_values->{$name} = $value;
            }
        }
    } else {
        # anything else
    }

    # Every tag may have an Id
    if (exists $atts->{id}) {
        if (exists $state->{ids}{$atts->{id}}) {
            _html_err($state, "duplicate Id '$atts->{id}'");
        }
        ++$state->{ids}{$atts->{id}};
    }

    # No inline event handlers, please
    if (grep /^on/, keys %$atts) {
        _html_warn($state, "inline event handler");
    }
}

sub _html_decode_string {
    my ($state, $text) = @_;

    # Sanity check
    if ($text =~ m|\$\(|) {
        _html_warn($state, "string possibly contains unescaped variable");
    }

    # Regular decoding
    pos($text) = 0;
    my $result = '';
    while ($text !~ /\G$/sgc) {
        if ($text =~ /\G([^&]+)/sgc) {
            $result .= $1;
        } elsif ($text =~ /\G&#x([0-9a-fA-F]+);/sgc) {
            $result .= '<unicode>';
        } elsif ($text =~ /\G&#([0-9]+);/sgc) {
            $result .= '<num>';
        } elsif ($text =~ /\G&(\w+);/sgc) {
            if (!exists $_html_entity_map{$1}) {
                _html_err($state, "unknown entity '&$1;'");
            } else {
                $result .= $_html_entity_map{$1};
            }
        } else {
            _html_err($state, "parse error in entity reference (stray '&'?)");
            last;
        }
    }
    $result;
}

sub _html_warn {
    my ($state, $msg) = @_;
    trace_test("$state->{id}: warning: $msg");
    ++$state->{num_warnings};
}

sub _html_err {
    my ($state, $msg) = @_;
    trace_test("$state->{id}: error: $msg");
    ++$state->{num_errors};
}

##
##  Serving
##

sub trace_in {
    # trace(2, "  \033[32m< ", @_, "\033[0m");
}

sub trace_out {
    # trace(2, "  \033[33;1m> ", @_, "\033[0m");
}

# setup_serve($setup): Serve the current setup.
# Provides a really simple web server and serves CGIs and static files with the current setup.
sub setup_serve {
    my $setup = shift;
    my $listener = IO::Socket::INET->new(Listen => 10, LocalHost => '127.0.0.1', Proto => 'tcp')
        or die "new socket: $!";
    my $host = $listener->sockhost();
    my $port = $listener->sockport();
    my $pid = fork();
    if (!defined($pid)) {
        die "fork: $!";
    }
    if ($pid == 0) {
        # I am the child
        $listener->listen() or die "listen: $!";
        while (my $client = $listener->accept()) {
            # Read line
            $client->autoflush(1);
            my $line = <$client>;
            next if !defined($line);
            $line =~ s/[\r\n]+//g;
            print "< $line\n";

            # Parse line
            my ($method, $path, $version) = split /\s+/, $line;
            last if $method eq 'QUIT';

            # Parse headers
            my %headers;
            while (defined($line = <$client>)) {
                $line =~ s/[\r\n]+//g;
                trace_in($line)
                    unless $line eq '';
                my ($key, $value) = ($line =~ /^(\S+):\s*(.*)/) or last;
                $headers{lc($key)} = $value;
            }

            # POST body
            my $post_body;
            my $post_length = $headers{'content-length'};
            if (uc($method) eq 'POST' && defined($post_length)) {
                read $client, $post_body, $post_length;
            }

            # Handle request
            my $result = _setup_handle_request($setup, $method, $path, \%headers, $post_body);

            # Produce result
            my $status = (defined $result->{headers}{status} && $result->{headers}{status} =~ /^(\d+)/ ? $1 : '500');
            my $resp = "HTTP/1.0 $status Whatever";
            print $client "$resp\r\n";
            trace_out($resp);
            foreach (sort keys %{$result->{headers}}) {
                if ($_ ne 'status') {
                    my $line = "$_: $result->{headers}{$_}";
                    print $client "$line\r\n";
                    trace_out($line);
                }
            }
            foreach(@{$result->{cookies}}) {
                my $line = "set-cookie: $_";

                # Our subject code generates "domain=127.0.0.1:<port>", which is not allowed
                # and not accepted by browsers. Remove the port numbers.
                $line =~ s/(;domain=[^:;]*):\d+/$1/;

                print $client "$line\r\n";
                trace_out($line);
            }            
            print $client "\r\n";
            print $client $result->{text};
            close $client;
        }
        exit(0);
    } else {
        # I am the parent
        print "Listening on\n";
        print "   http://$host:$port/\n";
        print "Press ENTER to stop.\n";
        readline(STDIN);

        my $conn = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp')
            or die "connect: $!";
        $conn->autoflush(1);
        print $conn "QUIT\n";
        close $conn;
        waitpid($pid, 0);
    }
}

sub _setup_handle_request {
    my ($setup, $method, $path, $headers, $post_body) = @_;

    # Chomp off query string
    my $query = ($path =~ s/\?(.*)// ? $1 : '');

    # Locate item to access
    my $base_path = setup_get_required_system_config($setup, 'c2web');
    my $script_path = "";
    while ($path =~ m|^(/[^/.][^/]*)(.*)| && -e "$base_path$1") {
        # Regexp matches any path component not starting with a dot, to defeat ".." attacks
        $base_path .= $1;
        $script_path .= $1;
        $path = $2;
    }
    if (-d $base_path) {
        # The remaining path needs to be '/'. If it's not, we had a URL of the form "http://xxx/foo".
        # Do NOT redirect. We don't want any implicit redirects happen in our production environment either.
        if ($path ne '/') {
            return { header => { status => 404 }, text => "Not Found (base='$base_path', query='$query')" };
        }

        # Turn "foo/" into "foo/index.cgi"
        foreach (qw(/index.html /index.cgi)) {
            if (-e "$base_path$_") {
                $base_path .= $_;
                $script_path .= $_;
                $path = '';
                last;
            }
        }
    }
    if (! -e $base_path) {
        return { header => { status => 404 }, text => "Not Found (base='$base_path', query='$query')" };
    }

    # OK, we can handle this
    if ($base_path =~ /\.cgi$/) {
        # CGI
        # script_path starts with "/", but cgi_new expects path without "/".
        # If we do not strip it, the script will see wrong parameters and generate wrong links.
        $script_path =~ s|^/||;
        my $cgi = cgi_new($setup, $script_path);

        # Serve headers, e.g. "Accept-Language" becomes "HTTP_ACCEPT_LANGUAGE".
        foreach (sort keys %$headers) {
            my $key = uc($_);
            $key =~ s/-/_/g;
            $cgi->{env}{"HTTP_$key"} = $headers->{$_};
        }

        # Set other parameters (possibly overwriting headers)
        if ($path ne '') { cgi_set_path($cgi, $path); }
        if ($query ne '') { cgi_set_raw_query_string($cgi, $query); }
        if (defined $post_body) { cgi_set_post($cgi, $post_body, $headers->{'content-type'}); }

        return cgi_run($cgi);
    } else {
        # Static file
        # Serve with max-age, to reduce the number of requests made by the browser.
        open FILE, '<', $base_path or die "$base_path: $!";
        my $content = join("", <FILE>);
        close FILE;
        return { headers => { status => 200,
                              'content-type' => _get_type_from_name($base_path),
                              'cache-control' => 'max-age=1000' },
                 text => $content };
    }
}

sub _get_type_from_name {
    foreach (@_) {
        /\.html?$/ and return 'text/html';
        /\.gif$/ and return 'image/gif';
        /\.png$/ and return 'image/png';
        /\.jpe?g$/ and return 'image/jpeg';
        /\.css$/ and return 'text/css';
        /\.js$/ and return 'text/javascript';
        return 'application/octet-stream';
    }
}


##
##  Links
##

# normalize_link($orig, $link): resolve the given link starting from path $orig.
# The result will either be an absolute link with schema (if the $link was one),
# or a path starting from the root of the server with no leading slash.
# Example: normalize_link("a/b/c", "../d") will be "a/d".
sub normalize_link {
    my ($path, $link) = @_;
    $path =~ s|[^/]+$||;
    if ($link =~ /^\w+:/) {
        return $link;
    } elsif ($link =~ m|^/(.*)|) {
        return $1;
    } else {
        my @list;
        foreach (split m|/|, $path.$link) {
            if ($_ eq '..') {
                if (!@list) {
                    assert_failure "Link '$link' points outside web root (too many '..')";
                }
                pop @list;
            } else {
                push @list, $_;
            }
        }
        return join('/', @list);
    }
}

# normalize_links($orig, $link_hash): transform a link hash as produced by cgi_verify_result
# into a new hash with normalized paths. Returns new link has reference.
# Use as 'normalize_links("orig.cgi", $html->{links})'.
sub normalize_links {
    my $orig = shift;
    my $p = shift;
    my $result = {};
    foreach my $k (keys %$p) {
        $result->{normalize_link($orig, $k)} = $p->{$k};
    }
    $result;
}

1;
