
GHCDEBUGOPTS= -W -fno-warn-unused-matches -fno-warn-unused-binds    # -O2 -ddump-simpl-stats -ddump-rules
GHCINC=  -iFrontEnd
PACKAGES= -package mtl  -package unix  #  -prof -auto-all
GHCOPTS=   -O     -pgmF drift-ghc  -F $(GHCDEBUGOPTS) $(GHCINC) $(PACKAGES) -fwarn-type-defaults   -fallow-undecidable-instances  -fglasgow-exts -fallow-overlapping-instances

HC = ghc
HC_OPTS = $(GHCOPTS)

DRIFT= ../DrIFT/src/DrIFT

ALLHS:=$(shell find . Grin Boolean Doc C E  FrontEnd DerivingDrift -maxdepth 1 -follow \( -name \*.hs -or -name \*.lhs \) -and \( \! -name Try\*.hs \) | sed -e 's@^\./@@')

OBJS=$(shell perl ./collect_deps.prl Main.o < depend.make)


SUFFIXES= .hs .lhs .o .hi .hsc .c .h .ly .hi-boot .hs-boot .o-boot

all: depend.make  jhc

MAIN=Main.hs

%.o: %.hs
	$(HC) -i.  $(HCFLAGS) $(GHCOPTS) -o $@ -c $<
%.o: %.lhs
	$(HC) -i.  $(HCFLAGS) $(GHCOPTS) -o $@ -c $<

%.hi: %.o
	@:

%.hi-boot: %.o-boot
	@:

%.o-boot: %.hs-boot
	$(HC) $(HCFLAGS) $(GHCOPTS) -c $<

RawFiles.hs:  data/HsFFI.h data/jhc_rts.c
	perl ./op_raw.prl $(basename $@)  $^ > $@

FrontEnd/HsParser.hs: FrontEnd/HsParser.ly
	happy -a -g -c FrontEnd/HsParser.ly

jhc: $(OBJS)  PrimitiveOperators.hs RawFiles.hs FrontEnd/HsParser.hs FlagDump.hs FlagOpts.hs
	$(HC) $(GHCOPTS) $(EXTRAOPTS) $(OBJS) -o $@

tags: $(ALLHS)
	hasktags $(ALLHS)

regress: jhc Try-Regress.hs
	time ./regress_test.prl try/Try-Regress.hs
	time ./regress_test.prl try/Try-Foo.hs
	time ./regress_test.prl try/Try-Lam.hs
	time ./regress_test.prl try/Try-Case.hs
#	$(MAKE) -C regress
#	(cd regress; ./regress)
#
#

hsdocs:
	haddock -h $(filter-out %/HsParser.hs FrontEnd/Representation.hs C/Gen.hs DData/% E/Subst.hs, $(OBJS:.o=.hs)) -o hsdocs

printos:
	echo $(ALLHS)
	echo $(OBJS)


depend: $(ALLHS)
	$(HC) -M -optdep-f -optdepdepend.make $(HC_OPTS) $(ALLHS)

clean:
	rm -f $(OBJS) jhc *.hs_code.c `find . -name \*.hi -or -name \*.o-boot -or -name \*.hi-boot`

builtfiles: PrimitiveOperators.hs RawFiles.hs FrontEnd/HsParser.hs FlagDump.hs FlagOpts.hs

realclean: clean
	rm -f PrimitiveOperators.hs RawFiles.hs FrontEnd/HsParser.hs FlagDump.hs FlagOpts.hs

clean-ho:
	rm -f -- `find -name \*.ho`

%.hs: %.flags  ./opt_sets.prl
	perl ./opt_sets.prl -n $< $<  > $@

PrimitiveOperators.hs: op_process.prl data/operators.txt data/primitives.txt data/PrimitiveOperators-in.hs
	perl ./op_process.prl > $@ || rm -f $@

.PHONY: depend clean regress hsdocs

-include depend.make
