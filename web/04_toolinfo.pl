#!/usr/bin/perl -w
#
#  Test toolinfo.cgi
#

use strict;
use c2systest;
use c2cgitest;
use c2service;

# Signing up
test 'web/04_toolinfo', sub {
    # Start it
    my $setup = shift;
    my $dbs = setup_add_db($setup);
    my $ufs = setup_add_userfile($setup);
    setup_add_talk($setup);
    setup_add_host($setup);
    setup_add_hostfile($setup);
    setup_add_mailout($setup);
    setup_start_wait($setup);
    c2service::setup_db_init($setup);
    c2service::setup_talk_init($setup);
    c2service::setup_hostfile_add_defaults($setup);

    # Define a tool
    my $hc = setup_connect_app($setup, 'host');
    my $hfc = setup_connect_app($setup, 'hostfile');
    conn_call($hfc, 'mkdirhier', 'tools/config-exp4');
    conn_call($hfc, 'put', 'tools/config-exp4/pconfig.src.frag', "phost.NumExperienceLevels = 4\n");
    conn_call($hc, 'tooladd', 'config-exp4', 'tools/config-exp4', '', 'experience');
    conn_call($hc, 'toolset', 'config-exp4', 'description', 'Four Experience Levels');
    conn_call($hc, 'toolset', 'config-exp4', 'extradescription', 'Enable the PHost experience system...');
    conn_call($hc, 'toolset', 'config-exp4', 'files', 'pconfig.src.frag');

    # Read it. Overview page must contain link to tool page.
    my $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    my $result = cgi_run($cgi);
    my $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{'/host/toolinfo.cgi/tool/config-exp4'} || $html->{links}{'toolinfo.cgi/tool/config-exp4'};

    # Read tool page. Must be valid and link to group page.
    $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    cgi_set_path($cgi, '/tool/config-exp4');
    $result = cgi_run($cgi);
    $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{'/host/toolinfo.cgi?toolkind=experience'};

    # Read group page. Must link back to tool page.
    $cgi = cgi_new($setup, 'host/toolinfo.cgi');
    cgi_set_get_params($cgi, toolkind => 'experience');
    $result = cgi_run($cgi);
    $html = cgi_verify_result($cgi, $result);
    assert $html;
    assert $html->{links}{'/host/toolinfo.cgi/tool/config-exp4'} || $html->{links}{'toolinfo.cgi/tool/config-exp4'};
};
