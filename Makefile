# 
# Copyright (C) 1993-1998 Ken'ichi Fukamachi
#          All rights reserved. 
#               1993-1996 fukachan@phys.titech.ac.jp
#               1996-1998 fukachan@sapporo.iij.ad.jp
# 
# FML is free software; you can redistribute it and/or modify
# it under the terms of GNU General Public License.
# See the file COPYING for more details.
#
# $Id$

CC 	  = cc
CFLAGS	  = -s -O -DPOSIX

SH	  = /bin/sh
MKDIR     = mkdirhier

PWD       = `pwd`
CONFIG_PH = ./config.ph
GENHOST   = _`hostname`_
FWIX      = perl bin/fwix.pl

include .release/mk/prog

all:
	perl ./makefml

install:
	perl ./makefml install

dns_check:
	@ perl bin/dns_check.pl

localtest: 
	@ echo " "
	@ echo "LOCALLY CLOSED TEST in DEBUG MODE(-d option)"
	@ echo "perl sbin/localtest.pl | perl $(PWD)src/fml.pl -d $(PWD) "
	@ echo " "
	@ echo IF YOU WOULD LIKE TO TEST THE DELIVERY WITHOUT Sendmail
	@ echo JUST TYPE
	@ echo "perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -udebug $(PWD)"
	@ echo " "
	@ echo " "
	@ echo "O.K.?(wait 3 sec.)"; sleep 3;
	@ echo INPUT:
	@ echo "-----------------------------------"
	@ perl sbin/localtest.pl 
	@ echo "==================================="
	@ echo " "
	@ echo " "
	@ echo " "
	@ echo "This Header O.K.?(wait 3 sec.)"; sleep 3;
	@ echo OUTPUT: debug info from src/fml.pl 
	@ echo "   *** DEBUG MODE! ***  "
	@ echo "-----------------------------------"
	perl sbin/localtest.pl | perl $(PWD)/src/fml.pl -d $(PWD) 
	@ echo "   DEBUG MODE!   "
	@ echo "-----------------------------------"

doc: 	html_doc

html_doc:
	$(FWIX) -T op -m html -D doc/html/op -d doc/smm < doc/smm/op.wix

roff:	doc/smm/op.wix
	@ echo "sorry, not implemetend yet but halfly completed?"
	@ echo ""
	@ echo "Making nroff of doc/smm/op => var/man"
	@ $(MKDIR) var/man
	@ $(FWIX) -T smm/op -m roff -R var/man -I doc/smm doc/smm/op.wix

texinfo:
	@ echo sorry, not implemetend yet

DISTRIB: distrib 
### ATTENTION! CUT OUT HEREAFTER WHEN RELEASE
# FYI:
# sed '/^DISTRIB/,$d' Makefile > release-snapshot/Makefile 
#

allclean: clean cleanfr

