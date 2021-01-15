; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

; *** Register usage
; *** RA - Address pointer
; *** RB - Data base page
; *** RF - buffers

TKN_USTR:  equ     0fch
TKN_QSTR:  equ     0fdh
TKN_NUM:   equ     0feh
TKN_TERM:  equ     0ffh

ERR_DIRECT: equ    1
ERR_SYN:    equ    2
ERR_NOLN:   equ    3

OP_LB:     equ     009h
OP_LN:     equ     00ah
OP_DS:     equ     00bh
OP_SP:     equ     00ch
OP_IN:     equ     00dh
OP_PE:     equ     00eh
OP_PO:     equ     00fh
OP_OU:     equ     010h
OP_FG:     equ     011h
OP_FV:     equ     012h
OP_SV:     equ     013h
OP_DE:     equ     014h
OP_DO:     equ     015h
OP_PL:     equ     016h
OP_NE:     equ     017h
OP_AD:     equ     018h
OP_SU:     equ     019h
OP_MP:     equ     01ah
OP_DV:     equ     01bh
OP_CP:     equ     01ch
OP_TS:     equ     01dh
OP_TJ:     equ     01eh
OP_LW:     equ     01fh
OP_PN:     equ     020h
OP_PT:     equ     022h
OP_NL:     equ     023h
OP_PC:     equ     024h
OP_AN:     equ     025h
OP_OR:     equ     026h
OP_GL:     equ     027h
OP_XR:     equ     028h
OP_CL:     equ     02ah
OP_RN:     equ     02bh
OP_FR:     equ     02ch
OP_WS:     equ     02dh
OP_US:     equ     02eh
OP_RT:     equ     02fh
OP_IE:     equ     030h
OP_ID:     equ     031h
OP_IR:     equ     032h
OP_IT:     equ     033h
OP_NX:     equ     034h
OP_OJ:     equ     035h
OP_OS:     equ     036h
OP_JS:     equ     07fh
OP_J:      equ     080h

org:       equ     2000h

           org     8000h
           lbr     0ff00h
           db      'sbc',0
           dw      9000h
           dw      endrom+9000h-org
           dw      org
           dw      endrom-org
           dw      org
           db      0

           org     2000h
           br      start
       
include    date.inc
include    build.inc
           db      'Written by Michael H. Riley',0

pass:      db      0
lineaddr:  dw      0
linenum:   dw      0
compjumps: db      0
dolist:    db      0
errors:    dw      0
errhalt:   db      0
size:      db      0
varbase:   dw      0                   ; Base address for variables.  LSB first
vars:      dw      0                   ; pointer to variable table. LSB first


start:     mov     rf,0400h            ; check kernel build
           lda     rf
           smi     0
     
           mov     rf,0442h            ; point to high memory pointer
           lda     rf                  ; put stack at top of memory
           phi     r2
           lda     rf
           plo     r2

           sep     scall               ; display startup message
           dw      o_inmsg
           db      'Small BASIC Compiler v0.2',10,13
           db      'by Michael H. Riley',10,13,0
           ldi     high ifname         ; point to input filename area
           phi     rf
           ldi     low ifname
           plo     rf
           ldi     high ofname         ; point to output filename
           phi     r9
           ldi     low ofname
           plo     r9
           ldi     high start          ; get base page address
           phi     rb
           ldi     low dolist          ; set listing off
           plo     rb
           ldi     0
           str     rb
           ldi     low size            ; set 16-bits
           plo     rb
           ldi     0                   ; 0=16-bits
           str     rb
           ldi     low errhalt         ; set no halt on errors
           plo     rb
           ldi     0
           str     rb
           ldi     low lineaddr        ; point to line addresses
           plo     rb
           ldi     high lines          ; set address prointer
           str     rb
           inc     rb
           ldi     low lines
           str     rb
           ldi     low errors          ; point to error counter
           plo     rb
           ldi     0                   ; set initial errors to zero
           str     rb
           inc     rb
           str     rb
           ldi     low vars            ; point to variable table pointer
           plo     rb
           ldi     0ffh                ; put variable table 1 page below the stack
           str     rb
           plo     r7                  ; set r7 to varaible table
           inc     rb
           ghi     r2
           smi     1
           str     rb
           phi     r7
           ldi     0                   ; need to mark end of table
           str     r7
arg_lp:    ldn     ra                  ; see if first char is a switch
           smi     '-'                 ; switches are minus sign
           lbnz    fnamelp             ; jump if not
           inc     ra                  ; increment to switch
           lda     ra                  ; get switch character
           smi     'L'                 ; check for list
           lbnz    not_l               ; jump if not list
           ldi     low dolist          ; point to listing flag
           plo     rb
           ldi     1                   ; signal listing enabled
           str     rb
           lbr     noargs              ; jump to skip whitespace
not_l:     dec     ra                  ; get character again
           lda     ra
           smi     'H"                 ; see if halt on erros
           lbnz    not_h
           ldi     low errhalt         ; point to error halt flag
           plo     rb
           ldi     1                   ; signal listing enabled
           str     rb
           lbr     noargs              ; jump to skip whitespace
not_h:     dec     ra                  ; get character again
           lda     ra
           smi     '3'                 ; check for 32 bits
           lbnz    not_32              ; jump if not
           lda     ra                  ; get next character
           smi     '2'                 ; must be 2 for 32 bits
           lbnz    not_32              ; jump if not
           ldi     low size            ; point to size variable
           plo     rb
           ldi     32                  ; indicate 32 bits
           str     rb
           lbr     noargs              ; jump to skip whitespace
not_32:    nop
noargs:    lda     ra                  ; get next cahr
           lbz     nothing             ; jump if no filename found
           smi     32                  ; check for space
           lbz     noargs              ; loop until no more spaces
           dec     ra                  ; move back to nonspace char
           lbr     arg_lp              ; and check for more args
nothing:   sep     sret                ; return to Elf/OS
fnamelp:   lda     ra                  ; get byte from specified filename
           str     rf                  ; store for input filename
           inc     rf
           str     r9                  ; store for output filename
           inc     r9
           smi     33                  ; look anything space or less
           lbdf    fnamelp             ; loop back if not
           dec     rf                  ; move to terminator
           sep     scall               ; append .bas extension
           dw      append
           db      '.bas',0
           str     r9                  ; to output filename
           ldi     high ifname         ; point to input filename
           phi     rf
           ldi     low ifname
           plo     rf
           
           ldi     high (fildes+5)         ; point to input file descriptor
           phi     rd
           ldi     fildes+5
           plo     rd
           ldi     low dta             ; setup dta address
           str     rd
           dec     rd                  ; point to msb of dta
           ldi     high dta            ; get high portion of address
           str     rd                  ; and store
           dec     rd                  ; back to beginning of descriptr
           dec     rd
           dec     rd
           dec     rd
           ldi     0                   ; open flags
           plo     r7
           sep     scall               ; attempt to open the file
           dw      o_open
           lbnf    opened              ; jump if it opened
openerr:   ldi     high fileerr        ; point to error message
           phi     rf
           ldi     low fileerr
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           lbr     o_wrmboot           ; and return to caller
opened:    sep     scall               ; print message
           dw      o_inmsg
           db      'Pass 1.',10,13,0
           ldi     low pass            ; point to pass variable
           plo     rb
           ldi     0                   ; indicate first pass
           str     rb
           ldi     low compjumps       ; indicate no computed jumps
           plo     rb
           ldi     0
           phi     ra                  ; set address pointer to origin
           plo     ra
           sep     scall               ; invoke a compiler pass
           dw      compile
           ldi     low errors          ; point to compile errors
           plo     rb
           lda     rb                  ; see if there were any
           lbnz    nogood              ; jump on compile error
           ldn     rb
           lbnz    nogood              ; jump on compile error
           sep     scall               ; close source file
           dw      o_close
; ************************************************
; *** First pass is complete, open output file ***
; ************************************************
           ldi     high (ofildes+5)    ; point to output file descriptor
           phi     rd
           ldi     ofildes+5
           plo     rd
           ldi     low odta            ; setup dta address
           str     rd
           dec     rd                  ; point to msb of dta
           ldi     high odta           ; get high portion of address
           str     rd                  ; and store
           dec     rd                  ; back to beginning of descriptr
           dec     rd
           dec     rd
           dec     rd
           ldi     3                   ; create/truncate file
           plo     r7
           ldi     high ofname         ; point to output filename
           phi     rf
           ldi     low ofname
           plo     rf
           sep     scall               ; attempt to open the file
           dw      o_open
           lbdf    openerr             ; jump if failed to open
           ldi     'S'                 ; write header
           sep     scall
           dw      output_1
           ldi     low size            ; need size 
           plo     rb
           ldn     rb                  ; get ti
           lbz     sz16                ; jump if 16 bits
           ldi     32                  ; signal 32 bits
           lbr     szgo
sz16:      ldi     16                  ; signal 16 bits
szgo:      sep     scall
           dw      output_1
; **************************************************
; *** Now re-open input file to process 2nd pass ***
; **************************************************
           ldi     low varbase         ; need var base
           plo     rb
           glo     ra                  ; store address
           str     rb
           inc     rb
           ghi     ra
           str     rb
           sep     scall               ; print message
           dw      o_inmsg
           db      'Pass 2.',10,13,0
           ldi     high ifname         ; point to input filename
           phi     rf
           ldi     low ifname
           plo     rf
           ldi     high fildes         ; point to file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; open flags
           plo     r7
           sep     scall               ; attempt to open the file
           dw      o_open
           lbdf    openerr             ; jump if failed to open
           ldi     0                   ; reset address
           phi     ra
           plo     ra
           ldi     low pass            ; point to pass variable
           plo     rb
           ldi     1                   ; set as second pass
           str     rb
           ldi     low compjumps       ; need to check for computed jumps
           plo     rb
           ldn     rb
           lbz     nocomps             ; jump of no computed jumps
           sep     scall               ; output the line address table
           dw      lineout
           ldi     high fildes         ; point to file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
