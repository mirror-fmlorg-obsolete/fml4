# Copyright (C) 1993-1999 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1999 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# q$Id$;


sub ConfirmationModeInit
{
    local(*e, $mode) = @_;

    &Log("Mode Confirmation") if $debug;

    # common
    $CONFIRMATION_ADDRESS = $CONFIRMATION_ADDRESS || $e{'CtlAddr:'};
    $CONFIRMATION_EXPIRE  = $CONFIRMATION_EXPIRE || 7*24; # unit is "hour"

    # EXTENTION "unsubscribe" confirmation
    if ($mode eq 'unsubscribe') {
	&Log("ConfirmationModeInit: mode=$mode");
	$CONFIRMATION_KEYWORD = "unsubscribe-confirm";

	$CONFIRMATION_FILE = "$DIR/unsub.confirm";
	$CONFIRMATION_LIST = "$FP_VARLOG_DIR/unsub.confirm";
	$CONFIRMATION_SUBSCRIBE = "unsubscribe";

	$CONFIRMATION_RESET_KEYWORD = 
	    $CONFIRMATION_RESET_KEYWORD || "unsubscribe-confirm reset";

	$CONFIRM_REPLAY_TEXT_FUNCTION    = 
	    "Confirm'GenUnsubscribeConfirmReplyText";	    
	$CONFIRM_REPLAY_SUBJECT_FUNCTION = 
	    "Confirm'GenUnsubscribeConfirmReplySubject";
    }
    elsif ($mode eq 'chaddr') {
	&Log("ConfirmationModeInit: mode=$mode");
	$CONFIRMATION_KEYWORD = "chaddr-confirm";

	$CONFIRMATION_ENV_SAVED_FILE = "$VARLOG_DIR/$mode.info";

	$CONFIRMATION_FILE = "$DIR/chaddr.confirm";
	$CONFIRMATION_LIST = "$FP_VARLOG_DIR/chaddr.confirm";
	$CONFIRMATION_SUBSCRIBE = "chaddr";

	$CONFIRMATION_RESET_KEYWORD = 
	    $CONFIRMATION_RESET_KEYWORD || "chaddr-confirm reset";

	$CONFIRM_REPLAY_TEXT_FUNCTION    = 
	    "Confirm'GenChaddrConfirmReplyText";	    
	$CONFIRM_REPLAY_SUBJECT_FUNCTION = 
	    "Confirm'GenChaddrConfirmReplySubject";
    }
    else {
	# save the request and given identifier;
	# The concept of KEYWORD and ADDRESS suggeted by ando@iij-mc.co.jp
	$CONFIRMATION_KEYWORD = $CONFIRMATION_KEYWORD || "confirm";
	$CONFIRMATION_RESET_KEYWORD = 
	    $CONFIRMATION_RESET_KEYWORD || "confirm reset";

	$CONFIRMATION_FILE    = $CONFIRMATION_FILE || "$DIR/confirm";
	$CONFIRMATION_LIST    = $CONFIRMATION_LIST || "$FP_VARLOG_DIR/confirm";
	$CONFIRMATION_SUBSCRIBE = $CONFIRMATION_SUBSCRIBE ||
	    $AUTO_REGISTRATION_KEYWORD || $DEFAULT_SUBSCRIBE || "subscribe";
    }

    # touch
    -f $CONFIRMATION_LIST || &Touch($CONFIRMATION_LIST);

    # transfer main to Confirm NameSpace;
    for (CONFIRMATION_KEYWORD,
	 CONFIRMATION_RESET_KEYWORD,
	 CONFIRMATION_FILE,
	 CONFIRMATION_LIST,
	 CONFIRMATION_ADDRESS,
	 CONFIRMATION_SUBSCRIBE, 
	 CONFIRMATION_EXPIRE,
	 CONFIRMATION_WELCOME_STATEMENT,
	 MAIL_LIST) {
	eval("\$Confirm'$_ = \$main'$_;");
    }

    # debug
    eval("\$Confirm'debug = \$main'debug;");
    eval("\$Confirm'debug_confirm = \$main'debug_confirm;");
}


