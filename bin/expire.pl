#!/usr/local/bin/perl
#
# Copyright (C) 1993-1996 fukachan@phys.titech.ac.jp
# Copyright (C) 1996      fukachan@sapporo.iij.ad.jp
# fml is free software distributed under the terms of the GNU General
# Public License. see the file COPYING for more details.

# $rcsid   = q$Id$;


# CONFIGURATION
$SPOOL_DIR = $SPOOL_DIR || "spool";	# expire spool articles
$EXPIRE	   = $EXPIRE    || 7;		# days (7 == one week)

if ($0 eq __FILE__) {
	require 'getopts.pl';
	&Getopts("hs:e:dn");

	die(&USAGE) if $opt_h;
	$SPOOL_DIR = $opt_s || $SPOOL_DIR;
	$EXPIRE	   = $opt_e || $EXPIRE;
	$with_number = $opt_n;	# number
	$debug     = $opt_d;
	
	print STDERR "&Expire($SPOOL_DIR, $EXPIRE);\n" if $debug;
	if ($with_number) {
	    &Expire($SPOOL_DIR, $EXPIRE, $with_number);
	}
	else {
	    &Expire($SPOOL_DIR, $EXPIRE);
	}

	exit 0;
}
else {
	print STDERR "Loading Expire Library\n" if $debug;
}

##### LIBRARY #####
sub Expire_with_date { &Expire(@_);}
sub Expire
{
	local($SPOOL_DIR, $EXPIRE, $with_number) = @_;
	local($d, $f, @f, %f);
	local($oneday) = 24*3600; # seconds for one day

	opendir(F, $SPOOL_DIR) || (return $NULL);
	foreach $f (readdir(F)) {
		next if $f =~ /^\.$/;

		if ($with_number)  {
		    push(@f, $f);
		}
		else {
		    # expire with date(default)
		    $f = "$SPOOL_DIR/$f";
		    $d = time - (stat($f))[10];
		    $d /= $oneday;
		    
		    print STDERR "?:expire $f if $d > $EXPIRE\n" if $debug; 

		    if ( !$debug && -f $f && $d > $EXPIRE && unlink $f ) {
			print STDERR "unlink $f\n";
		    }
		}
	}
	closedir(F);

	# Suppose I do not believe the counter by $DIR/seq 
	if ($with_number)  {
	    # sort ->  1 , 2, 3, ... incresing order.
	    @f = sort { $a <=> $b;} @f;
	    $d = scalar(@f) - $EXPIRE;

	    foreach (@f) {
		$_ = "$SPOOL_DIR/$_";
		print STDERR "Try    $_ [$d files left]\n" if $debug;
		last if $d <= 0;
		print STDERR "unlink $_ [$d files left]\n" if $debug;
		-f $_ && unlink($_) && $d--;
	    }
	}

}


sub USAGE
{
q#expire.pl [-h] [-e expire_days] [-s spool_directry] [-n]
    -h                 : this HELP
    -e expire_days(or max number of files left in the spool) 
    -s spool_directry  : spool
    -n                 : expire with the max number(number is -e option)   
#;
}

1;