nocomps:   sep     scall               ; invoke a compiler pass
           dw      compile
           lbdf    nogood              ; jump on compile error
           sep     scall               ; close the input file
           dw      o_close
           ldi     high ofildes        ; point to output file descriptor
           phi     rd
           ldi     low ofildes
           plo     rd
           sep     scall               ; and close it
           dw      o_close
           lbr     o_wrmboot           ; and return to caller
nogood:    lbr     o_wrmboot

; **************************************
; *** This is the main compiler loop ***
; **************************************
compile:   ldi     high buffer         ; point to buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; read in next line
           dw      readln
           glo     rc                  ; make sure bytes were read
           lbnz    compgo
           ghi     rc
           lbnz    compgo
           ldi     0ffh                ; put address of exit into address table
           phi     rf
           plo     rf
           sep     scall               ; add it
           dw      add_line
           ldi     OP_WS               ; write a final exit
           sep     scall
           dw      output
           adi     0                   ; indicate successful compile
           sep     sret                ; return to caller
           

compgo:    mov     rf,buffer           ; convert input to uppercase
           sep     scall
           dw      touc
           glo     rd                  ; save file descriptor
           stxd
           ghi     rd
           stxd
           ldi     low pass            ; need to dertermine pass
           plo     rb
           ldn     rb                  ; get pass
           lbz     pass1               ; jump if on first pass
           ldi     low dolist          ; see if listing is enabled
           plo     rb
           ldn     rb
           lbz     pass1               ; jump if not
           ldi     high buffer         ; back to beginning of buffer
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; display the line
           dw      o_msg
           sep     scall               ; and a carriage return
           dw      docrlf
pass1:     ldi     high buffer
           phi     rf
           ldi     low buffer
           plo     rf
           ldi     high tokens         ; point to token buffer
           phi     r9
           ldi     low tokens
           plo     r9
           sep     scall               ; tokenize the line
           dw      tokenize
           ldi     high tokens         ; point to token buffer
           phi     r9
           ldi     low tokens
           plo     r9
           sep     scall               ; process the tokens
           dw      process
           irx                         ; recover source file descriptor
           ldxa
           phi     rd
           ldx
           plo     rd
           lbdf    failure             ; jump on failure
           lbr     compile             ; and loop back for next line

failure:   ldi     high buffer         ; want to print errant line
           phi     rf
           ldi     low buffer
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           sep     scall               ; now a crlf
           dw      docrlf
           ldi     high err_msg        ; point to error message
           phi     rf
           ldi     low err_msg
           plo     rf
           sep     scall               ; and display it
           dw      o_msg
           ldi     low errors          ; point to error counter
           plo     rb
           inc     rb                  ; increment it
           ldn     rb
           adi     1
           str     rb
           dec     rb
           ldn     rb
           adci    0
           str     rb
           ldi     low errhalt         ; see if halt on erros is on
           plo     rb
           ldn     rb
           lbz     compile             ; and continue processing file
           smi     0                   ; indicate compile error
           sep     sret                ; and return

; **************************************
; *** Append inline text to a buffer ***
; *** RF - buffer to append to       ***
; **************************************
append:    lda     r6                  ; read next byte
           str     rf                  ; store into buffer
           inc     rf                  ; point to next character
           lbnz    append              ; loop back if more
           sep     sret                ; return to caller

; ************************************
; *** Read a line from disk file   ***
; *** RD - File Descriptor         ***
; *** RF - Buffer to store line in ***
; *** Returns: RC - Bytes read     ***
; ***          DF=1 - EOF          ***
; ************************************
readln:    ldi     0                   ; set byte count
           phi     rc
           plo     rc
readln1:   sep     scall               ; read a byte
           dw      readbyte
           lbdf    readlneof           ; jump on eof
           plo     re                  ; keep a copy
           smi     32                  ; look for anything below a space
           lbnf    readln1
readln2:   inc     rf                  ; point to next position
           inc     rc                  ; increment character count
           sep     scall               ; read next byte
           dw      readbyte
           lbdf    readlneof           ; jump if end of file
           smi     32                  ; make sure it is positive
           lbdf    readln2             ; loop back on valid characters
           adi     0                   ; signal valid read
readlncnt: ldi     0                   ; need terminator
           str     rf
           sep     sret                ; and return to caller
readlneof: smi     0                   ; signal eof
           lbr     readlncnt

; ******************************
; *** Read 1 byte from file  ***
; *** RF - where to put byte ***
; *** RD - File descriptor   ***
; *** Returns: D - Read byte ***
; ***          DF=1 - error  ***
; ******************************
readbyte:  glo     rc                  ; save consumed register
           stxd
           ghi     rc
           stxd
           ldi     0                   ; setup 1 byte to read
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; call OS to read byte from file
           dw      o_read
           dec     rf                  ; point RF back to byte
           glo     rc                  ; get bytes read count
           lbz     readbno             ; error if no bytes were read
           adi     0                   ; indicate successfull read
readbcnt:  irx                         ; recover consumed register
           ldxa
           phi     rc
           ldx
           plo     rc
           ldn     rf                  ; get read byte 
           sep     sret                ; and return to caller
readbno:   smi     0                   ; signal no bytes read
           lbr     readbcnt

docrlf:    ldi     high crlf
           phi     rf
           ldi     low crlf
           plo     rf
           sep     scall
           dw      o_msg
           sep     sret

; *************************************
; *** Tokenize a string             ***
; *** R9 - Buffer for tokens        ***
; *** RF - Ascii string to tokenize ***
; *** Returns: RC - token count     ***
; ***          DF=1 - error         ***
; *************************************
tokenize:  ldi     0                   ; set initial token count to zero
           phi     rc
           plo     rc
tokenlp:   sep     scall               ; move past any whitespace
           dw      f_ltrim
           ldn     rf                  ; get pointed at character
           lbz     tokendn             ; jump if terminator
           smi     34                  ; check for string
           lbz     charstr             ; jump if so
           sep     scall               ; see if numeric
           dw      f_idnum
           lbnf    tokennum            ; jump if numeric
           ldi     high functable      ; point to function table
           phi     r7
           ldi     low functable
           plo     r7
           sep     scall               ; check for token
           dw      f_findtkn
           lbdf    tokenfunc           ; jump if function

           ldn     rf                  ; get next character
           sep     scall               ; see if alnum
           dw      f_isalnum
           lbdf    ustrlpa             ; jump if it is
           lda     rf                  ; otherwise it is a single character
           str     r9
           inc     r9
           lbr     tokenlp             ; and keep looking for tokens

ustrlpa:   ldi     TKN_USTR            ; token for unquoted strings
ustrlp:    str     r9                  ; store into token stream
           inc     r9
           lda     rf                  ; get next byte
           sep     scall               ; see if alphanumeric
           dw      f_isalnum
           lbdf    ustrlp              ; loop back if so, store, and keep going
           dec     rf                  ; move back to non-string char
           lbr     strdn               ; terminate string 
charstr:   inc     rf                  ; move past opening quote
           ldi     TKN_QSTR            ; token for quoted string
charstrlp: str     r9                  ; store it
           inc     r9
           lda     rf                  ; get next byte of string
           plo     re                  ; save a copy
           lbz     strdn               ; jump if end
           smi     34                  ; check for ending quote
           lbz     strdn               ; also done
           glo     re                  ; recover byte
           lbr     charstrlp           ; and loop back til done
strdn:     ldi     TKN_TERM            ; terminate the string
           str     r9
           inc     r9
           lbr     tokenlp             ; and keep looking for tokens
tokennum:  lbz     numisdec            ; jump if decimal number
           sep     scall               ; convert hex number
           dw      f_hexin
           lbr     numcont             ; continue processing number
numisdec:  push    r7
           push    r8
           sep     scall               ; convert number
           dw      atoi
numcont:   ldi     TKN_NUM             ; get token for number
           str     r9                  ; place into token stream
           inc     r9 
           sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    num16               ; jump if 16 bits
           ghi     r7                  ; write high word
           str     r9
           inc     r9
           glo     r7
           str     r9
           inc     r9
num16:     ghi     r8                  ; now write number
           str     r9
           inc     r9
           glo     r8                  ; and low byte
           str     r9
           inc     r9
           pop     r8
           pop     r7
           lbr     tokenlp             ; loop back for more tokens
tokenfunc: glo     rd                  ; get token number
           ori     080h                ; set high bit
           str     r9                  ; store into token stream
           inc     r9                  ; point to next free space
           lbr     tokenlp             ; and keep searching for tokens
tokendn:   ldi     0                   ; need to terminate token sequence
           str     r9
           adi     0                   ; signal no error
           sep     sret                ; and return to caller

; *********************************
; *** Find address for a line   ***
; *** RF - line number          ***
; *** Returns: R7 - entry       ***
; ***          DF=1 - not found ***
; *********************************
linentry:  ldi     high lines          ; point to line address data
           phi     r7
           ldi     low lines
           plo     r7
           ldi     low lineaddr        ; get end of table
           plo     rb
           lda     rb
           phi     r8                  ; place into r8
           lda     rb
           plo     r8
