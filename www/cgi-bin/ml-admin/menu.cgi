#!/usr/local/bin/perl
#-*- perl -*-
#
# Copyright (C) 1999 Ken'ichi Fukamachi
#          All rights reserved. 
#
# $Id$
#


### AUTOMATICALLY REPLACED by makefml (Sun, 9 Mar 97 19:57:48 )
$CONFIG_DIR = ''; # __MAKEFML_AUTO_REPLACED_HERE__
$ML         = '_ML_'; # automatically replaced by makefml
# tricy \_ML\_ syntax to avoid "makefml &Conv() replacement'
if ($ML eq "\_ML\_" || (!$ML)) {
    &Err("Error: mailing list is not defined.");
}

# fml system configuration
require "$CONFIG_DIR/system";
push(@INC, "$EXEC_DIR/www/lib");
require 'libcgi_kern.pl';


### MAIN ###
&Init;
&GetBuffer(*Config);

&ShowHeader;

if ($ErrorString) { &Exit($ErrorString);}

if ($Config{'LANGUAGE'} eq 'Japanese') {
    &Convert("$HTDOCS_TEMPLATE_DIR/Japanese/ml-admin/index.html");
}
elsif ($Config{'LANGUAGE'} eq 'English') {
    &Convert("$HTDOCS_TEMPLATE_DIR/English/ml-admin/index.html");
}
else {
    if ($LANGUAGE eq 'Japanese') {
	&Convert("$HTDOCS_TEMPLATE_DIR/Japanese/ml-admin/index.html");
    }    
    else {
	&Convert("$HTDOCS_TEMPLATE_DIR/English/ml-admin/index.html");
    }
}

&CleanUp;

exit 0;
