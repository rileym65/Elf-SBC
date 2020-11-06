PROJECT = sbc

sbc.rom: sbc.prg sbrun.prg
	./combine.pl sbc.prg sbrun.prg >sbc.rom

sbc.prg: sbc.asm bios.inc
	../date.pl > date.inc
	rcasm -l -v -x -d 1802 sbc > sbc.lst
	cat sbc.prg | sed -f sbc.sed > x.prg
	rm sbc.prg
	mv x.prg sbc.prg
	tail -6 sbc.lst

sbrun.prg: sbrun.asm bios.inc
	../date.pl > date.inc
	rcasm -l -v -x -d 1802 sbrun > sbrun.lst
	cat sbrun.prg | sed -f sbrun.sed > x.prg
	rm sbrun.prg
	mv x.prg sbrun.prg
	tail -6 sbrun.lst

clean:
	-rm sbc.prg
	-rm sbrun.prg
	-rm sbc.rom
	-rm *.lst

