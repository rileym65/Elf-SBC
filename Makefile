PROJECT = sbc

sbc.rom: sbc.prg sbrun16.prg sbrun32.prg
	./combine.pl sbc.prg sbrun16.prg sbrun32.prg >sbc.rom

sbc.prg: sbc.asm bios.inc
	mv sbc.num build.num
	../dateextended.pl > date.inc
	../build.pl > build.inc
	mv build.num sbc.num
	rcasm -l -v -x -d 1802 sbc > sbc.lst
	cat sbc.prg | sed -f sbc.sed > x.prg
	rm sbc.prg
	mv x.prg sbc.prg
	tail -6 sbc.lst

sbrun16.prg: sbrun.asm bios.inc
	mv sbrun.num build.num
	../dateextended.pl > date.inc
	../build.pl > build.inc
	mv build.num sbrun.num
	rcasm -l -v -x -d 1802 -DBIT16 sbrun > sbrun16.lst
	mv sbrun.prg sbrun16.prg
	cat sbrun16.prg | sed -f sbrun16.sed > x.prg
	rm sbrun16.prg
	mv x.prg sbrun16.prg
	tail -6 sbrun16.lst

sbrun32.prg: sbrun.asm bios.inc
	mv sbrun32.num build.num
	../dateextended.pl > date.inc
	../build.pl > build.inc
	mv build.num sbrun32.num
	rcasm -l -v -x -d 1802 -DBIT32 sbrun > sbrun32.lst
	mv sbrun.prg sbrun32.prg
	cat sbrun32.prg | sed -f sbrun32.sed > x.prg
	rm sbrun32.prg
	mv x.prg sbrun32.prg
	tail -6 sbrun32.lst

hex: $(PROJECT).rom
	cat $(PROJECT).rom | ../tointel.pl > $(PROJECT).hex

install: $(PROJECT).rom
	cp $(PROJECT).rom ../../$(PROJECT).prg
	cd ../.. ; ./run -R $(PROJECT).prg

clean:
	-rm sbc.prg
	-rm sbrun16.prg
	-rm sbrun32.prg
	-rm sbc.rom
	-rm *.lst