fndlnlp:   lda     r7                  ; get msb line byte from table
           str     r2                  ; setup for compare
           ghi     rf                  ; get msb of requested line
           sm                          ; check for a match
           lbnz    fndno               ; jump if not a match
           ldn     r7                  ; now to check lsb
           str     r2
           glo     rf                  ; lsb of requested line
           sm                          ; check for match
           lbnz    fndno               ; jump if not
           adi     0                   ; signal success
           sep     sret                ; return postion to caller
fndno:     inc     r7                  ; move to next entry
           inc     r7
           inc     r7
           glo     r8                  ; check against end of table
           str     r2
           glo     r7
           sm
           lbnz    fndlnlp             ; not at end, loop to check next entry
           ghi     r8                  ; check high byte
           str     r2
           ghi     r7
           sm
           lbnz    fndlnlp             ; jump if more entries to check
notfnd:    smi     0                   ; indicate line was not found
           sep     sret                ; and return


; *********************************
; *** Find address for a line   ***
; *** RF - line number          ***
; *** Returns: RF - Address     ***
; ***          DF=1 - not found ***
; *********************************
findline:  sep     scall               ; find entry for line
           dw      linentry
           lbdf    notfnd              ; jump if not found
           inc     r7                  ; found, so point to address
           lda     r7                  ; retrieve address
           phi     rf                  ; and put into RF
           lda     r7
           plo     rf
           adi     0                   ; indicate line was found
           sep     sret                ; return to caller

; **********************************
; *** Find address for next line ***
; *** RF - line number           ***
; *** Returns: RF - Address      ***
; ***          DF=1 - not found  ***
; **********************************
findnext:  sep     scall               ; find entry for line
           dw      linentry
           lbdf    notfnd              ; jump if not found
           inc     r7                  ; move to following entry
           inc     r7
           inc     r7
           inc     r7
           inc     r7                  ; found, so point to address
           lda     r7                  ; retrieve address
           phi     rf                  ; and put into RF
           lda     r7
           plo     rf
           adi     0                   ; indicate line was found
           sep     sret                ; return to caller

; ******************************
; *** Output a compiled byte ***
; *** D - byte to output     ***
; ******************************
output:    inc     ra                  ; increment address
           plo     re                  ; save a copy
           ldi     low pass            ; see what pass we are on
           plo     rb
           ldn     rb
           lbnz    output_1            ; jump if not first pass
           sep     sret                ; return to caller on first pass
output_1:  glo     rf                  ; save consumed registers
           stxd
           ghi     rf
           stxd
           ldi     high data           ; point to output data pointer
           phi     rf
           ldi     low data
           plo     rf
           glo     re                  ; recover value
           str     rf                  ; ready for output
           ldi     high ofildes        ; get output file descriptor
           phi     rd
           ldi     low ofildes
           plo     rd
           ldi     0                   ; 1 byte to write
           phi     rc
           ldi     1
           plo     rc
           sep     scall               ; write it
           dw      o_write
           irx                         ; recover consumed registers
           ldxa
           phi     rf
           ldx
           plo     rf
           sep     sret                ; and return

; *****************************************************
; *** Add line number and address to lineaddr table ***
; *** RF - line number                              ***
; *** RA - address                                  ***
; *****************************************************
add_line:  ldi     low pass            ; can only add during first pass
           plo     rb                  ; put into base page
           ldn     rb                  ; get current pass
           lbnz    add_no              ; do not allow on pass 1
           ldi     low lineaddr        ; point to next line address
           plo     rb                  ; put into base page
           lda     rb                  ; retrieve pointer
           phi     r7                  ; into r7
           ldn     rb
           plo     r7
           ghi     rf                  ; write line number to table
           str     r7
           inc     r7
           glo     rf
           str     r7
           inc     r7
           ghi     ra                  ; write address to table
           str     r7
           inc     r7
           glo     ra
           str     r7
           inc     r7
           glo     r7                  ; write new pointer back to data area
           str     rb
           dec     rb
           ghi     r7
           str     rb
add_no:    sep     sret                ; return

; **********************************
; *** Process a token stream     ***
; *** R9 - pointer to tokens     ***
; *** Returns: DF=1 on error     ***
; ***             D - error code ***
; **********************************
process:   lda     r9                  ; get first token from stream
           smi     TKN_NUM             ; must be a number (line number)
           lbz     process_1           ; jump if line number found
           ldi     ERR_DIRECT          ; indicate direct command error
           smi     0                   ; set DF
           sep     sret                ; and return
process_1: sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    proc1               ; jump if not
           inc     r9                  ; move past first 16 bits
           inc     r9
proc1:     ldi     low linenum         ; point to current line number
           plo     rb
           lda     r9                  ; get msb of line number
           str     rb
           inc     rb
           ldn     r9                  ; get lsb of line number
           str     rb
           dec     r9                  ; move back to msb
           lda     r9                  ; get line number
           phi     rf
           lda     r9
           plo     rf
           sep     scall               ; and add into line address table
           dw      add_line
process_3: lda     r9                  ; get next token
           ani     07fh                ; strip high bit
           plo     re                  ; keep a copy of it
           smi     14                  ; check for PRINT
           lbz     c_print             ; jump if so
           lbnf    syn_err             ; jump on syntax error
           smi     1                   ; check for GOTO
           lbz     c_goto
           smi     1                   ; check for END
           lbz     c_end
           smi     1                   ; check for GOSUB
           lbz     c_gosub
           smi     1                   ; check for RETURN
           lbz     c_return
           smi     1                   ; check for LET
           lbz     c_let
           smi     1                   ; check for IF
           lbz     c_if
           smi     1                   ; check for INPUT
           lbz     c_input
           smi     1                   ; check for REM
           lbz     good                ; ignore this line
           smi     2                   ; check for POKE
           lbz     c_poke
           smi     1                   ; check for DPOKE
           lbz     c_dpoke
           smi     9                   ; check for OUT
           lbz     c_out
           smi     4                   ; check for PLOT
           lbz     c_plot
           smi     1                   ; check for CLS
           lbz     c_cls
           smi     1                   ; check for ION
           lbz     c_ion
           smi     1                   ; check for IOFF
           lbz     c_ioff
           smi     1                   ; check for IRETURN
           lbz     c_ireturn
           smi     1                   ; check for INTR
           lbz     c_intr
           smi     1                   ; check for FOR
           lbz     c_for
           smi     3                   ; check for NEXT
           lbz     c_next
           smi     1                   ; check for ON
           lbz     c_on

           dec     r9                  ; retrieve base token
           lda     r9
           smi     31+80h              ; see if USR
           lbz     c_usr               ; jump if so

           dec     r9                  ; move back to token
           lbr     c_let               ; treat as let
           lbr     syn_err             ; not found is syntax error

; *****************************
; *** Process PLOT statment ***
; *****************************
c_plot:    sep     scall               ; get address
           dw      expr
           lbdf    syn_err             ; jump on error
           lda     r9                  ; get next symbol
           smi     13+80h              ; must be a comma
           lbnz    syn_err
           sep     scall               ; get value to poke
           dw      expr
           lbdf    syn_err             ; jump on expression error
           ldi     OP_PL               ; plot function
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler


;c_plot:    ldi     OP_PL               ; load graphic address
;           sep     scall               ; output it
;           dw      output
;           sep     scall               ; get first argument
;           dw      expr
;           lbdf    syn_err             ; jump on expression error
;           ldn     r9                  ; get next token
;           lbz     plot_a1             ; if terminater then single argument
;           smi     37+80h              ; also check for :
;           lbz     plot_a1
;           lda     r9                  ; need to verify a comma
;           smi     13+80h              ; check for ,
;           lbnz    syn_err             ; jump on error
;           sep     scall               ; evaluate 2nd argument
;           dw      expr
;           lbdf    syn_err             ; jump if expression error
;           ldn     r9                  ; get next token
;           lbz     syn_err             ; cannot have only 2 args
;           smi     37+80h              ; also check for :
;           lbz     syn_err
;           lda     r9                  ; need to verify a comma
;           smi     13+80h              ; check for ,
;           lbnz    syn_err             ; jump if not
;           ldi     OP_SP               ; discard values for now
;           sep     scall               ; output it
;           dw      output
;           ldi     OP_SP               ; discard values for now
;           sep     scall               ; output it
;           dw      output
;           sep     scall               ; evaluate 3rd argument
;           dw      expr
;           lbdf    syn_err             ; jump if expression error
;; *** 1 argument version
;plot_a1:   ldi     OP_DS               ; duplicate top os stack
;           sep     scall               ; output it
;           dw      output
;           ldi     OP_US               ; call USR function
;           sep     scall               ; output it
;           dw      output
;           ldi     OP_SP               ; discard return value
;           sep     scall               ; output it
;           dw      output
;           lbr     stmtend             ; good compile
 
          

; ****************************
; *** Process OUT statment ***
; ****************************
c_out:     sep     scall               ; evaluate 
           dw      expr
           lbdf    syn_err             ; jump on error
           lda     r9                  ; get next token
           smi     13+80h              ; must be a comma
           lbnz    syn_err             ; jump if not 
           sep     scall               ; evaluate 
           dw      expr
           lbdf    syn_err             ; jump on error
           ldi     OP_OU               ; now a OUT call
           sep     scall               ; and output it
           dw      output
stmtend:   lda     r9                  ; get next token
           lbz     good                ; jump if at terminator
           smi     37+80h              ; check for :
           lbz     process_3           ; continue processing line if :
           lbr     syn_err             ; jump if not terminator