sub FixFmlservConfirmationMode
{
    local(*e) = @_;
    $CONFIRMATION_KEYWORD   = "$CONFIRMATION_KEYWORD $e{'tmp:ml'}";
    $CONFIRMATION_SUBSCRIBE = "$CONFIRMATION_SUBSCRIBE $e{'tmp:ml'}";
}


# return 1 if we can regist $addr (replied and confirmed);
# return 0 if first-time, expired, confirmation yntax error;
sub Confirm
{
    local(*e, $addr, $buffer) = @_;
    local($id, $r, @r, %r, $time, $m, $gh_subject, $type);

    $e{'GH:Reply-To:'} = $e{'GH:Reply-To:'} || $e{'CtlAddr:'};
    $e{"GH:Subject:"}  = &GenConfirmReplySubject(*e, *cf, 'Default');
    $e{'message:h:to'} = $From_address;

    # current time
    $time = time;

    # result code; @r is the identifier;
    $r = &Confirm'FirstTimeP(*r, $addr, $time);#';

    &Log("r => @r") if $debug_confirm;

    # Mail is "subscribe" ? or "confirm" ? else ? (error?)
    $type = &Confirm'BufferSyntaxType(*e, $buffer); #';

    &Log("Confirm::FirstTimeP r=$r type=$type");

    if ($debug_confirm) {
	&Warn("Confirm Request[$r] $ML_FN", 
	      "debug_confirm = 1\nConfirm::FirstTimeP r=$r type=$type\n\n". 
	      &WholeMail);
    }
    
    if ($r eq 'first-time' || $r eq 'expired' || 
	($r eq 'confirmed' && $type eq 'subscribe')) {

	# need to check the validity of the buffer
	# to reply "subscribe key" (reply new id again if expired).
	# $name == "Elena Lolobrigita"
	if ($r eq 'expired') { 
	    &Log("request is expired");
	    $e{"GH:Subject:"} = 
		&GenConfirmReplySubject(*e, *cf, 'Confirm::expired');
	    $m .= &GenConfirmReplyText(*e, *cf, 'Confirm::expired');
	}
	else {
	    $name = &Confirm'BufferSyntax(*e, $buffer);#';
	    &Log("name=[$name]") if $debug_confirm;
	}

	# subscribe / expired state
	if ($name || $r eq 'expired') {
	    # create a format "addr id time(for expire) signature"
	    $id   = &Confirm'GenKey(length($from)); #';
	    $name = $name || $r[3];

	    # cache on var/log/confirm (always);
	    &Append2("$time\t$addr\t$id\t$name", $CONFIRMATION_LIST);

	    # Generating preamble of confirmation
	    $cf{'id'}   = $e{'buf:confirmation:id'}   = $id; 
	    $cf{'name'} = $e{'buf:confirmation:name'} = $name;

	    # create new "id"
	    $e{"GH:Subject:"} = 
		&GenConfirmReplySubject(*e, *cf, "Confirm::GenPreamble");
	    $m .= &GenConfirmReplyText(*e, *cf, 'Confirm::GenPreamble');
	}
	else {
	    &Log("Confirm: buffer with invalid key");
	}

	&Mesg(*e, $m);

	if (-f $CONFIRMATION_FILE) {
	    $e{'message:append:files'} = $CONFIRMATION_FILE;
	}

	# undef $e{"GH:Subject:"};
	return 0;
    }
    elsif ($r eq 'confirmed') { # @r == identifier;
	$r = &Confirm'IdCheck(*e, *r, $addr, $buffer);#';
	$e{"GH:Subject:"} = 
	    &GenConfirmReplySubject(*e, *cf, 
				    $r ? 
				    'Confirm::Confirmed' : 
				    'Confirm::Error');
	# undef $e{"GH:Subject:"};# subject: welcome file;
	return $r;
    }
    else {
	$e{"GH:Subject:"} = 
	    &GenConfirmReplySubject(*e, *cf, 'Confirm::Error');
	&Log("Confirm: Error exception");
	return 0;
    }
}