clean:
	gar *~ _* proc/*~ \
	tmp/mget* *.core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*.[0-9] \
	tmp/release.info* tmp/sendfilesbysplit* 
	(chdir $(HOME)/var/simulation/var; gar queue*/*)
	(chdir w; 	gar *~ _* proc/*~ \
	tmp/mget* *.core tmp/MSend*.[0-9] tmp/[0-9]*.[0-9] tmp/*:*:*.[0-9] \
	tmp/release.info* tmp/sendfilesbysplit* )

cleanfr:
	gar *.frbak */*.frbak

# OLD# 
#     DISTRIB: distrib export archive versionup 
#     fj: distrib archive fj.sources

# -Z address
# -S stylesheet
FWIX    =  bin/fwix.pl -F -Z fml-bugs@fml.org 

# .release dir
REL     = .release
RELBIN  = .release/bin

local: distrib 

ntdist: 
	(/bin/sh .release/generator 2>&1| tee /var/tmp/_distrib.log)
	(/bin/sh $(RELBIN)/nt-release.sh /tmp/distrib 2>&1|\
	 tee -a /var/tmp/_distrib.log)
	@ $(RELBIN)/error_report.sh /var/tmp/_distrib.log
	@ echo "(chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)"
	@ (chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)
	@ chmod -R 777 /tmp/nt

nt:	dist wintermute

wintermute:
	chmod -R 777 /var/tmp/fml-current/
	ssh wintermute 'mv -f /home/nt/fukachan/src /home/nt/fukachan/src$$$$'
	ssh wintermute mkdir /home/nt/fukachan/src
	ssh wintermute chmod 777 /home/nt/fukachan/src
	rsync -av /var/tmp/fml-current/ wintermute:/home/nt/fukachan/src/

#nt:	
#	@ (chdir /tmp/; tar cf - distrib)|(chdir /tmp/nt; tar xf -)
#	@ chmod -R 777 /tmp/nt

dist:	distrib 
distrib:
	(/bin/sh .release/generator 2>&1| tee /var/tmp/_distrib.log)
	@ $(RELBIN)/error_report.sh /var/tmp/_distrib.log
	@ echo "";
	@ echo "make distsnap  (make snapshot of dist) "
	@ echo "make sync      (syncrhonize -> fml.org)"

distsnap:
	@ (cd /var/tmp/fml-current/; rsync -auv . $(HOME)/.ftp/snapshot)

snapshot: 
	(/bin/sh .release/generator -ip 2>&1| tee /var/tmp/_release.log)
	@ $(RELBIN)/error_report.sh /var/tmp/_release.log

branch:
	(/bin/sh .release/generator -b 2>&1| tee /var/tmp/_release.log)
	@ $(RELBIN)/error_report.sh /var/tmp/_release.log

release:
	(/bin/sh .release/generator -rp 2>&1| tee /var/tmp/_release.log)
	@ $(RELBIN)/error_report.sh /var/tmp/_release.log

faq:	 plaindoc
textdoc: plaindoc

# release snapshot generator library
GEN_RELEASE     = $(FML)/.release
DOC_RECONFIGURE = $(GEN_RELEASE)/DocReconfigure

INFO:	var/doc/INFO

var/doc/INFO: $(FML)/.info
	$(MKDIR) /var/tmp/.fml
	rm -f /var/tmp/.fml/INFO
	(nkf -e doc/ri/INFO ; nkf -e .info ; nkf -e doc/ri/README.wix) |\
		nkf -e |tee var/doc/INFO > /var/tmp/.fml/INFO
	sh $(DOC_RECONFIGURE) -o var/doc /var/tmp/.fml/INFO 


plaindoc: doc/smm/op.wix
	@ $(MKDIR) /var/tmp/.fml
	@ rm -f /var/tmp/.fml/INFO
	@ (nkf -e doc/ri/INFO ; nkf -e .info ; nkf -e doc/ri/README.wix) |\
		nkf -e > /var/tmp/.fml/INFO
	@ sh $(DOC_RECONFIGURE)

htmldoc: doc/smm/op.wix
	@ find var/html -type l -print |perl -nle unlink
	@ (chdir doc/html; make)
	@ $(MKDIR) var/html/op
	@ (chdir doc/html; make op)
	@ echo "Please see ./var/html/index.html for html version documents"

search:
	@ echo ""
	@ sh .release/search_doc_generator

fix-rcsid:
	@ echo " "; echo "Fixing rcsid ... " 
	@ /bin/sh $(RELBIN)/fix-rcsid.sh
	@ chmod 755 *.pl bin/*.pl sbin/*.pl libexec/*.pl 
	@ echo " Done. " 

check:	fml.pl
	sh .release/bin/check.sh

size_check:
	@ echo "";
	@ echo "size check";
	@ echo "";
	@ find2perl -size 0 -print|perl

c:	*.p?
	(2>&1; for x in *.p? ; do perl -cw $$x ; done ) |\
	perl .release/bin/fix-perl-c-output.pl

fix-include: 
	sh .release/bin/fix-include.sh

cmp:
	$(RELBIN)/uncomments.pl fml.pl | wc
	.release/bin/fpp.pl -mCROSSPOST fml.pl | $(RELBIN)/uncomments.pl | wc
	$(RELBIN)/uncomments.pl libsmtp.pl | wc
	(.release/bin/fpp.pl -mCROSSPOST fml.pl; cat libsmtp.pl)|\
	$(RELBIN)/uncomments.pl|wc
#	$(RELBIN)/uncomments.pl $(HOME)/work/src/USEFUL/hml-1.6/hml.pl |wc

use:
	grep require *pl | grep "\'lib"

reset:
	gar summary log members actives seq
	gar *.bak
	gar var/log/*.[0-9]

capital:
	cat `echo *pl proc/*pl | sed 's#proc/libcompat.pl##'| sed 's#proc/libsid.pl##'` |\
	perl $(RELBIN)/getcapital.pl | sort -n | uniq | sed 's/\$\(.*\)/\1:/' 

syncwww:
	rsync -aubv $(FML)/var/html/ $(WWW)

syncinfo:
	nkf -j var/doc/INFO > $(HOME)/.ftp/snapshot/info

bethdoc: INFO syncinfo newdoc search
newdoc: htmldoc syncwww syncinfo 

varcheck:
	perl .release/bin/search-config-variables.pl -D -s -m *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

v2: varcheck2

varcheck2:
	perl .release/bin/search-config-variables.pl -E -D -s -m \
	*pl libexec/[a-lo-z]*pl proc/*pl bin/*pl |\
	tee /tmp/VARLIST
	@ wc /tmp/VARLIST

v3:
	perl .release/bin/search-config-variables.pl \
	-E -D -s *pl libexec/*pl proc/*pl bin/*pl |\
	tee tmp/VARLIST
	@ wc tmp/VARLIST

sync:
	# scp -v -p /var/tmp/distrib/src/*.pl eriko:~/.fml
	chmod 755 /var/tmp/fml-current/src/fml.pl \
		/var/tmp/fml-current/src/msend.pl \
		/var/tmp/fml-current/libexec/*pl
	rsync --rsh ssh -aubzv /var/tmp/fml-current/src/ eriko:~/.fml/
	rsync --rsh ssh -aubzv /var/tmp/fml-current/bin/ eriko:~/.fml/bin/
	rsync --rsh ssh -aubzv /var/tmp/fml-current/drafts/ eriko:~/.fml/drafts/
	rsync --rsh ssh -aubzv /var/tmp/fml-current/libexec/ eriko:~/.fml/libexec
	(echo "test of new FML snapshot."; echo ""; echo "--fukachan")|\
	Mail test@fml.org

test:
	(bin/emumail.pl; echo test )|perl fml.pl $(PWD) $(PWD)/proc

makefml:
	sh .release/bin/reset-makefml

init-makefml:
	cp sbin/makefml /tmp/distrib
	(chdir /tmp/distrib ; perl makefml )

admin-ci:
	ci usr/bin/[^c^r]* .release/bin/*
	chmod 755 usr/*bin/*

rd:
	perl $(RELBIN)/rdiff.pl *pl libexec/*pl proc/lib[a-jl-z]*pl *bin/[a-z]* Makefile C/*.[ch]


simulation:
	sh $(FML)/.simulation/bootstrap

rel:
	rm -f /tmp/relnotes

libkern:
	sed '/^$$Rcsid/,/MAIN ENDS/d' fml.pl > proc/libkern.pl

diff:
	perl $(FML)/.release/rcsdiff.pl -p
	# fvs diff * proc/* libexec/* sbin/makefml 

ci:
	fvs ci * proc/* libexec/* 

docdiff:
	fvs diff doc/ri/*wix doc/smm/*wix

scan:
	fvs scan * proc/* libexec/* \
		sbin/makefml doc/ri/*wix doc/smm/*wix doc/master/*wix \
		doc/html/* \
		etc/makefml/* cf/* bin/* sys/*/*|\
	tee /tmp/scanbuffer
	@ cp /dev/null /tmp/__scan__
	@ echo "" >> /tmp/__scan__
	@ echo "--- noid ---" >> /tmp/__scan__
	@ grep ^noid /tmp/scanbuffer >> /tmp/__scan__ || echo "NO noid OK" >> /tmp/__scan__
	@ echo "" >> /tmp/__scan__
	@ echo "--- Modified ---" >> /tmp/__scan__
	@ grep ^Modified /tmp/scanbuffer >> /tmp/__scan__ || echo "NO Modified OK" >> /tmp/__scan__
	@ rm /tmp/scanbuffer
	@ echo "";
	@ cat /tmp/__scan__
	@ echo ""; echo "file: /tmp/__scan__"; echo "";

loop:
	perl .release/bin/search_loop.pl *pl libexec/* proc/lib*pl|less -plocal

e:	testsetup
	@ echo 'make m is to re-generate /tmp/e/makefml'
	@ (cd /var/tmp/fml-current; pwd ; perl makefml -f /tmp/e/.fml/system install)

m:
	if [ -d /tmp/e ]; then \
	 perl w/repl.pl sbin/makefml > /tmp/e/makefml ; fi

testsetup:
	@ test -d $(TRASH)/FML_TEST || mkdir $(TRASH)/FML_TEST
	@ test -d $(TRASH)/FML_TEST/e || mkdir $(TRASH)/FML_TEST/e
	@ test -d $(TRASH)/FML_TEST/s || mkdir $(TRASH)/FML_TEST/s
	@ test -h /tmp/e || ln -s $(TRASH)/FML_TEST/e /tmp/e
	@ test -h /tmp/s || ln -s $(TRASH)/FML_TEST/s /tmp/s

diag:
	egrep 'arch/|sub MkDirHier' *pl [a-v]*/*pl sbin/* sys/*/*|grep -v libkern
