# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$;

### Lock library functions, 
### This lock functions uses proceses ID

# Lock UNIX V7 age like..
# old lock extracted from fml 0.x and revised now :-)
sub V7Lock
{
    $0 = "$FML: link(2) style Locked and waiting <$LOCKFILE>";

    # set variables
    $LockFile = $LOCK_FILE || "$FP_VARRUN_DIR/lockfile.v7";
    $LockTmp  = "$FP_VARRUN_DIR/lockfile.$$";
    local($timeout) = 0;

    # create tmpfile
    open(APP, ">> $LockTmp") || die "Can't make LOCK $LockTmp\n";
    close(APP); 
    chown $<, $GID, $LockTmp if $GID;

    &Append2(&WholeMail."[$$]", $LockTmp) if $debug;

    # Timeout by alarm(3);
    &SetEvent($MAX_TIMEOUT * 10, 'TimeOut') if $HAS_ALARM;

    # try within about 10min.
    srand(time|$$);
    for ($timeout = 0; $timeout < $MAX_TIMEOUT; $timeout++) {
	if (link($LockTmp, $LockFile) == 0) {	# if lock fails, wait&try
	    sleep (rand(3)+5);
	} 
	else {
	    last;
	}
    }
    
    unlink $LockTmp;

    if ($timeout >= $MAX_TIMEOUT) {
	$Timeout = sprintf("TIMEOUT.%2d%02d%02d%02d%02d%02d", 
			   $year, $mon+1, $mday, $hour, $min, $sec);

	open(TIMEOUT, "> $FP_VARLOG_DIR/$Timeout");
	select(TIMEOUT); $| = 1; select(STDOUT);
	print TIMEOUT &WholeMail;
	close(TIMEOUT);

	&Warn("link(2) style LOCK TIMEOUT", 
	      "saved in $FP_VARLOG_DIR/$Timeout\n\n".&WholeMail);
    }
}

sub V7Unlock
{
    $0 = "$FML: link(2) style Unlocked <$LOCKFILE>";
    unlink $LockFile;
}

1;