; ******************************
; *** Process DPOKE statment ***
; ******************************
c_dpoke:   sep     scall               ; get address
           dw      expr
           lbdf    syn_err             ; jump on error
           lda     r9                  ; get next symbol
           smi     13+80h              ; must be a comma
           lbnz    syn_err
           sep     scall               ; get value to poke
           dw      expr
           lbdf    syn_err             ; jump on expression error
           ldi     OP_DO               ; usr function
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler

; *****************************
; *** Process POKE statment ***
; *****************************
c_poke:    sep     scall               ; get address
           dw      expr
           lbdf    syn_err             ; jump on error
           lda     r9                  ; get next symbol
           smi     13+80h              ; must be a comma
           lbnz    syn_err
           sep     scall               ; get value to poke
           dw      expr
           lbdf    syn_err             ; jump on expression error
           ldi     OP_PO               ; poke function
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler

; ****************************
; *** Process USR statment ***
; ****************************
c_usr:     dec     r9                  ; prepare for later increment
           sep     scall               ; call f_usr code
           dw      f_usr
           lbdf    syn_err             ; jump if error
           ldi     OP_SP               ; discard result
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler

; *****************************
; *** Process INTR statment ***
; *****************************
c_intr:    lda     r9                  ; get next token
           smi     TKN_NUM             ; must be a number
           lbnz    syn_err             ; jump if not a number
           inc     r9                  ; move to following token
           inc     r9
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_intr_2            ; jump if not
           inc     r9
           inc     r9
c_intr_2:  ldn     r9                  ; retrieve it
           dec     r9                  ; move pointer back
           dec     r9
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_intr_3
           dec     r9
           dec     r9
c_intr_3:  lbz     c_intr_g            ; jump if line terminator
           smi     37+80h              ; check for colon
           lbz     c_intr_g            ; jump if so
           lbr     syn_err             ; otherwise error
c_intr_g:  ldi     low pass            ; need to check pass
           plo     rb
           ldn     rb
           lbnz    c_intr_1            ; jump if second pass
           ldi     0                   ; just output 3 anything bytes
           sep     scall
           dw      output
           sep     scall
           dw      output
           sep     scall
           dw      output
           inc     r9                  ; move past line number
           inc     r9
           sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    c_intr_dn
           inc     r9
           inc     r9
c_intr_dn: lbr     stmtend
c_intr_1:  lda     r9                  ; retrieve line number
           phi     rf
           lda     r9
           plo     rf
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_intr_4            ; jump if not
           lda     r9                  ; retrieve actual line number
           phi     rf
           lda     r9
           plo     rf
c_intr_4:  sep     scall               ; retrieve line address
           dw      findline
           lbdf    line_err            ; jump if line was not found
           ldi     OP_IT               ; code for setting interrupt
           sep     scall               ; output it
           dw      output
           ghi     rf                  ; get line address
           sep     scall               ; and output
           dw      output
           glo     rf                  ; get low byte of address
           sep     scall               ; and output
           dw      output
           lbr     c_intr_dn           ; process ending



; ******************************
; *** Process INPUT statment ***
; ******************************
c_input:   ldn     r9                  ; get next token
           smi     TKN_QSTR            ; see if it is a quoted string
           lbnz    input_1             ; jump if not
           ldi     OP_PC               ; need to print the prompt
           sep     scall               ; output the code
           dw      output
           inc     r9                  ; point to first byte
input_l1:  lda     r9                  ; get next character
           plo     re                  ; save for a moment
           ldn     r9                  ; get following byte
           xri     0ffh                ; see if terminator
           lbz     input_2             ; jump if so
           glo     re                  ; recover character
           sep     scall               ; output it
           dw      output
           lbr     input_l1            ; loop back for more
input_2:   glo     re                  ; recover character
           ori     80h                 ; set high bit
           sep     scall               ; output it
           dw      output
           inc     r9                  ; move past terminatoer
input_c:   lda     r9                  ; get next token
           smi     13+80h              ; must be a comma
           lbnz    syn_err             ; otherwise syntax error
input_1:   lda     r9                  ; get next token
           smi     TKN_USTR            ; must be unquoted string (variable)
           lbnz    syn_err             ; jump if not
           ldi     OP_LW               ; function to load a word
           sep     scall               ; output it
           dw      output
           sep     scall               ; get variable address
           dw      getvar
           ghi     rf                  ; high byte of address
           sep     scall               ; output it
           dw      output
           glo     rf                  ; low byte of address
           sep     scall               ; output it
           dw      output
           ldi     OP_GL               ; function to get input
           sep     scall               ; output it
           dw      output
           ldi     OP_SV               ; save into variable
           sep     scall               ; output it
           dw      output
           ldn     r9                  ; get next token
           lbz     stmtend             ; jump if terminator
           smi     37+80h              ; check for colon
           lbz     stmtend             ; jump if so
           lbr     input_c             ; jump if not terminator


; ***************************
; *** Process IF statment ***
; ***************************
c_if:      sep     scall               ; evaluate expression following IF
           dw      expr
           lbdf    syn_err             ; jump if evaluation error
           lda     r9                  ; get comparison
           smi     086h                ; check for =
           lbz     if_eq               ; jump if so
           smi     1                   ; check for <=
           lbz     if_le
           smi     1                   ; check for >=
           lbz     if_ge
           smi     1                   ; check for <>
           lbz     if_ne
           smi     1                   ; check for <
           lbz     if_lt
           smi     1                   ; check for >
           lbz     if_gt
           lbr     syn_err             ; invalid comparison
if_eq:     ldi     2                   ; setup comparison
           lskp
if_le:     ldi     3
           lskp
if_ge:     ldi     6
           lskp
if_ne:     ldi     5
           lskp
if_lt:     ldi     1
           lskp
if_gt:     ldi     4
           stxd                        ; save this
           ldi     OP_LB               ; need to load byte to stack
           sep     scall               ; output it
           dw      output
           irx                         ; recover mask
           ldx
           sep     scall               ; and output it
           dw      output
           sep     scall               ; evalute 2nd expression
           dw      expr
           lbdf    syn_err             ; jump on error
           ldi     OP_CP               ; need comparison operator
           sep     scall               ; output it
           dw      output
           sep     scall               ; get next line address
           dw      nxtlnadr
           ghi     rf                  ; get msb of next line address
           adi     080h                ; convert to J code
           sep     scall               ; and then output
           dw      output
           glo     rf                  ; get lsb of address
           sep     scall               ; and output
           dw      output
           ldn     r9                  ; get next token
           smi     23+80h              ; is it THEN
           lbnz    process_3           ; jump to process next token
           inc     r9                  ; move past THEN
           lbr     process_3           ; and keep processing

; ****************************
; *** Process LET statment ***
; ****************************
c_let:     lda     r9                  ; get token following LET
           smi     TKN_USTR            ; must be unquoted string (variable)
           lbnz    syn_err             ; otherwise syntax error

           ldi     OP_LW               ; function to load a word
           sep     scall               ; output it
           dw      output
           sep     scall               ; get variable address
           dw      getvar
           ghi     rf                  ; high byte of address
           sep     scall               ; output it
           dw      output
           glo     rf                  ; low byte of address
           sep     scall               ; output it
           dw      output

           lda     r9                  ; get next token
           smi     086h                ; must be =
           lbnz    syn_err             ; otherwise syntax error
           sep     scall               ; evaluate expression
           dw      expr
           lbdf    syn_err             ; jump if expression error
           ldi     OP_SV               ; function to set variable
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler

; ****************************
; *** Process FOR statment ***
; ****************************
c_for:     lda     r9                  ; get token following LET
           smi     TKN_USTR            ; must be unquoted string (variable)
           lbnz    syn_err             ; otherwise syntax error

           ldi     OP_LW               ; function to load a word
           sep     scall               ; output it
           dw      output
           sep     scall               ; get variable address
           dw      getvar
           mov     r7,rf               ; keep a copy of variable address
           ghi     rf                  ; high byte of address
           sep     scall               ; output it
           dw      output
           glo     rf                  ; low byte of address
           sep     scall               ; output it
           dw      output

           lda     r9                  ; get next token
           smi     086h                ; must be =
           lbnz    syn_err             ; otherwise syntax error
           sep     scall               ; evaluate expression
           dw      expr
           lbdf    syn_err             ; jump if expression error
           ldi     OP_SV               ; function to set variable
           sep     scall               ; output it
           dw      output

           lda     r9                  ; get next token
           smi     0adh                ; must be TO token
           lbnz    syn_err             ; otherwise syntax error

           sep     scall               ; evaluate expression
           dw      expr
           lbdf    syn_err             ; jump if expression error

           ldi     OP_LN               ; need to push step
           sep     scall               ; output il code
           dw      output

           sep     scall               ; check for 32-bits
           dw      is32bit
           lbnf    c_for1              ; jump if not
           ldi     0                   ; store 1 as the step for now
           sep     scall               ; output high word
           dw      output
           ldi     0                   ; store 1 as the step for now
           sep     scall
           dw      output
c_for1:    ldi     0                   ; store 1 as the step for now
           sep     scall               ; output lsw of step
           dw      output
           ldi     1
           sep     scall
           dw      output

           ldi     OP_LW               ; need to load address
           sep     scall
           dw      output
           glo     ra                  ; need to setup address
           adi     5                   ; 5 bytes from here
           plo     rf
           ghi     ra
           adci    0
           sep     scall               ; output high byte
           dw      output
           glo     rf                  ; output low byte
           sep     scall
           dw      output

           ldi     OP_LW               ; lastly we need the index variable
           sep     scall
           dw      output
           ghi     r7
           sep     scall
           dw      output
           glo     r7
           sep     scall
           dw      output

           lbr     stmtend             ; good compiler

