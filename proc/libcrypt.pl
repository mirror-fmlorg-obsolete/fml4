# Library of fml.pl 
# Copyright (C) 1993-1995 fukachan@phys.titech.ac.jp
# Please obey GNU Public Licence(see ./COPYING)

local($id);
$id = q$Id$;
$rcsid .= " :".($id =~ /Id: lib(.*).pl,v\s+(\S+)\s+/ && "$1[$2]");

$EXIST_CRYPT = eval "crypt('fukachan', 11);", $@ eq "";


# PLAIN passwd -> crypt(passwd, DES-function)
# return 'encrypted passwd' if     crypt() exists
# return passwd itself      if not crypt() exists 
sub Crypt
{
    local($passwd, $salt) = @_;
    local($salt);

    # if not have crypt();
    return $passwd unless $EXIST_CRYPT;

    # if DES function is not given
    $salt = $salt || rand(64);

    # crypt
    crypt($passwd, $salt);
}


# compare ENCRYPTED-PASSWD and PLAIN-PASSWD
# return 1 if matched
sub CmpPasswd
{
    local($c, $p) = @_;

    &Log("CmpPasswd($c,$p)") if $debug;

    if ($c =~ /^(\S\S)/) {
	$p = &Crypt($p, $1);
    }

    &Log("CmpPasswd($c,$p)") if $debug;

    ($c eq $p) ? 1: 0;
}

# in password file $file
# check '$passwd' for '$from' address
# return the retult
sub CmpPasswdInFile
{
    local($file, $from, $passwd) = @_;
    local($ok) = 0;

    open(FILE, $file) || return 0;
    while(<FILE>) {
	chop;

	if (/^$from\s+(\S+)/) {
	    #CmpPasswd(encrypt,plain)
	    &CmpPasswd($1,$passwd) && $ok++;#|| undef($ok);
	}
    }
    close(FILE);

    $ok ? 1: 0;
}


# in password file $file
# change the password to new password $new_passwd for $from 
# PASSWORD($new_passwd) is PLAIN 
# return the result value
sub ChangePasswd
{
    local($file, $from, $new_passwd) = @_;
    local($r) = 0;

    # new password: plain -> crypt
    $new_passwd = &Crypt($new_passwd);

    open(FILE, "< $file")      || do {
	select(FILE); $| = 1;
	&Log("Cannot open $file");
	$_cf{'return'} .= "Cannot open passwd file\n";
	return 0;
    };

    open(OUT,  "> $file.new")  || do {
	select(OUT); $| = 1;
	&Log("Cannot open $file.new");
	$_cf{'return'} .= "Cannot make new passwd file\n";
	return 0;
    };

    open(BAK,  ">> $file.bak") || do {
	select(BAK); $| = 1;
	&Log("Cannot open $file.bak");
	$_cf{'return'} .= "Cannot make passwd backup\n";
	return 0;
    };

    print BAK "--- $Now ---\n";
    while(<FILE>) {
	print BAK $_;

	local($a, $b) = split;
	if($a eq $from) {
	    print OUT "$a $new_passwd\n";
	    $r = 1;
	}else {
	    print OUT $_;
	}
    }

    close FILE;
    close OUT;
    close BAK;

    # Really Matched?
    if (! $r) {
	&Log("Not Matched Passwd Entry[$from] in $file");
	return 0;
    }

    if(rename("$file.new", $file)) {
	return 1;
    }else {
	&Log("Cannot rename $file.new");
	$_cf{'return'} .= "Cannot rename passwd backup\n";
	return 0;
    }
}


#########################################################
if (__FILE__ eq $0) {
    $debug = 1;

    print "&CmpPasswdInFile('etc/passwd',$ARGV[0], $ARGV[1]) = ";
    print &CmpPasswdInFile('etc/passwd',$ARGV[0], $ARGV[1]);
    print ";\n";

    sub Log { print STDERR "LOG:@_\n";}
}
#########################################################


1;