sub GenConfirmReplySubject
{
    local(*e, *cf, $mode) = @_;
    local($s);

    if ($debug_confirm) {
	local(@c) = caller;
	&Log("GenConfirmReplySubject<$c[2]>: $mode") if $mode ne 'Default';
    }

    # extensions for confirmd
    if ($CONFIRM_REPLAY_SUBJECT_FUNCTION) {
	return &$CONFIRM_REPLAY_SUBJECT_FUNCTION(@_);
    }

    if ($mode eq 'Default') {
	$s = "Subscribe request result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Confirmed') {
	$s = $CONFIRMATION_WELCOME_STATEMENT || $WELCOME_STATEMENT;
	# $s = "Newly added $From_address $ML_FN";
    }
    elsif ($mode eq 'Confirm::Error') {
	$s = "Subscribe with confirmation error $ML_FN";
    }
    elsif ($mode eq 'Confirm::GenPreamble') {
	$s = "Subscribe confirmation request $ML_FN";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    elsif ($mode eq 'Confirm::expired') {
	$s = "Subscribe confirmation expired $ML_FN";
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	$s = "Subscribe confirmation errror $ML_FN";
    }
    else {
	&Log("GenConfirmReplySubject: unknown mode [$mode]") if $debug_confirm;
	"Subscribe request result $ML_FN";
    }
}


sub GenConfirmReplyText
{
    local(*e, *cf, $mode) = @_;
    local($s);

    &Log("GenConfirmReplyText: $mode") if $debug_confirm;

    $s .= "Hi, I am fml ML manager for the ML <$MAIL_LIST>.\n";

    # extensions for confirmd
    if ($CONFIRM_REPLAY_TEXT_FUNCTION) {
	return &$CONFIRM_REPLAY_TEXT_FUNCTION(@_);
    }

    if ($mode eq 'Confirm::GenPreamble') {
	undef $s;

	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "$CONFIRMATION_KEYWORD $cf{'id'} $cf{'name'}\n\n";

	$s .= "Hi, I am fml ML manager for the ML $ML_FN.\n";
	$s .= "Please reply this mail to confirm your subscribe request\n";
	$s .= "and send this to $CONFIRMATION_ADDRESS\n";
	$s .= "So, you can be added to MAILING LIST $ML_FN.";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Confirmation Syntax or Password Error:\n";
	$s .= "Syntax is following style, check again syntax and password\n\n";
	$s .= "$CONFIRMATION_KEYWORD password $cf{'name'}\n";
	$s .= "\nwhere this \"password\" can be seen in the\n";
	$s .= "confirmation request mail from MAILING LIST <$MAIL_LIST>.\n";
    }
    elsif ($mode eq 'Confirm::expired') {
	$s .= "Your confirmation for \"subscribe request for $MAIL_LIST\"\n";
	$s .= "is TOO LATE TO REPLY SINCE ALREADY EXPIRED.\n";
	$s .= "So we treat you request is the first time request.\n";
	$s .= "Please try again. The new confirm key is as follows\n\n";
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Syntax Error! Please check your mail\n\n";
	$s .= "   - The address you used IS NOT A ML MEMBER?\n";
	$s .= "     (TRUE if you try to subscribe)\n";
	$s .= "   - You sent a bad subscribe syntax?\n\n";
	$s .= "If you try to subscribe,  please use the following syntax\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Your-Name ";
	$s .= "(Name NOT E-Mail Address)\n";
	$s .= "\nwhere \"Your Name\" for clearer identification.\n";
	$s .= "For example,\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Please use your name NOT E-Mail Address! like \n\n";
	$s .= "$CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }

    $s;
}


##### SPECIAL HOOKS FOR MANUAL REGISTRATION WITH CONFIRMATION
sub ManualRegistConfirm
{
    local(*e, $mode, $buf) = @_;
    local($org_cf, $org_ws) = ($CONFIRMATION_FILE,
			       $CONFIRMATION_WELCOME_STATEMENT);

    $CONFIRMATION_FILE = $MANUAL_REGISTRATION_CONFIRMATION_FILE;
    $CONFIRMATION_WELCOME_STATEMENT = "Your subscribe request is confirmed.";

    &ConfirmationModeInit(*e, 'subscribe');

    # How to handle 'subscribe' request
    if ($mode eq 'subscribe' && 
	$MANUAL_REGISTRATION_TYPE eq 'forward_to_admin') {
	&LogWEnv("$proc request is forwarded to Maintainer", *e);
	&Mesg(*e, "Please wait a little");
	&Warn("$proc request from $From_address", &WholeMail);
    }
    # $MANUAL_REGISTRATION_TYPE eq confirmation
    elsif ($mode eq 'subscribe') {
	&Confirm(*e, $From_address, $buf);
	&Log("send back confirmation");
    }
    # $MANUAL_REGISTRATION_TYPE eq confirmation
    elsif ($mode eq 'confirm') {
	local($r);
	$r = &Confirm(*e, $From_address, $buf);
	if ($r) {
	    &Log("ManualRegistConfirm: confirm succeeds");

	    &Warn("subscribe request is confirmed $ML_FN",
		  "Hi, I am fml ML manager for <$MAIL_LIST>.\n".
		  "I confirmed subscribe request from <$From_address>.\n".
		  "Please add <$From_address> to a ML member.\n\n".
		  "FYI:Administrative Command Example:\n".
		  "Please send back the following either phrase to <$CONTROL_ADDRESS>.\n\n".
		  "admin pass ADMIN-PASSWORD\n".
		  "admin add $From_address\n\n\tOR\n\n".
		  "approve ADMIN-PASSWORD add $From_address\n\n".
		  &WholeMail);
	    &Log("subscribe request is forwarded to maintainer");

	    $r = $buf;
	    $r =~ s/\n/\n>>> /g;
	    $r  = ">>> $r\n\n";
	    $r .= "Good. Your subscribe request is confirmed ";
	    $r .= "and forwarded to the maintainer.\n";
	    $r .= "He/She will subscribe you, so PLEASE WAIT A LITTLE.\n";
	    &Mesg(*e, $r);
	}
	else {
	    &Log("ManualRegistConfirm: confirm fails");
	}
    }
    else {
	&Log("Error: ManualRegistConfirm: unknown mode");
    }    

    # back store
    ($CONFIRMATION_FILE, $CONFIRMATION_WELCOME_STATEMENT) = ($org_cf, $org_ws);
}


##### Section: CHADDR confirmation
sub FML_SYS_ChaddrConfirm
{
    local(*e, $buf) = @_; # $e{'buf:req:chaddr-confirm'});

}


sub FML_SYS_ChaddrRequest
{
    local(*e, $buf) = @_; # $e{'buf:req:chaddr'});
}


package Confirm;

sub Confirm'GenConfirmReplySubject { &main'GenConfirmReplySubject(@_);}
sub Confirm'GenConfirmReplyText    { &main'GenConfirmReplyText(@_);}

