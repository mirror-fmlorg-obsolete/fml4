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

### themost important variable ! ###
FML = ${.CURDIR}

.include "distrib/mk/fml.sys.mk"
.include "distrib/mk/fml.prog.mk"
.include "distrib/mk/fml.doc.mk"

.if exists(Makefile.local)
.include "Makefile.local"
.endif

.MAIN: usage
all:	usage

usage:
	@ echo ""
	@ echo "\"make all\"       not works!!!"
	@ echo ""
	@ echo "\"make release\"   to make the release"
	@ echo "\"make snapshot\"  to make a snapshot to export"
	@ echo "\"make dist \"     to make a snapshot to use internally" 
	@ echo "\"make distsnap\"  to export snapshot to ftp.iij.ad.jp"
	@ echo "";
	@ echo "-- Makefile.local";
	@ echo "\"make sync\"      to syncrhonize -> fml.org mail server"
	@ echo ""


dist:
	@ make -f distrib/mk/fml.sys.mk __setup
	(/bin/sh $(DIST_BIN)/generator 2>&1| tee $(DESTDIR)/_distrib.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_distrib.log
	@ make usage

distsnap:
	@ make -f distrib/mk/fml.sys.mk __setup
	@ (cd $(DESTDIR)/fml-current/; $(RSYNC) -auv . $(SNAPSHOT_DIR))

snapshot:
	@ make -f distrib/mk/fml.sys.mk __setup
	@ ssh-add -l |grep beth >/dev/null || printf "\n--please ssh-add.\n"
	(/bin/sh $(DIST_BIN)/generator -ip 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log

branch: 
	@ make -f distrib/mk/fml.sys.mk __setup
	(/bin/sh $(DIST_BIN)/generator -b 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log

release:
	@ make -f distrib/mk/fml.sys.mk __setup
	(/bin/sh $(DIST_BIN)/generator -rp 2>&1| tee $(DESTDIR)/_release.log)
	@ $(DIST_BIN)/error_report.sh $(DESTDIR)/_release.log

.PHONY: pkgsrc
pkgsrc:
	(cd pkgsrc; make MASTER_SITE=${MASTER_SITE} )


##### "make build" to initialize documents and all
.if ! exists(.info)
__BUILD_INIT__ += touch_info
.endif

.if ! exists(conf/release_version)
__BUILD_INIT__ += init_conf
__BUILD_END__  += note_conf
.endif

World: world
world: build
build: init_build plaindoc htmldoc pkgsrc dist ${__BUILD_END__}

touch_info:
	echo ${FML}
	touch .info

init_conf:
	echo `cat conf/release`"#0" > conf/release_version
	echo please set up ${FML}/conf/release_version >> /tmp/fml.note

note_conf:
	cat /tmp/fml.note

init_build: ${__BUILD_INIT__}
##### end of "make build"


doc: INFO syncinfo newdoc search
newdoc: htmldoc syncwww syncinfo 

INFO:	$(WORK_DOC_DIR)/INFO $(WORK_DOC_DIR)/INFO-e

INFO-common: $(FML)/.info
	@ make -f distrib/mk/fml.sys.mk __setup
	@ $(MKDIR) $(COMPILE_DIR)
	@ rm -f $(COMPILE_DIR)/INFO
	($(ECONV) doc/ri/INFO; $(ECONV) .info; $(ECONV) doc/ri/README.wix)|\
		$(ECONV) |\
		tee $(WORK_DOC_DIR)/INFO > $(COMPILE_DIR)/INFO

$(WORK_DOC_DIR)/INFO: INFO-common
	$(GEN_PLAIN_DOC) -o $(WORK_DOC_DIR) $(COMPILE_DIR)/INFO 

$(WORK_DOC_DIR)/INFO-e: INFO-common
	perl $(DIST_BIN)/remove_japanese_line.pl \
		< $(COMPILE_DIR)/INFO > $(COMPILE_DIR)/INFO-e

init_dir:
	@ make -f distrib/mk/fml.sys.mk __setup

plaindoc: init_dir INFO doc/smm/op.wix
	@ make -f distrib/mk/fml.sys.mk __setup
#	@ $(GEN_PLAIN_DOC)
	@ env FML=${FML} make -f distrib/mk/fml.doc.mk plaindocbuild

htmldoc: init_dir INFO doc/smm/op.wix
	@ make -f distrib/mk/fml.sys.mk __setup
	@ find $(WORK_HTML_DIR) -type l -print |perl -nle unlink
	@ $(MKDIR) $(WORK_HTML_DIR)/op
	@ env FML=${FML} make -f distrib/mk/fml.doc.mk htmlbuild

syncwww:
	$(RSYNC) -av $(WORK_HTML_DIR)/ $(WWW)/

syncinfo:
	$(JCONV) $(WORK_DOC_DIR)/INFO > $(SNAPSHOT_DIR)/info

libkern:
	sed '/^$$Rcsid/,/MAIN ENDS/d' fml.pl > proc/libkern.pl