; *****************************
; *** Process NEXT statment ***
; *****************************
c_next:    lda     r9                  ; get token following LET
           smi     TKN_USTR            ; must be unquoted string (variable)
           lbnz    syn_err             ; otherwise syntax error

           ldi     OP_LW               ; function to load a word
           sep     scall               ; output it
           dw      output
           sep     scall               ; get variable address
           dw      getvar
           ghi     rf                  ; high byte of address
           sep     scall               ; output it
           dw      output
           glo     rf                  ; low byte of address
           sep     scall               ; output it
           dw      output

           ldi     OP_NX               ; IL code for NEXT
           sep     scall               ; output it
           dw      output
           lbr     stmtend             ; good compiler

; *****************************
; *** Process CLS statement ***
; *****************************
c_cls:     ldi     OP_CL               ; get opcode for cls
           sep     scall               ; and output it
           dw      output
           lbr     stmtend             ; done with statement

; *****************************
; *** Process ION statement ***
; *****************************
c_ion:     ldi     OP_IE               ; get opcode to enable interrupts
           sep     scall               ; and output it
           dw      output
           lbr     stmtend             ; done with statement

; *****************************
; *** Process ION statement ***
; *****************************
c_ioff:    ldi     OP_ID               ; get opcode to disable interrupts
           sep     scall               ; and output it
           dw      output
           lbr     stmtend             ; done with statement

; *****************************
; *** Process END statement ***
; *****************************
c_end:     ldi     OP_WS               ; get opcode for end
           sep     scall               ; and output it
           dw      output
           lda     r9                  ; get next token
           lbnz    syn_err             ; syntax error if not terminator
good:      adi     0                   ; signal good
           sep     sret                ; and return

; ********************************
; *** Process RETURN statement ***
; ********************************
c_return:  ldi     OP_RT               ; get opcode for return
           sep     scall               ; and output it
           dw      output
           lda     r9                  ; get next token
           lbnz    syn_err             ; syntax error if not terminator
           lbr     good                ; return as good command

; *********************************
; *** Process IRETURN statement ***
; *********************************
c_ireturn: ldi     OP_IR               ; get opcode for return
           sep     scall               ; and output it
           dw      output
           lda     r9                  ; get next token
           lbnz    syn_err             ; syntax error if not terminator
           lbr     good                ; return as good command

; *******************************
; *** Process GOSUB statement ***
; *******************************
c_gosub:   ldi     OP_JS               ; opcode for jump
           lbr     jumpcont            ; continue processing

; ******************************
; *** Process GOTO statement ***
; ******************************
c_goto:    ldi     OP_J                ; opcode for jump
jumpcont:  plo     r7                  ; save it
           lda     r9                  ; get next token
           smi     TKN_NUM             ; must be a number
           lbnz    c_cgoto             ; try computed jump
           inc     r9                  ; move to following token
           inc     r9
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_goto_2            ; jump if not
           inc     r9
           inc     r9
c_goto_2:  ldn     r9                  ; retrieve it
           dec     r9                  ; move pointer back
           dec     r9
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_goto_3
           dec     r9
           dec     r9
c_goto_3:  lbz     c_goto_g            ; jump if line terminator
           smi     37+80h              ; check for colon
           lbz     c_goto_g            ; jump if so
           lbr     c_cgoto             ; treat as computed goto
;           lbnz    syn_err             ; syntax error if not
c_goto_g:  ldi     low pass            ; need to check pass
           plo     rb
           ldn     rb
           lbnz    c_goto_1            ; jump if second pass
           glo     r7                  ; get opcode
           xri     OP_JS               ; is it gosub
           lbnz    c_goto_g1           ; jump if not
           ldi     0                   ; gosub is a third byte
           sep     scall
           dw      output
c_goto_g1: ldi     0                   ; just output 2 anything bytes
           sep     scall
           dw      output
           sep     scall
           dw      output
           inc     r9                  ; move past line number
           inc     r9
           sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    c_goto_dn
           inc     r9
           inc     r9
c_goto_dn: lbr     stmtend
c_goto_1:  lda     r9                  ; retrieve line number
           phi     rf
           lda     r9
           plo     rf
           sep     scall               ; check for 32 bit
           dw      is32bit
           lbnf    c_goto_4            ; jump if not
           lda     r9                  ; retrieve actual line number
           phi     rf
           lda     r9
           plo     rf
c_goto_4:  glo     r7                  ; save opcode
           stxd
           sep     scall               ; retrieve line address
           dw      findline
           irx                         ; recover opcode
           ldx
           lbdf    line_err            ; jump if line was not found
           smi     OP_JS               ; check for gosub
           lbz     c_gosub1            ; jump if so
           ldx                         ; recover opcode
           plo     r7
           glo     r7                  ; get opcode offset
           str     r2                  ; prepare for add
           ghi     rf                  ; get line address
           add                         ; add in opcode offset
c_goto_5:  sep     scall               ; and output
           dw      output
           glo     rf                  ; get low byte of address
           sep     scall               ; and output
           dw      output
           lbr     c_goto_dn           ; process ending

c_gosub1:  ldi     OP_JS               ; code for subroutine
           sep     scall               ; output it
           dw      output
           ghi     rf                  ; msb of jump address
           lbr     c_goto_5            ; output the rest

c_cgoto:   dec     r9                  ; move back one token
           sep     scall               ; compute line number
           dw      expr
           glo     r7                  ; get command
           smi     OP_J                ; was it J
           lbz     c_cgoto_j           ; jump if so
           ldi     OP_TS               ; opcode for table sub
c_cgotoct: sep     scall               ; output it
           dw      output
           ldi     low compjumps       ; need to signal computed jumps
           plo     rb
           ldi     1
           str     rb
           lbr     stmtend             ; check proper end
c_cgoto_j: ldi     OP_TJ               ; opcode for table jump
           lbr     c_cgotoct           ; continue

c_on:      sep     scall               ; process expression
           dw      expr
           lbdf    syn_err             ; jump if error in expression
           ldn     r9                  ; get next token
           smi     08fh                ; check for Goto
           lbz     c_ongoto            ; jump if goto
           ldn     r9                  ; recover command
           smi     091h                ; check for Gosub
           lbz     c_ongosub           ; jump if so
           lbr     syn_err             ; otherwise syntax error
c_ongoto:  ldi     OP_OJ               ; token for ON GOTO
           nlbr                        ; skip next two bytes
c_ongosub: ldi     OP_OS               ; token for ON GOSUB
           sep     scall               ; output it
           dw      output
           inc     r9                  ; move to next token
c_on_lp:   lda     r9                  ; get next token
           smi     TKN_NUM             ; must be a number
           lbnz    syn_err             ; jump if not a number
           lda     r9                  ; retrieve line number
           phi     rf
           lda     r9
           plo     rf
           sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    c_on_1              ; jump if not
           lda     r9                  ; retrieve line number
           phi     rf
           lda     r9
           plo     rf
c_on_1:    ldi     low pass            ; need to check pass
           plo     rb
           ldn     rb
           lbnz    c_on_2              ; jump if second pass
           ldi     0                   ; otherwise just output 2 zeroes
           sep     scall
           dw      output
           sep     scall
           dw      output
           lbr     c_on_3              ; and continue
c_on_2:    sep     scall               ; retrieve line address
           dw      findline
           ghi     rf                  ; output line number
           sep     scall
           dw      output
           glo     rf
           sep     scall
           dw      output
c_on_3:    lda     r9                  ; get next token
           plo     r7                  ; save it
           smi     08dh                ; check for comma
           lbz     c_on_lp             ; process next line number
           dec     r9                  ; backup pointer
           ldi     0ffh                ; mark end of line numbers
           sep     scall
           dw      output
           ldi     0ffh                ; mark end of line numbers
           sep     scall
           dw      output
           lbr     stmtend             ; done with statement


; *******************************
; *** Process PRINT statement ***
; *******************************
c_print:   lda     r9                  ; get next token
           lbz     prt_done            ; jump if terminator
           plo     re                  ; keep a copy
           smi     37+80h              ; also check for :
           lbz     prt_done
           glo     re
           smi     TKN_QSTR            ; is it a quoted string
           lbz     prt_qstr            ; jump if so
           glo     re                  ; check for semi-colon
           smi     12+80h
           lbz     prt_semi            ; jump if so
           glo     re                  ; check for comma
           smi     13+80h
           lbz     prt_comma           ; jump if so
           dec     r9                  ; move back a byte
           sep     scall               ; try evaluating as an expression
           dw      expr
           lbdf    syn_err             ; jump on error
           ldi     OP_PN               ; need to print the number
           sep     scall               ; output code
           dw      output
           lbr     c_print             ; loop back for more
prt_done:  ldi     OP_NL               ; output print new line code
           sep     scall
           dw      output
           dec     r9                  ; point back to termination
           lbr     stmtend             ; good compiler
prt_comma: ldi     OP_PT               ; output print tab code
           sep     scall
           dw      output
prt_semi:  ldn     r9                  ; see if next token is terminator
           lbnz    c_print             ; loop back for more if not
           adi     0                   ; indicate no error
           sep     sret                ; and return
prt_qstr:  ldi     OP_PC               ; opcode to print constant string
           sep     scall               ; output it
           dw      output
