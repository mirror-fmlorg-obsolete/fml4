#!/usr/local/bin/perl
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996-1997 fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.
#
# $Id$


#########################################################################
### Configrations ###

$WWW_HOME = $ENV{'WWW_HOME'};
$DIR      = $FP_TMP_DIR = $TMP_DIR = ($ENV{'TMPDIR'} || '.');

$LOGFILE  = "$DIR/geturllog";

$LIBRARY_TO_OVERWRITE = q#;
sub Log     { print STDERR "@_\n";};
sub Mesg    { local(*e, $s) = @_; print STDERR "LOG>$s\n" if $debug;};
sub Debug   { &Log(@_);};
sub LogWEnv { &Log(@_);};
#;

#########################################################################

### MAIN ###
&Init;
&GetUrl;

exit 0;

### MAIN ENDS ###



#########################################################################
sub GetUrl
{ 
    local($req, $outfile, $head, $tmpf);

    $req      = shift @ARGV || $WWW_HOME;
    $outfile  = shift @ARGV;

    if ($outfile) {
	# if exists already, we update it;
	# if (-f $outfile) { die("$outfile already exists, exit!\n");}
	if ($outfile eq '-') { $UseStdout = 1;}
    } 
    else {
	if ($req =~ m#/$#) { 
	    $req .= "index.html"; 
	}
	if ($req =~ m#\S+/(\S+)#) {
	    $outfile = $1;
	}
    }

    $head     = ".head-${outfile}";
    $headnew  = ".head-${outfile}-new";

    $oldcache = "${outfile}.old";
    $newcache = "${outfile}.new";

    # clean up
    for ($oldcache, $newcache, $headnew) { 
	unlink $_ if -f $_;
    }

    # probe by HEAD
    $tmpf = &ProbeUrl($headnew);


    # connect failed
    if (-z $headnew) {
	&Log("Cannot connect (HEAD probe) $req, exit");
	return 0;
    }

    # not found error?
    if (&Grep('404.*[nN]ot [fF]ound', $headnew)) {
	&Log("Cannot connect (HEAD probe) $req, exit");
	$force_updated = 1 if -f $outfile;
	$force_created = 1 if !-f $outfile;
    }

    # for the first time;
    if ($force_created || !-f $outfile || !-f $head) {
	&Log(sprintf("%-15s %s", "created:", $req));

	$tmpf     = &DoGetUrl($req, $outfile);

	&OutPutFile($tmpf, $outfile);
	&OutPutFile($headnew, $head);

	link($outfile, $newcache);
    }
    # IF updated
    elsif ($force_updated || &UpDatedP($head, $headnew)) {
	&Log(sprintf("%-15s %s", "updated:", $req));
	rename($outfile, $oldcache);

	$tmpf     = &DoGetUrl($req, $outfile);

	&OutPutFile($tmpf, $outfile);
	&OutPutFile($headnew, $head);
    }
    else {
	&Log(sprintf("%-15s %s", "not updated:", $req));
    }

    # unlink temporarily
    unlink $tmpf;
}


sub UpDatedP
{
    local($head, $headnew) = @_;
    local($last, $lastnew);

    # first time
    return 0 unless (-f $head && -f $headnew);

    $last    = &Grep('^Last-Modified:', $head);
    $lastnew = &Grep('^Last-Modified:', $headnew);

    ($last ne $lastnew) ? 1 : 0;
}


sub Grep
{
    local($key, $file) = @_;

    open(IN, $file) || (&Log("Grep: cannot open file[$file]"), return $NULL);
    while (<IN>) { return $_ if /$key/;}
    close(IN);
    $NULL;
}


sub Init
{
    require 'getopts.pl';
    &Getopts("C:H:cdpI:");

    $debug = 1 if $opt_d;

    ### Target machine hack;
    push(@INC, $ENV{'FML'});
    push(@INC, $ENV{'FMLLIB'});
    push(@INC, $opt_I) if $opt_I;

    require 'libkern.pl';
    require 'libsmtp.pl';
    require 'libhref.pl';

    eval($LIBRARY_TO_OVERWRITE); print STDERR $@ if $@;
}


sub ProbeUrl
{
    local($out) = @_;
    local($tmpf);

    $e{"special:probehttp"} = 1;
    $e{'special:geturl'} = 1; # Retrieve

    &HRef($req, *e);

    $tmpf = $e{'special:geturl'};

    undef $e{'special:geturl'};
    undef $e{"special:probehttp"};

    if (-f $tmpf && -s $tmpf) {
	&OutPutFile($tmpf, $out);
	unlink $tmpf;
    }
    else {
	&Log("Not Found: $tmpf");
    }

    $tmpf;
}


sub DoGetUrl
{
    local($req, $outfile) = @_;
    local($tmpf);

    $e{'special:geturl'} = 1; # Retrieve

    &HRef($req, *e);

    $tmpf = $e{'special:geturl'};
    undef $e{'special:geturl'};

    $tmpf;
}


sub OutPutFile
{
    local($in, $out) = @_;
    local($p, $f, $l) = caller;

    print STDERR "Open $out < $in\n" if $debug;

    ### $tmpf -> $out
    open(IN, $in) || die("$!: input($in) [$f $l]\n");

    if (! $UseStdout) {
	open(STDOUT, "> $out") || die("$!: output($out) [$f $l]\n");
    }
    else {
	&Debug("> STDOUT") if $debug;
    }

    select(STDOUT); $| = 1;

    while (sysread(IN, $_, 4096)) { print $_;}

    close(STDOUT);
    close(IN);

    &Debug("$in -> ".($out || 'STDOUT')) if $debug;
}


1;
