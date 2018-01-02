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
            SERVER_PORT => '80'
        }
    };
}

# cgi_run($cgi): Run the test
# Returns: result
#    result->{headers} = {a=>, b=>}       Headers
#    result->{cookies} = [a,b,c]          Cookies
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
            } else {
                if (exists($result->{headers}{$hdr})) {
                    assert_failure("Duplicate header: '$hdr'");
                }
                $result->{headers}{$hdr} = $val;
                trace_detail("Received header: $hdr: $val");
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
    trace(5, "Received content: <<$text>>");
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

# cgi_set_post($cgi, $content, $contentType): make this a POST request (default is GET).
# $content and $contentType specify the posted entity.
sub cgi_set_post {
    # Fetch parameters and verify
    my $cgi = shift;
    my $content = shift;
    my $ctype = shift;
    _cgi_verify($cgi);
    if (!defined($content))                 { test_failure('Missing content') }
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
    foreach (@_) {
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
            if (m|/([^/+])$|) { $modules{$1} |= 1 }
        }
        foreach (keys %{$html->{styles}}) {
            if (m|/([^/+])$|) { $modules{$1} |= 2 }
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
sub html_verify {
    my $id = shift;
    my $text = shift;
    my $keep = shift;

    my $state = {
        id => $id,
        num_warnings => 0,
        num_errors => 0,
        stack => [],
        links => { },
        images => { },
        scripts => { },
        styles => { },
        ids => { }
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
            if ($c !~ /user [\d.]+ ms/) {
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
                    || $text =~ /\G([\w-]+)\s*=\s*([\w-]+)\s*/sgc)
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

1;
