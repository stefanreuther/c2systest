#!/usr/bin/perl -w
#
#  Selftest: HTML parser
#

use strict;
use c2systest;
use c2cgitest;

test 'self/01_html', sub {
    my $setup = shift;
    my $p;

    # Disable logging most of the time (add 10 '-v' to re-enable...)
    trace_adjust(-10);
    trace_test(trace_color(32, "Note that the following errors/warnings are part of the test:"));

    # doctype not at outer scope
    test_html('doctype-pos-1', '<html><!DOCTYPE html>', 0);

    # doctype wording
    test_html('doctype-wording-1', '<!DOCTYPE html>', 1);
    test_html('doctype-wording-2', '<!doctype html>', 0);
    test_html('doctype-wording-3', '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">', 0);

    # comments
    test_html('comment-1', '<!-- user 30.00 ms, sys 0.00 ms, real 114.93 ms, total 80.00, 442 x expand, 62 x call, 1 x load -->', 1);
    test_html('comment-2', '<!-- stuff -->', 0);

    # tag case
    test_html('tag-case-1', '<html></html>', 1);
    test_html('tag-case-2', '<HTML></HTML>', 0);
    test_html('tag-case-3', '<html></HTML>', 0);
    test_html('tag-case-4', '<HTML></html>', 0);
    
    # attribute case
    test_html('attr-case-1', '<html><head><link rel="x" href="y" /></head></html>', 1);
    test_html('attr-case-2', '<html><head><link REL="x" href="y" /></head></html>', 0);

    # duplicate attribute
    test_html('attr-dup-1', '<html><head><link rel="x" href="y" rel="z" /></head></html>', 0);

    # attribute syntax
    test_html('attr-syn-1', '<html att></html>', 0);
    test_html('attr-syn-2', '<html id=1></html>', 1);
    test_html('attr-syn-3', '<html id="1"></html>', 1);
    test_html('attr-syn-4', "<html id='1'></html>", 1);

    # general tag syntax
    test_html('tag-syn-1', '< html >< / html >', 1);
    test_html('tag-syn-2', '< html ><body>< img src = "x" alt = "y" / >< / body>< / html >', 1);

    # tag nesting
    test_html('tag-nesting-1', '<html><body><img src="a" alt="b"></body></html>', 1);
    test_html('tag-nesting-2', '<html><body><img src="a" alt="b" /></body></html>', 1);
    test_html('tag-nesting-3', '<html><head><link foo="x"></head></html>', 1);
    test_html('tag-nesting-4', '<html><head><link foo="x" /></head></html>', 1);
    test_html('tag-nesting-5', '<html><head><meta name="x" content="y"></head></html>', 1);
    test_html('tag-nesting-6', '<html><head><meta name="x" content="y" /></head></html>', 1);
    test_html('tag-nesting-7', '<html><body><br></body></html>', 1);
    test_html('tag-nesting-8', '<html><body><br/></body></html>', 1);
    test_html('tag-nesting-9', '<html><body><br /></body></html>', 1);
    test_html('tag-nesting-10', '<html><body><hr></body></html>', 1);
    test_html('tag-nesting-11', '<html><body><hr/></body></html>', 1);
    test_html('tag-nesting-12', '<html><body><hr /></body></html>', 1);
    test_html('tag-nesting-13', '<html><body><input name="a"></body></html>', 1);
    test_html('tag-nesting-14', '<html><body><input name="a"/></body></html>', 1);
    test_html('tag-nesting-15', '<html><body><input name="a" /></body></html>', 1);
    test_html('tag-nesting-16', '<html><body><b/></body></html>', 1);
    test_html('tag-nesting-17', '<html><body><b/></b></body></html>', 0);
    test_html('tag-nesting-18', '<html><body><b>x</b></body></html>', 1);
    test_html('tag-nesting-19', '</foo>', 0);
    test_html('tag-nesting-20', '<html>', 0);
    test_html('tag-nesting-21', '<html><head><link foo="x">', 0);

    # parse error
    test_html('syntax-1', '<', 0);

    # entities in text
    test_html('entity-text-1', '<html><body>a & b</body></html>', 0);
    test_html('entity-text-2', '<html><body>a &amp b</body></html>', 0);
    test_html('entity-text-3', '<html><body>a &amp; b</body></html>', 1);
    test_html('entity-text-4', '<html><body>a &#33; b</body></html>', 1);
    test_html('entity-text-5', '<html><body>a &#x2222; b</body></html>', 1);
    test_html('entity-text-6', '<html><body>a &#33 b</body></html>', 0);
    test_html('entity-text-7', '<html><body>a &#x2222 b</body></html>', 0);

    # entities in attributes
    test_html('entity-attr-1', '<html><body><a href="&">b</a></body></html>', 0);
    test_html('entity-attr-2', '<html><body><a href="&amp">b</a></body></html>', 0);
    test_html('entity-attr-3', '<html><body><a href="&amp;">b</a></body></html>', 1);
    test_html('entity-attr-4', '<html><body><a href="&#33;">b</a></body></html>', 1);
    test_html('entity-attr-5', '<html><body><a href="&#x2222;">b</a></body></html>', 1);
    test_html('entity-attr-6', '<html><body><a href="&#33">b</a></body></html>', 0);
    test_html('entity-attr-7', '<html><body><a href="&#x2222">b</a></body></html>', 0);
    test_html('entity-attr-8', '<html><body><a href="x&amp;y&z">b</a></body></html>', 0);
    test_html('entity-attr-9', '<html><body><a href="x&amp;y&ampz">b</a></body></html>', 0);
    test_html('entity-attr-10', '<html><body><a href="x&amp;y&amp;z">b</a></body></html>', 1);
    test_html('entity-attr-11', '<html><body><a href="x&amp;y&#33;z">b</a></body></html>', 1);
    test_html('entity-attr-12', '<html><body><a href="x&amp;y&#x2222;z">b</a></body></html>', 1);
    test_html('entity-attr-13', '<html><body><a href="x&amp;y&#33z">b</a></body></html>', 0);
    test_html('entity-attr-14', '<html><body><a href="x&amp;y&#x2222z">b</a></body></html>', 0);

    # inline stuff
    test_html('inline-1', '<html><head><script>alert("hi")</script></head></html>', 0);
    test_html('inline-2', '<html><head><style>body { color: red; }</style></head></html>', 0);
    test_html('inline-3', '<html><body><b onclick="alert()">hi</b></body></html>', 0);

    # Re-enable logging
    trace_test(trace_color(32, "End of test."));
    trace_adjust(+10);
};

sub test_html {
    my ($id, $text, $ok) = @_;
    my $state = html_verify($id, $text, 1);
    if (!$state) { die "$id: did not get a result?"; }
    if ($ok) {
        if ($state->{num_warnings} || $state->{num_errors}) {
            assert_failure "$id: expected success, but got warnings/errors";
        }
    } else {
        if (!$state->{num_warnings} && !$state->{num_errors}) {
            assert_failure "$id: expected warnings/errors, but got none";
        }
    }
}