qstr_lp:   lda     r9                  ; get next byte
           plo     re                  ; keep for a moment
           ldn     r9                  ; get following byte
           xri     0ffh                ; see if string terminator
           lbz     qstrterm            ; jump if so
           glo     re                  ; retreive byte
           sep     scall               ; output it
           dw      output
           lbr     qstr_lp             ; loop back for more
qstrterm:  glo     re                  ; retrieve byte
           ori     080h                ; set high bit
           sep     scall               ; output it
           dw      output
           inc     r9                  ; move past string terminator
           lbr     c_print             ; and check for more printing

; **************
; *** Errors ***
; **************
line_err:  ldi     ERR_NOLN            ; indicate line does not exist
           lskp
syn_err:   ldi     ERR_SYN             ; indicate syntax error
           smi     0                   ; indicate error
           sep     sret                ; and return

; *********************************
; *** Find address of next line ***
; *********************************
nxtlnadr:  ldi     low pass            ; see what pass we are on
           plo     rb
           ldn     rb
           lbnz    nxtln_1             ; jump if pass 2
           ldi     0                   ; return zeros for pass 0
           phi     rf
           plo     rf
           sep     sret                ; and return to caller
nxtln_1:   ldi     low linenum         ; need current line number
           plo     rb                  ; put into base register
           lda     rb                  ; get current line number
           phi     rf                  ; and put into rf
           ldn     rb
           plo     rf
           sep     scall               ; get address of next line
           dw      findnext
           lbdf    syn_err             ; error if not found
           adi     0                   ; signal found
           sep     sret                ; and return

; **********************************
; *** Compile expressions        ***
; *** R9 - Pointer to expression ***
; *** Returns: DF=1 error        ***
; **********************************
expr:      ldn     r9                  ; get first character of epxressions
           smi     81h                 ; check for negative sign
           lbnz    expr_p              ; not negative, check for positive
           inc     r9                  ; move to next token
           sep     scall               ; call level 2 to get value
           dw      expr_l2
           lbdf    expr_err            ; exit out on error
           ldi     OP_NE               ; need negate opcode
           sep     scall               ; output it
           dw      output
           lbr     expr_lp             ; jump to main expression loop
expr_p:    ldn     r9                  ; get first character
           smi     80h                 ; check for positive
           lbr     expr_np             ; jump if no plus sign
           inc     r9                  ; ignore the plus sing
expr_np:   sep     scall               ; call level 2 to get value
           dw      expr_l2
           lbdf    expr_err            ; exit out on error
expr_lp:   ldn     r9                  ; get next token
           smi     26+80h              ; check for &
           lbnz    expr_1_1            ; jump if not
           ldi     OP_AN               ; operation is AND
expr_l1g:  stxd                        ; save operation code
           inc     r9                  ; move to next token
           sep     scall               ; get next value
           dw      expr_l2
           irx                         ; recover operation value
           ldx
           lbdf    expr_err            ; exit out on error
           sep     scall               ; and output it
           dw      output
           lbr     expr_lp             ; loop back for more terms
expr_1_1:  ldn     r9                  ; recover token
           smi     27+80h              ; check for |
           lbnz    expr_1_2            ; jump if not
           ldi     OP_OR               ; need OR operator
           lbr     expr_l1g            ; and process
expr_1_2:  ldn     r9                  ; recover token
           smi     28+80h              ; check for ^
           lbnz    expr_1_3            ; jump if not
           ldi     OP_XR               ; need XR operator
           lbr     expr_l1g            ; and process
expr_1_3:  adi     0                   ; signal no error
           sep     sret                ; end of expression, so return
; *************************************
; *** Level 2 of evaluator: + and - ***
; *************************************
expr_l2:   sep     scall               ; call level 3 for value
           dw      expr_l3
           lbdf    expr_err            ; exit out on error
expr_l2lp: ldn     r9                  ; get token
           smi     80h                 ; check for + token
           lbnz    expr_2_1            ; jump if not
           ldi     OP_AD               ; need add operation
expr_l2g:  stxd                        ; save operation code
           inc     r9                  ; point to next token
           sep     scall               ; and retrieve value
           dw      expr_l3
           irx                         ; recover operation code
           ldx
           lbdf    expr_err            ; exit out on error
           sep     scall               ; and output it
           dw      output
           lbr     expr_l2lp           ; loop back for more
expr_2_1:  ldn     r9                  ; recover token
           smi     81h                 ; check for - token
           lbnz    expr_2_2            ; jump if not
           ldi     OP_SU               ; need subtraction operator
           lbr     expr_l2g            ; process it
expr_2_2:  adi     0                   ; signal no error
           sep     sret                ; return to caller
; *************************************
; *** Level 3 of evaluator: * and / ***
; *************************************
expr_l3:   sep     scall               ; call level 4 for value
           dw      expr_l4
           lbdf    expr_err            ; exit out on error
expr_l3lp: ldn     r9                  ; get next token
           smi     082h                ; check for *
           lbnz    expr_3_1            ; jump if not
           ldi     OP_MP               ; need multiply operator
expr_l3g:  stxd                        ; save operation code
           inc     r9                  ; point to next token
           sep     scall               ; and retrieve value
           dw      expr_l4
           irx                         ; recover operation code
           ldx
           lbdf    expr_err            ; exit out on error
           sep     scall               ; and output it
           dw      output
           lbr     expr_l3lp           ; loop back for more
expr_3_1:  ldn     r9                  ; recover token
           smi     083h                ; check for /
           lbnz    expr_3_2            ; jump if not
           ldi     OP_DV               ; need divide operator
           lbr     expr_l3g            ; and process
expr_3_2:  adi     0                   ; signal no error
           sep     sret                ; return to caller
; **********************************************************************
; *** Level 4 of evaluator: numbers, variables, functions, sub-exprs ***
; **********************************************************************
expr_l4:   ldn     r9                  ; get token
           smi     TKN_NUM             ; is it a number
           lbnz    expr_4_1            ; jump if not
           inc     r9                  ; point to msb of number
           ldi     OP_LN               ; operator to load a number
           sep     scall               ; output it
           dw      output
           lda     r9                  ; get msb of number
           sep     scall               ; and output it
           dw      output
           lda     r9                  ; get lsb of number
           sep     scall               ; and output it
           dw      output
           sep     scall               ; check for 32 bits
           dw      is32bit
           lbnf    expr_l4a            ; jump if not
           lda     r9                  ; write lsw
           sep     scall
           dw      output
           lda     r9
           sep     scall
           dw      output
expr_l4a:  adi     0                   ; signal no error
           sep     sret                ; return to caller
; ************************************
; *** Not a number, try a variable ***
; ************************************
expr_4_1:  ldn     r9                  ; get token
           smi     TKN_USTR            ; look for unquoted string (variable)
           lbnz    expr_4_2            ; jump if not
           inc     r9                  ; move to beginning of name
           ldi     OP_LW               ; function to load a word
           sep     scall               ; output it
           dw      output
           sep     scall               ; get variable address
           dw      getvar
           ghi     rf                  ; high byte of address
           sep     scall               ; output it
           dw      output
           glo     rf                  ; low byte of address
           sep     scall               ; output it
           dw      output
           ldi     OP_FV               ; then a fetch variable code
           sep     scall               ; output it
           dw      output
           ldi     0                   ; signal no error
           shr
           sep     sret                ; then return to caller

;           ldn     r9                  ; retrieve varialbe name
;           plo     re                  ; save a coyp
;           smi     'a'                 ; see if lowercase
;           lbnf    expr_4_1a           ; jump if already uppercase
;           glo     re                  ; recover value
;           smi     32                  ; convert to UC
;           plo     re                  ; save it
;expr_4_1a: glo     re                  ; get name
;           smi     040h                ; subtract bias
;           shl                         ; multiply by 2
;           sep     scall               ; check for 32 bites
;           dw      is32bit
;           lbnf    expr_4_1c           ; jump if not
;           shl                         ; multiply by 4
;expr_4_1c: adi     080h                ; add bias back
;           stxd                        ; save for a moment
;           ldi     OP_LB               ; signal load byte operator
;           sep     scall               ; output it
;           dw      output
;           irx                         ; recover variable address
;           ldx
;           sep     scall               ; and output it
;           dw      output
;           ldi     OP_FV               ; then a fetch variable code
;           sep     scall               ; output it
;           dw      output
;expr_4_1b: lda     r9                  ; get byte from string
;           xri     0ffh                ; look for terminator
;           lbnz    expr_4_1b           ; loop until terminator found
;           adi     0                   ; signal no error
;           sep     sret                ; then return

; ************************************
; *** Not a variable, try sub-expr ***
; ************************************
expr_4_2:  ldn     r9                  ; recover token
           smi     84h                 ; look for (
           lbnz    expr_4_3            ; jump if not
           inc     r9                  ; move past paren
           sep     scall               ; and call evaluator for sub-expr
           dw      expr
           ldn     r9                  ; get next token
           smi     085h                ; must be )
           lbnz    expr_err            ; jump if an error
           inc     r9                  ; move past ) symbol
           adi     0                   ; signal no error
           sep     sret                ; and return