sub Confirm'FixFmlservConfirmationMode { 
    &main'FixFmlservConfirmationMode(@_);
} 
sub AddressMatch { &main'AddressMatch(@_);} #';
sub Log          { &main'Log(@_);} #';
sub Mesg         { &main'Mesg(@_);} #';
sub Open         { &main'Open(@_);} #';
sub Debug        { &main'Debug(@_);} #';

sub IdCheck
{
    local(*e, *r, $addr, $buffer) = @_;
    local($time, $a, $id, $name)  = @r;
    local($m, %cf);

    &Debug("Confirm::IdCheck(addr=$addr) {\n$buffer\n}") if $debug;

    # reset anyway; (if not defined, ignore "reset" routine)
    if ($CONFIRMATION_RESET_KEYWORD && 
	$buffer =~ /$CONFIRMATION_RESET_KEYWORD/) {
	&Log("confirm[confirm] reset request");

	if (&RemoveAddrInConfirmFile($addr)) {
	    &Mesg(*e, "I throw away your subscription request from $addr.");
	    &Mesg(*e, "Please do it again from the first step.");
	    if (-f $CONFIRMATION_FILE) {
		$e{'message:append:files'} = $CONFIRMATION_FILE;
	    }

	}

	&Log("Confirm::IdCheck(addr=$addr) reset");
	return 0;
    }

    # since some user set Japanese strings as $name, it becomes errors;_;
    if ($buffer =~ /$CONFIRMATION_KEYWORD $id/) {
	return 1;
    }
    else {
	&Log("Confirm::IdCheck syntax error");
	&Log("Confirm::IdCheck request[$buffer]") if $debug_confirm;
	$cf{'name'} = $name;
	&Mesg(*e, &GenConfirmReplyText(*e, *cf, 'IdCheck::syntax_error'));
	if (-f $CONFIRMATION_FILE) {
	    $e{'message:append:files'} = $CONFIRMATION_FILE;
	}

	return 0;
    }
}

# the check order is reversed to check all buffer lines.
# 1 confirm 2 subscribe
sub BufferSyntaxType
{
    local(*e, $buffer) = @_;

    if ($buffer =~ /$CONFIRMATION_KEYWORD/) {
	return 'confirm';
    }
    elsif ($buffer =~ /$CONFIRMATION_SUBSCRIBE/) {
	return 'subscribe';
    }
    else {
	return '';
    }
}

sub BufferSyntax
{
    local(*e, $buffer) = @_;
    local($name, $_, $ml);

    &Log("BufferSyntax::{$buffer}\n") if $debug_confirm;

    $ml = $*;
    $*  = 1;

    if ($buffer =~ /$CONFIRMATION_SUBSCRIBE\s+(\S+.*)/) { # require anything;
	$name = $1;
    }
    else {
	&Log("confirm buffer syntax error");
	&Log("error buffer [$buffer]");

	local($re_euc_c) = '[\241-\376][\241-\376]';
	local($re_jin)   = '\033\$[\@B]';

	if ($buffer =~ /($re_jin|$re_euc_c)/) {
	    &Log("confirm: request includes Japanese character [$&]");
	    &Mesg(*e, "Error! Your request seems to include Japanese.");
	}

	&Mesg(*e, &GenConfirmReplyText(*e, *cf, 'BufferSyntax::Error'));
	if (-f $CONFIRMATION_FILE) {
	    $e{'message:append:files'} = $CONFIRMATION_FILE;
	}
	$name = $NULL;
    }

    if (! $name) { $* =$ml; return $NULL;}

    if ($buffer =~ /\@/) {
	&Mesg(*e, &GenConfirmReplyText(*e, *cf, 'BufferSyntax::InvalidAddr'));
	if (-f $CONFIRMATION_FILE) {
	    $e{'message:append:files'} = $CONFIRMATION_FILE;
	}
	$name = $NULL;
    }
    else {
	; # do nothing
    }

    $* =$ml;
    $name;
}

# IMPORTANT (Reset by plural "subscribe" is based below;)
# LAST MATCH EVEN IF PLURAL ENTRIES MATCH ADDR;
# return *r is only for &IdCheck;
sub FirstTimeP
{
    local(*r, $addr, $cur_time) = @_;
    local($time, $key_addr, $a, $id, $name, $match, $addr_found);
    local($status) = 'first-time'; # default
    local($has_special_char);

    # init variables;
    $cur_time   = time;
    ($key_addr) = split(/\@/, $addr);

    if ($key_addr =~ /\+/) {
	$has_special_char = 1;
    }

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return $NULL);
    while (<FILE>) {
	chop;
	($time, $a, $id, $name) = split(/\s+/, $_, 4);

	# pre-match for faster code;
	next if (!$has_special_char) && $a !~ /^$key_addr/i;

	# address match
	&AddressMatch($addr, $a) || next;

	# LAST MATCH EVEN IF PLURAL ENTRIES MATCH ADDR;
	# already address is OK;
	if ($time + ($CONFIRMATION_EXPIRE*3600) < $cur_time) {
	    &Log("Confirmation [id=$id] is already Expired");
	    @r = ($time, $a, $id, $name);
	    $status = 'expired';
	}
	else {
	    @r = ($time, $a, $id, $name);
	    $status = 'confirmed';
	}
    }
    close(FILE);

    $status; 
}


sub RemoveAddrInConfirmFile
{
    local($addr) = @_;
    local($time, $key_addr, $a, $id, $name, $match, $addr_found);
    local($status);

    &Log("RemoveAddrInConfirmFile called") if $debug_confirm;

    # init
    ($key_addr) = split(/\@/, $addr);

    open(FILE, $CONFIRMATION_LIST) || 
	(&Log("cannot open $CONFIRMATION_LIST"), return $NULL);
    open(BAK, "> $CONFIRMATION_LIST.bak") || 
	(&Log("cannot open $CONFIRMATION_LIST.bak"), return $NULL);
    select(OUT); $| = 1; select(STDOUT);
    open(OUT, "> $CONFIRMATION_LIST.new") || 
	(&Log("cannot open $CONFIRMATION_LIST.new"), return $NULL);
    select(OUT); $| = 1; select(STDOUT);

    while (<FILE>) {
	print BAK $_;

	chop;

	($time, $a, $id, $name) = split(/\s+/, $_, 4);

	# address match
	&AddressMatch($addr, $a) && ($status++, next);

	print OUT "$_\n";
    }
    close(BAK);
    close(OUT);
    close(FILE);

    if ($status) {
	&Log("remove $addr in confirmation queue");
    }

    if (! rename("$CONFIRMATION_LIST.new", $CONFIRMATION_LIST)) {
	&Log("fail to rename $CONFIRMATION_LIST");
	return $NULL;
    }

    1;
}


sub GenKey
{
    local($seed) = @_;
    local($key)  = time|$$;

    ($sec,$min,$hour,$mday,$mon,$year,$wday) = (localtime(time))[0..6];

    &main'SRand(); #';

    sprintf("%04d%02d%02d%02d%02d%02d", 
	    1900 + $year, $mon + 1, $mday, $hour, $min, $sec)
	.$$.int(rand($seed + $key));
}


sub GenUnsubscribeConfirmReplySubject
{
    local(*e, *cf, $mode) = @_;
    local($s);

    &Log("GenUnsubscribeConfirmReplySubject: $mode") if $mode ne 'Default';

    if ($mode eq 'Default') {
	$s = "Unsubscribe request result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Confirmed') {
	$s = "Unsubscribe and confirmation result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Error') {
	$s = "Unsubscribe with confirmation error $ML_FN";
    }
    elsif ($mode eq 'Confirm::GenPreamble') {
	$s = "Unsubscribe confirmation request $ML_FN";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	;
    }
    elsif ($mode eq 'Confirm::expired') {
	;
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	;
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	;
    }

    $s || "Unsubscribe request result $ML_FN";
}


sub GenUnsubscribeConfirmReplyText
{
    local(*e, *cf, $mode) = @_;
    local($s);

    &Log("GenUnsubscribeConfirmReplyText: $mode");

    if ($mode eq 'Confirm::GenPreamble') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "$CONFIRMATION_KEYWORD $cf{'id'} $cf{'name'}\n\n";
	$s .= "Please reply this mail to confirm your unsubscribe request\n";
	$s .= "and send this to $CONFIRMATION_ADDRESS\n";
	$s .= "If confirmed, you are removed from MAILING LIST <$MAIL_LIST>.";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Confirmation Syntax or Password Error:\n";
	$s .= "Syntax is following style, check again syntax and password\n\n";
	$s .= "$CONFIRMATION_KEYWORD password $cf{'name'}\n";
	$s .= "\nwhere this \"password\" can be seen\n";
	$s .= "in the confirmation request mail from MAILING LIST <$MAIL_LIST>.\n";
    }
    elsif ($mode eq 'Confirm::expired') {
	$s .= "Your confirmation for \"unsubscribe request for $MAIL_LIST\"\n";
	$s .= "is TOO LATE TO REPLY SINCE ALREADY EXPIRED.\n";
	$s .= "So we treat you request is the first time request.\n";
	$s .= "Please try again. The new confirm key is as follows\n\n";
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Syntax Error! Please use the following syntax\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Your-Name ";
	$s .= "(Name NOT E-Mail Address)\n";
	$s .= "\nwhere \"Your Name\" for clearer identification.\n";
	$s .= "For example,\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Please use your name NOT E-Mail Address! like \n\n";
	$s .= "$CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }

    $s;
}

sub GenChaddrConfirmReplySubject
{
    local(*e, *cf, $mode) = @_;
    local($s);

    &Log("GenChaddrConfirmReplySubject: $mode") if $mode ne 'Default';

    if ($mode eq 'Default') {
	$s = "Chaddr request result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Confirmed') {
	$s = "Chaddr and confirmation result $ML_FN";
    }
    elsif ($mode eq 'Confirm::Error') {
	$s = "Chaddr with confirmation error $ML_FN";
    }
    elsif ($mode eq 'Confirm::GenPreamble') {
	$s = "Chaddr confirmation request $ML_FN";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	;
    }
    elsif ($mode eq 'Confirm::expired') {
	;
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	;
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	;
    }

    $s || "Chaddr request result $ML_FN";
}


sub GenChaddrConfirmReplyText
{
    local(*e, *cf, $mode) = @_;
    local($s);

    &Log("GenChaddrConfirmReplyText: $mode");

    if ($mode eq 'Confirm::GenPreamble') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "$CONFIRMATION_KEYWORD $cf{'id'} $cf{'name'}\n\n";
	$s .= "Please reply this mail to confirm your Chaddr request\n";
	$s .= "and send this to $CONFIRMATION_ADDRESS\n";
	$s .= "If confirmed, you are removed from MAILING LIST <$MAIL_LIST>.";
    }
    elsif ($mode eq 'IdCheck::syntax_error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Confirmation Syntax or Password Error:\n";
	$s .= "Syntax is following style, check again syntax and password\n\n";
	$s .= "$CONFIRMATION_KEYWORD password $cf{'name'}\n";
	$s .= "\nwhere this \"password\" can be seen\n";
	$s .= "in the confirmation request mail from MAILING LIST <$MAIL_LIST>.\n";
    }
    elsif ($mode eq 'Confirm::expired') {
	$s .= "Your confirmation for \"Chaddr request for $MAIL_LIST\"\n";
	$s .= "is TOO LATE TO REPLY SINCE ALREADY EXPIRED.\n";
	$s .= "So we treat you request is the first time request.\n";
	$s .= "Please try again. The new confirm key is as follows\n\n";
    }
    elsif ($mode eq 'BufferSyntax::Error') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Syntax Error! Please use the following syntax\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Your-Name ";
	$s .= "(Name NOT E-Mail Address)\n";
	$s .= "\nwhere \"Your Name\" for clearer identification.\n";
	$s .= "For example,\n\n";
	$s .= "   $CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }
    elsif ($mode eq 'BufferSyntax::InvalidAddr') {
	&FixFmlservConfirmationMode(*e) if $e{'mode:fmlserv'};
	$s .= "Please use your name NOT E-Mail Address! like \n\n";
	$s .= "$CONFIRMATION_SUBSCRIBE Elena Lolabrigita\n";
    }

    $s;
}

1;
