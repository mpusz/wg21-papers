include ../wg21/Makefile

SRC_BS = $(wildcard *.bs)
HTML_BS = $(SRC_BS:.bs=.html)

$(HTML_BS): %.html:
	mkdir -p $(OUTDIR)
	bikeshed spec $*.bs $(OUTDIR)/$@