; ***************************************
; *** Not a sub-expr, check functions ***
; ***************************************
expr_4_3:  ldn     r9                  ; get token
           smi     29+80h              ; check for PEEK
           lbz     f_peek              ; jump if so
           smi     1                   ; check for DPEEK
           lbz     f_dpeek             ; jump if so
           smi     1                   ; check for USR
           lbz     f_usr               ; jump if so
           smi     1                   ; check for FRE
           lbz     f_fre               ; jump if so
           smi     1                   ; check for RND
           lbz     f_rnd               ; jump if so
           smi     2                   ; check for INP
           lbz     f_inp               ; jump if so
           smi     1                   ; check for FLG
           lbz     f_flg               ; jump if so

expr_err:  smi     0                   ; signal an error
           sep     sret                ; and return

; ******************************
; *** Process FLG() function ***
; ******************************
f_flg:     inc     r9                  ; move past FLG token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression for port
           dw      expr
           lbdf    expr_err            ; jump if expression error
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err            ; otherwise error
           ldi     OP_FG               ; perform FLG call
           sep     scall
           dw      output
           adi     0                   ; signal success
           sep     sret                ; and return

; ******************************
; *** Process INP() function ***
; ******************************
f_inp:     inc     r9                  ; move past INP token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression for port
           dw      expr
           lbdf    expr_err            ; jump if expression error
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err            ; otherwise error
           ldi     OP_IN               ; perform INP call
           sep     scall
           dw      output
           adi     0                   ; signal success
           sep     sret                ; and return

; ******************************
; *** Process RND() function ***
; ******************************
f_rnd:     inc     r9                  ; move past INP token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression for port
           dw      expr
           lbdf    expr_err            ; jump if expression error
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err            ; otherwise error
           ldi     OP_RN               ; perform INP call
           sep     scall
           dw      output
           adi     0                   ; signal success
           sep     sret                ; and return

;f_rnd:     inc     r9                  ; move past RND token
;           lda     r9                  ; get next token
;           smi     084h                ; must be a (
;           lbnz    expr_err            ; otherwise error
;           ldi     high rtable1        ; point to code for RND
;           phi     rf
;           ldi     low rtable1
;           plo     rf
;rnd_1:     lda     rf                  ; load next value from table
;           lbz     rnd_2               ; jump if end found
;           sep     scall               ; otherwise output value
;           dw      output
;           lbr     rnd_1               ; loop until completed
;rnd_2:     sep     scall               ; evaluate argument
;           dw      expr
;           lbdf    expr_err            ; jump if error
;           lda     r9                  ; get next token
;           smi     085h                ; must be a )
;           lbnz    expr_err            ; otherwise error
;           ldi     high rtable2        ; point to code for RND
;           phi     rf
;           ldi     low rtable2
;           plo     rf
;rnd_3:     lda     rf                  ; load next value from table
;           xri     0ffh                ; check for end
;           lbz     rnd_4               ; jump if end found
;           xri     0ffh                ; restore value
;           sep     scall               ; otherwise output value
;           dw      output
;           lbr     rnd_3               ; loop until completed
;rnd_4:     adi     0                   ; signal good
;           sep     sret                ; and return

; ******************************
; *** Process FRE() function ***
; ******************************
f_fre:     inc     r9                  ; move past FRE token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err            ; otherwise error
           ldi     OP_FR               ; output bytes to implement FRE
           sep     scall
           dw      output
           adi     0                   ; signal good
           sep     sret                ; and return
            
; ******************************
; *** Process USR() function ***
; ******************************
f_usr:     inc     r9                  ; move past USR token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression (address)
           dw      expr
           lbdf    syn_err             ; jump if error
           ldn     r9                  ; get next token
           smi     85h                 ; check for )
           lbz     usr_n2              ; jump if so
           ldn     r9                  ; get next token
           smi     13+80h              ; check for a comma
           lbnz    syn_err             ; otherwise syntax error
           inc     r9                  ; move into expression
           sep     scall               ; evaluate expression (address)
           dw      expr
           lbdf    syn_err             ; jump if error
           ldn     r9                  ; get next token
           smi     85h                 ; check for )
           lbz     usr_n1              ; jump if so
           ldn     r9                  ; get next token
           smi     13+80h              ; check for a comma
           lbnz    syn_err             ; otherwise syntax error
           inc     r9                  ; move into expression
           sep     scall               ; evaluate expression (address)
           dw      expr
           lbdf    syn_err             ; jump if error
           lda     r9
           smi     085h                ; must be a )
           lbnz    expr_err
usr_go:    ldi     OP_US               ; need USR code
           sep     scall               ; output it
           dw      output
           adi     0                   ; signal good
           sep     sret                ; and return
usr_n2:    ldi     OP_DS               ; code to duplicate TOS
           sep     scall               ; output it
           dw      output
usr_n1:    ldi     OP_DS               ; code to duplicate TOS
           sep     scall               ; output it
           dw      output
           inc     r9                  ; move past )
           lbr     usr_go              ; and continue

; *******************************
; *** Process PEEK() function ***
; *******************************
f_peek:    inc     r9                  ; move past PEEK token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression
           dw      expr
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err
           ldi     OP_PE               ; opcode for peek
           sep     scall               ; output it
           dw      output
           adi     0                   ; signal no error
           sep     sret                ; then return

; ********************************
; *** Process DPEEK() function ***
; ********************************
f_dpeek:   inc     r9                  ; move past PEEK token
           lda     r9                  ; get next token
           smi     084h                ; must be a (
           lbnz    expr_err            ; otherwise error
           sep     scall               ; evaluate expression
           dw      expr
           lda     r9                  ; get next token
           smi     085h                ; must be a )
           lbnz    expr_err
           ldi     OP_DE               ; opcode for dpeek call
           sep     scall               ; output it
           dw      output
           adi     0                   ; signal no error
           sep     sret                ; then return

; *********************************
; *** output line-address table ***
; *********************************
lineout:   ldi     0ffh                ; put marker that line table is present
           sep     scall
           dw      output
           ldi     high lines          ; point to line address data
           phi     r7
           ldi     low lines
           plo     r7
           ldi     low lineaddr        ; get end of table
           plo     rb
           lda     rb
           phi     r8                  ; place into r8
           lda     rb
           plo     r8
lineoutlp: glo     r7                  ; check if at end of table
           str     r2
           glo     r8
           sm
           lbnz    lineoutgo           ; jump if not
           ghi     r7                  ; check high byte
           str     r2
           ghi     r8
           sm
           lbnz    lineoutgo           ; jump if not at end
           ldi     0                   ; write 2 zeroes
           sep     scall
           dw      output
           ldi     0                   ; write 2 zeroes
           sep     scall
           dw      output
           sep     sret                ; return to caller
lineoutgo: lda     r7                  ; copy byte from table to output
           sep     scall
           dw      output
           lbr     lineoutlp           ; loop until end of table

is32bit:   stxd                        ; save D
           glo     rb
           str     r2
           ldi     low size            ; point to size
           plo     rb
           ldn     rb                  ; get size
           lbz     is32bitn            ; jump if not 32 bits
           ldi     1                   ; signal 32 bits
is32bitgo: shr                         ; shift into df
           ldxa                        ; recover rb.0
           plo     rb
           ldx                         ; recover D
           sep     sret                ; and return
is32bitn:  ldi     0                   ; signal 16 bits
           lbr     is32bitgo
           
; **********************************
; ***** Convert ascii to int32 *****
; ***** RF - buffer to ascii   *****
; ***** Returns R7:R8 result   *****
; ***** Uses: RA - digits msb  *****
; *****       R9 - counters    *****
; **********************************
atoi:      push    ra           ; save consumed registers
           push    rb
           push    r9
           mov     r7,r2        ; keep the last position for moment
           ldi     10           ; need 10 work bytes on the stack
           plo     re
atoi1:     ldi     0            ; put a zero on the stack
           stxd
           dec     re           ; decrement count
           glo     re           ; see if done
           lbnz    atoi1        ; loop until done
           ldi     0            ; need to get count of characters
           plo     re
atoi2:     ldn     rf           ; get character from RF
           smi     '0'          ; see if below digits
           lbnf    atoi3        ; jump if not valid digit
           ldn     rf           ; recover byte
           smi     '9'+1        ; check if above digits
           lbdf    atoi3        ; jump if not valid digit
           inc     rf           ; point to next character
           inc     re           ; increment count
           lbr     atoi2        ; loop until non character found
atoi3:     mov     rb,rf
           glo     re           ; were any valid digits found
           lbnz    atoi4        ; jump if so
           mov     rb,rf
           ldi     0            ; otherwise result is zero
           plo     r7
           phi     r7
           plo     r8
           phi     r8
atoidn:    glo     r2           ; clear work bytes off stack
           adi     10
           plo     r2
           ghi     r2
           adci    0
           phi     r2
           mov     rf,rb        ; recover ending position
           pop     r9           ; recover consumed registers
           pop     rb
           pop     ra
           sep     sret         ; and return to caller
atoi4:     dec     rf           ; move back to last valid character
           ldn     rf           ; get digit
           smi     030h         ; convert to binary
           str     r7           ; store into work space
           dec     r7
           dec     re           ; decrement count
           glo     re           ; see if done
           lbnz    atoi4        ; loop until all digits copied
           ldi     0            ; need to clear result
           plo     r7
           phi     r7
           plo     r8
           phi     r8
           ldi     32           ; 32 bits to process
           plo     r9
atoi5:     ldi     10           ; need to shift 10 cells
           plo     re
           mov     ra,r2        ; point to msb
           inc     ra
           ldi     0            ; clear carry bit
           shr
atoi6:     ldn     ra           ; get next cell
           lbnf    atoi6a       ; Jump if no need to set a bit
           ori     16           ; set the incoming bit
atoi6a:    shr                  ; shift cell right
           str     ra           ; store new cell value
           inc     ra           ; move to next cell
           dec     re           ; decrement cell count
           glo     re           ; see if done
           lbnz    atoi6        ; loop until all cells shifted
           ghi     r7           ; shift remaining bit into answer
           shrc
           phi     r7
           glo     r7
           shrc
           plo     r7
           ghi     r8
           shrc
           phi     r8
           glo     r8
           shrc
           plo     r8
           ldi     10           ; need to check 10 cells
           plo     re
           mov     ra,r2        ; point ra to msb
           inc     ra
atoi7:     ldn     ra           ; get cell value
           ani     8            ; see if bit 3 is set
           lbz     atoi7a       ; jump if not
           ldn     ra           ; recover value
           smi     3            ; minus 3
           str     ra           ; put it back
atoi7a:    inc     ra           ; point to next cell
           dec     re           ; decrement cell count
           glo     re           ; see if done
           lbnz    atoi7        ; loop back if not
           dec     r9           ; decrement bit count
           glo     r9           ; see if done
           lbnz    atoi5        ; loop back if more bits
           lbr     atoidn       ; otherwise done

; ********************************************
; ***** Variable table, builds downwards *****
; ***** Byte 0 - Type, 0=end of table    *****
; ***** Byte 1 - size                    *****
; ***** Byte 2..n - ASCIIZ variable name *****
; ********************************************
; ***************************************************
; ***** Get address of where variable is stored *****
; ***** R9 - token stream, pointing at name     *****
; ***** Returns: RF - variable address          *****
; *****          R9 - following variable name   *****
; ***************************************************
getvar:     push    r7           ; save consumed registers
            push    rc
            ldi     low vars     ; need to point to variable table
            plo     rb
            lda     rb           ; retrieve variable table address
            plo     rf           ; store into rf
            lda     rb
            phi     rf           ; rf now points to variable table
            ldi     0            ; address offset starts at 0
            plo     rc
            phi     rc
getvar1:    ldn     rf           ; get next type
            lbz     newvar       ; new variable if end of table encountered
            push    rf           ; save positions
            push    r9
            dec     rf           ; now points at size
            dec     rf           ; now pointing at variable name
getvar2:    lda     r9           ; get next byte of token stream
            xri     0ffh         ; is it terminator
            lbz     getvar3      ; jump if so
            xri     0ffh         ; restore character
            str     r2           ; store for comparison
            ldn     rf           ; get name byte from variable table
            sm                   ; compare them
            lbnz    getvarno     ; jump if they are not the same
            dec     rf           ; move to next name byte
            lbr     getvar2      ; loop back to continue comparing
getvar3:    ldn     rf           ; get byte from variable table
            lbnz    getvarno     ; must be terimanator, or no match
            pop     r9           ; recover token stream
            pop     rf           ; recover variable table
getvar4:    lda     r9           ; find name terminator
            xri     0ffh
            lbz     getvardn     ; variable found, so finish up
            lbr     getvar4
getvarno:   pop     r9           ; recover token stream
            pop     rf           ; recover table pointer
            dec     rf           ; point to size
            ldn     rf           ; get size
            dec     rf
            str     r2           ; store for add
            glo     rc           ; add variable size to offset
            add
            plo     rc
            ghi     rc
            adci    0
            phi     rc
getvarno1:  ldn     rf           ; get next byte of char name
            lbz     getvarno2    ; jump if terminator found
            dec     rf           ; move to next character
            lbr     getvarno1    ; loop until terminator found
getvarno2:  dec     rf           ; move below terminator
            lbr     getvar1      ; loop back to test next entry
newvar:     ldi     1            ; signal integer variable
            str     rf           ; store as variable type
            dec     rf
            ldi     2            ; integers are 16 bits
            sep     scall        ; check for 32 bits
            dw      is32bit
            lbnf    newvar1      ; jump if not
            ldi     4            ; integers are 32 bits
newvar1:    str     rf           ; store size
            dec     rf
newvar2:    lda     r9           ; get next byte from variable name
            xri     0ffh         ; check for terminator
            lbz     newvard      ; jump if terminator found
            xri     0ffh         ; restore character
            str     rf           ; store into table
            dec     rf
            lbr     newvar2      ; loop back for next character
newvard:    str     rf           ; store 0 terminator to table
            dec     rf           ; need to indicate end of table
            str     rf
getvardn:   ldi     low varbase  ; need variable base
            plo     rb
            lda     rb           ; get lsb of base
            str     r2           ; store for add
            glo     rc           ; get low of offset
            add                  ; add in variable base
            plo     rf           ; put into return value
            lda     rb           ; get msb of base
            str     r2           ; store for add
            ghi     rc           ; get high of offset
            adc                  ; and propagate the carry
            phi     rf           ; rf now has variable address
            pop     rc           ; recover consumed registers
            pop     r7
            sep     sret         ; and return

; **********************************************************
; ***** Convert string to uppercase, honor quoted text *****
; **********************************************************
touc:      ldn     rf                  ; check for quote
           smi     022h
           lbz     touc_qt             ; jump if quote
           ldn     rf                  ; get byte from string
           lbz     touc_dn             ; jump if done
           smi     'a'                 ; check if below lc
           lbnf    touc_nxt            ; jump if so
           smi     27                  ; check upper rage
           lbdf    touc_nxt            ; jump if above lc
           ldn     rf                  ; otherwise convert character to lc
           smi     32
           str     rf
touc_nxt:  inc     rf                  ; point to next character
           lbr     touc                ; loop to check rest of string
touc_dn:   sep     sret                ; return to caller
touc_qt:   inc     rf                  ; move past quote
touc_qlp:  lda     rf                  ; get next character
           lbz     touc_dn             ; exit if terminator found
           smi     022h                ; check for quote charater
           lbz     touc                ; back to main loop if quote
           lbr     touc_qlp            ; otherwise keep looking



functable: db      ('+'+80h)           ; 0   00  80
           db      ('-'+80h)           ; 1   01  81
           db      ('*'+80h)           ; 2   02  82
           db      ('/'+80h)           ; 3   03  83
           db      ('('+80h)           ; 4   04  84
           db      (')'+80h)           ; 5   05  85
           db      ('='+80h)           ; 6   06  86
           db      '<',('='+80h)       ; 7   07  87
           db      '>',('='+80h)       ; 8   08  88
           db      '<',('>'+80h)       ; 9   09  89
           db      ('<'+80h)           ; 10  0A  8A
           db      ('>'+80h)           ; 11  0B  8B
           db      (';'+80h)           ; 12  0C  8C
           db      (','+80h)           ; 13  0D  8D
           db      'PRIN',('T'+80h)    ; 14  0E  8E
           db      'GOT',('O'+80h)     ; 15  0F  8F
           db      'EN',('D'+80h)      ; 16  10  90
           db      'GOSU',('B'+80h)    ; 17  11  91
           db      'RETUR',('N'+80h)   ; 18  12  92
           db      'LE',('T'+80h)      ; 19  13  93
           db      'I',('F'+80h)       ; 20  14  94
           db      'INPU',('T'+80h)    ; 21  15  95
           db      'RE',('M'+80h)      ; 22  16  96
           db      'THE',('N'+80h)     ; 23  17  97
           db      'POK',('E'+80h)     ; 24  18  98
           db      'DPOK',('E'+80h)    ; 25  19  99
           db      ('&'+80h)           ; 26  1A  9A
           db      ('|'+80h)           ; 27  1B  9B
           db      ('^'+80h)           ; 28  1C  9C
           db      'PEE',('K'+80h)     ; 29  1D  9D
           db      'DPEE',('K'+80h)    ; 30  1E  9E
           db      'US',('R'+80h)      ; 31  1F  9F
           db      'FR',('E'+80h)      ; 32  20  A0
           db      'RN',('D'+80h)      ; 33  21  A1
           db      'OU',('T'+80h)      ; 34  22  A2
           db      'IN',('P'+80h)      ; 35  23  A3
           db      'FL',('G'+80h)      ; 36  24  A4
           db      (':'+80h)           ; 37  25  A5
           db      'PLO',('T'+80h)     ; 38  26  A6
           db      'CL',('S'+80h)      ; 39  27  A7
           db      'IO',('N'+80h)      ; 40  28  A8
           db      'IOF',('F'+80h)     ; 41  29  A9
           db      'IRETUR',('N'+80h)  ; 42  2A  AA
           db      'INT',('R'+80h)     ; 43  2B  AB
           db      'FO',('R'+80h)      ; 44  2C  AC
           db      'T',('O'+80h)       ; 45  2D  AD
           db      'STE',('P'+80h)     ; 46  2E  AE
           db      'NEX',('T'+80h)     ; 47  2F  AF
           db      'O',('N'+80h)       ; 48  30  B0
           db      0

rtable1:   db      0ah,80h,80h,12h,0Ah,09h,29h,1Ah,0Ah
           db      1ah,85h,18h,13h,09h,80h,12h,1,0Bh,0   
rtable2:   db      0bh,4,2,3,5,3,1bh,1ah,19h
           db      0bh,09h,06h,0ah,0,0,1ch,17h,8,0ffh

fileerr:   db      'File Error'
crlf:      db      10,13,0
err_msg:   db      'Error',10,13,0
endrom:    equ     $

ifname:    ds      32
ofname:    ds      32
fildes:    ds      20
ofildes:   ds      20
dta:       ds      512
odta:      ds      512
data:      ds      1
buffer:    ds      256
tokens:    ds      512
lines:     ds      1024

