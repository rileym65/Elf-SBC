; *******************************************************************
; *** This software is copyright 2004 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

; RA = instruction table
; RB = Basic data
; RC = TBC Proram counter
; RD = TBC Stack

include    bios.inc
include    kernel.inc

org:       equ     2000h

           org     8000h
           lbr     0ff00h
#ifdef BIT32
           db      'SBRUN32',0
           dw      0c000h
           dw      endrom+0c000h-org
           dw      org
           dw      endrom-org
           dw      org
           db      0
#else
           db      'SBRUN',0
           dw      0a000h
           dw      endrom+0a000h-org
           dw      org
           dw      endrom-org
           dw      org
           db      0
#endif

           org     2000h
           lbr     start

include    date.inc

; ********************************************
; ***** Runtime library code begins here *****
; ********************************************

; *****************************************
; ***** Get current state of EF flags *****
; *****************************************
flags:     ldi     0                   ; start from zero
           bn1     flags1              ; jump if ef1 is zero
           ori     1                   ; signal ef1 set
flags1:    bn2     flags2              ; jump if ef2 is zero
           ori     2                   ; signal ef2 set
flags2:    bn3     flags3              ; jump if ef3 is zero
           ori     4                   ; signal ef3 set
flags3:    bn4     flags4              ; jump if ef4 is zero
           ori     8                   ; signal ef4 set
flags4:    sep     sret                ; return to caller


; *********************************
; ***** ADD - TOS = TOS + SOS *****
; *********************************
rt_add:  sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    4
#else
         adi    2
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; add LSB
         add
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and add next byte
         adc
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and add next byte
         adc
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and add
         adc
         str    rf          ; store MSB
#endif
         sex    r2          ; point X back to system stack
         sep    sret        ; and return


; *********************************
; ***** NEG - TOS = -TOS      *****
; *********************************
rt_neg:  mov    rf,rd       ; will work from rf
         inc    rf          ; point to LSB
         ldn    rf          ; get LSB
         xri    0ffh        ; invert
         adi    1           ; 2s compliment needs +1
         str    rf          ; store result
         inc    rf
         ldn    rf          ; and neg next byte
         xri    0ffh        ; invert
         adci   0           ; propagate carry
         str    rf          ; store result
#ifdef BIT32
         inc    rf
         ldn    rf          ; and neg next byte
         xri    0ffh        ; invert
         adci   0           ; propagate carry
         str    rf          ; store result
         inc    rf
         ldn    rf          ; and neg
         xri    0ffh        ; invert
         adci   0           ; propagate carry
         str    rf          ; store MSB
#endif
         sep    sret        ; and return


; *********************************
; ***** SUB - TOS = SOS - TOS *****
; *********************************
rt_sub:  sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    4
#else
         adi    2
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; add LSB
         sm 
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub next byte
         smb
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub next byte
         smb
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub
         smb
         str    rf          ; store MSB
#endif
         sex    r2          ; point X back to system stack
         sep    sret        ; and return


; ************************************************
; ***** multiply. M[R7]=M[R7]*M[R8]          *****
; ***** Numbers in memory stored LSB first   *****
; ***** In routine:                          *****
; *****    R7 - points to answer             *****
; *****    R9 - points to first number       *****
; *****    R8 - points to second number      *****
; ************************************************
rt_mul:  ldi      0                 ; need to zero answer
         stxd
         stxd
#ifdef BIT32
         stxd
         stxd
#endif
         mov      r9,r7             ; r9 will point to first number
         mov      r7,r2             ; r7 will point to where the answer is
         inc      r7                ; point to LSB of answer
scmul2:  mov      rf,r8             ; need second number
         lda      rf                ; get lsb
         lbnz     scmul4            ; jump if not zero
         lda      rf                ; get second byte
         lbnz     scmul4            ; jump if not zero
#ifdef BIT32
         lda      rf                ; get third byte
         lbnz     scmul4            ; jump if not zero
         lda      rf                ; get fourth byte
         lbnz     scmul4            ; jump if not zero
#endif
         inc      r2                ; now pointing at lsb of answer
         lda      r2                ; get number from stack
         str      r9                ; store into destination
         inc      r9                ; point to 2nd byte
         lda      r2                ; get number from stack
         str      r9                ; store into destination
#ifdef BIT32
         inc      r9                ; point to 3rd byte
         lda      r2                ; get number from stack
         str      r9                ; store into destination
         inc      r9                ; point to msb
         lda      r2                ; get number from stack
         str      r9                ; store into destination
#endif
         dec      r2
         sep      sret              ; return to caller
scmul4:  ldn      r8                ; get lsb of second number
         shr                        ; shift low bit into df
         lbnf     scmulno           ; no add needed
         push     r7                ; save position of first number
         push     r9                ; save position of second number
         sex      r7                ; point x to answer
         lda      r9                ; get lsb of first number
         add                        ; and add to answer
         str      r7                ; store it
         inc      r7                ; point to next byte
         lda      r9                ; get second byte
         adc                        ; add byte from answer
         str      r7                ; and store it
#if BIT32
         inc      r7                ; point to 3rd byte
         lda      r9                ; get 3rd byte
         adc                        ; and add
         str      r7                ; store it
         inc      r7                ; point to 4th byte
         lda      r9                ; get final byte
         adc                        ; and add
         str      r7                ; store into answer
#endif
         sex      r2                ; point x back to system stack
         pop      r9                ; recover positions
         pop      r7
scmulno: ldn      r9                ; need to shift first number left
         shl
         str      r9
         inc      r9
         ldn      r9
         shlc
         str      r9
#ifdef BIT32
         inc      r9
         ldn      r9
         shlc
         str      r9
         inc      r9
         ldn      r9
         shlc
         str      r9
         dec      r9
         dec      r9
#endif
         dec      r9                ; put r9 back where it belongs
         inc      r8                ; need to shift second number right
#ifdef BIT32
         inc      r8
         inc      r8
#endif
         ldn      r8
         shr
         str      r8
         dec      r8
         ldn      r8
         shrc
         str      r8
#ifdef BIT32
         dec      r8
         ldn      r8
         shrc
         str      r8
         dec      r8
         ldn      r8
         shrc
         str      r8
#endif
         lbr      scmul2            ; loop until done



; ************************************************
; ***** 32-bit division. M[R7]=M[R7]/M[R8]   *****
; ***** D = number of bytes in integer       *****
; ***** Numbers in memory stored LSB first   *****
; ***** In routine:                          *****
; *****    R7=a                              *****
; *****    R8=b                              *****
; *****    RA=result                         *****
; *****    RB=shift                          *****
; ************************************************
rt_div:  push     ra                ; save consumed registers
         push     rb
         ldi      0                 ; need to zero result
         stxd                       ; reserve bytes on stack for result
         stxd
#ifdef BIT32
         stxd
         stxd
#endif
         mov      ra,r2             ; set RA here
         inc      ra                ; plus 1
         ldi      1                 ; set shift to 1
         plo      rb
         ldi      0
         str      r2
         inc      r7                ; move to high byte of A
#ifdef BIT32
         inc      r7
         inc      r7
#endif
         ldn      r7                ; retrieve it
         ani      080h              ; keep only sign bit
         str      r2                ; store here
         shl                        ; shift into df
         dec      r7
#ifdef BIT32
         dec      r7
         dec      r7
#endif
         lbnf     scdiv0            ; jump if number is positive
         ldn      r7                ; 2s compliment number
         xri      0ffh
         adi      1                 ; plus 1
         str      r7
         inc      r7
         ldn      r7 
         xri      0ffh
         adci     0
         str      r7
#ifdef BIT32
         inc      r7
         ldn      r7
         xri      0ffh
         adci     0
         str      r7
         inc      r7
         ldn      r7
         xri      0ffh
         adci     0
         str      r7
         dec      r7
         dec      r7
#endif
         dec      r7
scdiv0:  inc      r8                ; move to high byte of B
#ifdef BIT32
         inc      r8
         inc      r8
#endif
         ldn      r8                ; retrieve it
         ani      080h              ; keep only sign bit
         xor                        ; combine with sign bit already stored
         str      r2                ; store on stack
         ldn      r8
         ani      080h
         shl                        ; shift into df
         dec      r8
#ifdef BIT32
         dec      r8
         dec      r8
#endif
         lbnf     scdiv0a           ; jump if number is positive
         ldn      r8                ; 2s compliment number
         xri      0ffh
         adi      1                 ; plus 1
         str      r8
         inc      r8
         ldn      r8 
         xri      0ffh
         adci     0
         str      r8
#ifdef BIT32
         inc      r8
         ldn      r8
         xri      0ffh
         adci     0
         str      r8
         inc      r8
         ldn      r8
         xri      0ffh
         adci     0
         str      r8
         dec      r8
         dec      r8
#endif
         dec      r8
scdiv0a: dec      r2                ; move stack below sign comparison
scdiv1:  sex      r8                ; compare a to b
         lda      r7                ; get lsb from first number
         sd                         ; subtract
         inc      r8                ; point to second byte
         ldn      r7                ; get 2nd byte of first number
         sdb                        ; perform subtraction
#ifdef BIT32
         inc      r8
         inc      r7
         lda      r7
         sdb
         inc      r8
         ldn      r7
         sdb
         dec      r7
         dec      r7
         dec      r8
         dec      r8
#endif
         dec      r7
         dec      r8
         sex      r2                ; point x back to system stack
         shl                        ; shift sign into df
         lbnf     scdiv4            ; jump if b>=a
         ldn      r8                ; need to shift B left
         shl
         str      r8
         inc      r8
         ldn      r8
         shlc
         str      r8
#ifdef BIT32
         inc      r8
         ldn      r8
         shlc
         str      r8
         inc      r8
         ldn      r8
         shlc
         str      r8
         dec      r8
         dec      r8
#endif
         dec      r8
         inc      rb                ; increment shift
         lbr      scdiv1            ; loop until b>=a
scdiv4:  mov      rf,r7             ; need to check A for zero
         lda      rf 
         lbnz     scdiv4a
         lda      rf
         lbnz     scdiv4a
#ifdef BIT32
         lda      rf
         lbnz     scdiv4a
         lda      rf
         lbnz     scdiv4a
#endif
         lbr      scdivd1           ; was zero, so done
scdiv4a: mov      rf,r8             ; need to check B for zero
         lda      rf 
         lbnz     scdiv4b
         lda      rf
         lbnz     scdiv4b
#ifdef BIT32
         lda      rf
         lbnz     scdiv4b
         lda      rf
         lbnz     scdiv4b
#endif
         lbr      scdivd1           ; was zero, so done
scdiv4b: ldn      ra                ; need to shift result left
         shl
         str      ra
         inc      ra
         ldn      ra
         shlc
         str      ra
#ifdef BIT32
         inc      ra
         ldn      ra
         shlc
         str      ra
         inc      ra
         ldn      ra
         shlc
         str      ra
         dec      ra
         dec      ra
#endif
         dec      ra
         sex      r8                ; need to see if a<b
         ldn      r7                ; get lsb
         sm                         ; add second lsb of second number
         inc      r7                ; point to 2nd byte
         inc      r8
         ldn      r7                ; get second byte
         smb                        ; add second byte of second number
#ifdef BIT32
         inc      r7                ; point to 3rd byte
         inc      r8
         ldn      r7                ; get third byte
         smb                        ; add third byte of second number
         inc      r7                ; point to msb
         inc      r8
         ldn      r7                ; get msb byte
         smb                        ; add msb byte of second number
         dec      r7
         dec      r7
         dec      r8
         dec      r8
#endif
         dec      r7
         dec      r8
         sex      r2                ; restore stack
         shl                        ; shift sign bit into df
         lbdf     scdiv6            ; jump if a < b
         ldn      ra                ; get LSB of result
         ori      1                 ; set low bit
         str      ra                ; and but it back
         sex      r8                ; point x to second number
         ldn      r7                ; get lsb
         sm                         ; add second lsb of second number
         str      r7                ; store it
         inc      r7                ; point to 2nd byte
         inc      r8
         ldn      r7                ; get second byte
         smb                        ; add second byte of second number
         str      r7                ; store it
#ifdef BIT32
         inc      r7                ; point to 3rd byte
         inc      r8
         ldn      r7                ; get third byte
         smb                        ; add third byte of second number
         str      r7                ; store it
         inc      r7                ; point to msb
         inc      r8
         ldn      r7                ; get msb byte
         smb                        ; add msb byte of second number
         str      r7                ; store it
         dec      r7
         dec      r7
         dec      r8
         dec      r8
#endif
         dec      r7
         dec      r8
         sex      r2                ; restore stack
scdiv6:  ldn      r8                ; get lsb of b
         shr                        ; see if low bit is set
         lbnf     scdiv5            ; jump if not
         dec      rb                ; mark final shift
         lbr      scdivd1           ; and then done
scdiv5:  inc      r8                ; need to shift B right
#ifdef BIT32
         inc      r8
         inc      r8
#endif
         ldn      r8
         shr
         str      r8
         dec      r8
         ldn      r8
         shrc
         str      r8
#ifdef BIT32
         dec      r8
         ldn      r8
         shrc
         str      r8
         dec      r8
         ldn      r8
         shrc
         str      r8
#endif
         dec      rb                ; decrement shift
         lbr      scdiv4            ; loop back until done
scdivd1: glo      rb                ; get shift
         shl                        ; shift sign into df
         lbdf     scdivd2           ; jump if so
scdivd3: glo      rb                ; get shift
         lbz      scdivdn           ; jump if zero
         ldn      ra                ; need to shift result left
         shl
         str      ra
         inc      ra
         ldn      ra
         shlc
         str      ra
#ifdef BIT32
         inc      ra
         ldn      ra
         shlc
         str      ra
         inc      ra
         ldn      ra
         shlc
         str      ra
         dec      ra
         dec      ra
#endif
         dec      ra
         dec      rb                ; decrement shift
         lbr      scdivd3           ; loop back
scdivd2: glo      rb                ; get shift
         lbz      scdivdn           ; jump if zero
         inc      ra                ; need to shift result right
#ifdef BIT32
         inc      ra
         inc      ra
#endif
         ldn      ra
         shr
         str      ra
         dec      ra
         ldn      ra
         shrc
         str      ra
#ifdef BIT32
         dec      ra
         ldn      ra
         shrc
         str      ra
         dec      ra
         ldn      ra
         shrc
         str      ra
#endif
         inc      rb                ; increment shift
         lbr      scdivd2
scdivdn: irx                        ; get sign comparison
         ldx
         shl                        ; shift into df
         lbnf     scdivn2           ; jump if same signs
         ldn      ra                ; need to 2s compliment answer
         xri      0ffh
         adi      1                 ; plus 1
         str      ra
         inc      ra
         ldn      ra
         xri      0ffh
         adci     0
         str      ra
#ifdef BIT32
         inc      ra
         ldn      ra
         xri      0ffh
         adci     0
         str      ra
         inc      ra
         ldn      ra
         xri      0ffh
         adci     0
         str      ra
         dec      ra
         dec      ra
#endif
         dec      ra
scdivn2: plo      rb                ; save it here
         lda      ra                ; transfer answer
         str      r7
         inc      r7
         lda      ra
         str      r7
#ifdef BIT32
         inc      r7
         lda      ra
         str      r7
         inc      r7
         lda      ra
         str      r7
#endif
         glo      ra                ; need to clean up the stack
         plo      r2
         ghi      ra
         phi      r2
         dec      r2
         pop      rb                ; recover consumed registers
         pop      ra
         sep      sret              ; return to caller

; *********************************
; ***** CMP - TOS - SAS       *****
; ***** D=comparison type     *****
; ***** Returns:DF=1 success  *****
; *********************************
rt_cmp:  sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    5
#else
         adi    3
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; subtract LSB
         sm 
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub next byte
         smb
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub next byte
         smb
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and sub
         smb
         str    rf          ; store MSB
#endif
         inc    rd          ; rd now points to comparison type
         lda    rd          ; retrieve it
         plo    re          ; store it here
         lda    rd          ; get first byte
         or                 ; or with second byte
#ifdef BIT32
         inc    rd          ; point to third byte
         or
         inc    rd          ; point to fourth byte
         or
#endif
         plo    rf          ; rf.0 now holds wither equal or not
         ldn    rd          ; get msb
         shl                ; shift sign into df
         ldi    0           ; clear d
         shlc               ; shift in df
         phi    rf          ; rf now has wheter negative or not
         sex    r2          ; point X back to system stack
         glo    re          ; get comparison type
         smi    1           ; check for 1 <
         lbnz   rt_cmp2     ; jump if not
         glo    rf          ; need to see if equal
         lbz    rt_cmpn     ; fails if they were
         ghi    rf          ; get df
         shr                ; shift for check
         lbdf   rt_cmpy     ; jump if true
         lbr    rt_cmpn     ; otherwise no
rt_cmp2: smi    1           ; check for 2 =
         lbnz   rt_cmp3     ; jump if not
         glo    rf          ; need to see if equal
         lbz    rt_cmpy     ; jump if so
         lbr    rt_cmpn     ; otherwise no
rt_cmp3: smi    1           ; check for 3 <=
         lbnz   rt_cmp4     ; jump if not
         glo    rf          ; see if equal
         lbz    rt_cmpy     ; skip next if so
         ghi    rf          ; get df
         shr                ; shift back into df
         lbdf   rt_cmpy     ; jump if negative
         lbr    rt_cmpn     ; otherwise continue
rt_cmp4: smi    1           ; check for 4 >
         lbnz   rt_cmp5     ; jump if not
         glo    rf          ; need to see if equal
         lbz    rt_cmpn     ; fails if they were
         ghi    rf          ; get df
         shr                ; shift for check
         lbnf   rt_cmpy     ; jump if greater
         lbr    rt_cmpn     ; otherwise continue
rt_cmp5: smi    1           ; check for 5 <>
         lbnz   rt_cmp6     ; jump if not
         glo    rf          ; need to see if equal
         lbnz   rt_cmpy     ; jump if not
         lbr    rt_cmpn     ; otherwise continue
rt_cmp6: glo    rf          ; see if equal
         lbz    rt_cmpy     ; skip next if so
         ghi    rf          ; get df
         shr                ; shift back into df
         lbnf   rt_cmpy     ; jump if positive
         lbr    rt_cmpn     ; otherwise continue
rt_cmpy: ldi    1           ; indicate compare succeeded
         shr                ; shift into df
         sep    sret        ; and return
rt_cmpn: ldi    0           ; indicate compare failed
         shr
         sep    sret        ; and return



; *********************************
; ***** AND - TOS = TOS & SAS *****
; *********************************
rt_and:  sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    4
#else
         adi    2
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; and LSB
         and
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and and next byte
         and
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and and next byte
         and
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and and
         and
         str    rf          ; store MSB
#endif
         sex    r2          ; point X back to system stack
         sep    sret        ; and return


; *********************************
; ***** OR - TOS = TOS | SAS  *****
; *********************************
rt_or:   sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    4
#else
         adi    2
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; and LSB
         or
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and or next byte
         or
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and or next byte
         or
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and or
         or
         str    rf          ; store MSB
#endif
         sex    r2          ; point X back to system stack
         sep    sret        ; and return


; *********************************
; ***** XOR - TOS = TOS ^ SAS *****
; *********************************
rt_xor:  sex    rd          ; point X to VM stack
         irx                ; point to LSB of 2nd number
         glo    rd          ; point RF to LSB of 1st number
#ifdef BIT32
         adi    4
#else
         adi    2
#endif
         plo    rf
         ghi    rd
         adci   0
         phi    rf          ; RF now points to LSB of 1st number
         ldn    rf          ; and LSB
         xor
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and xor next byte
         xor
         str    rf          ; store result
#ifdef BIT32
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and xor next byte
         xor
         str    rf          ; store result
         inc    rd          ; point to next byte
         inc    rf
         ldn    rf          ; and xor
         xor
         str    rf          ; store MSB
#endif
         sex    r2          ; point X back to system stack
         sep    sret        ; and return

; **********************************
; ***** Convert ascii to int32 *****
; ***** RF - buffer to ascii   *****
; ***** Returns R7:R8 result   *****
; ***** Uses: RA - digits msb  *****
; *****       R9 - counters    *****
; **********************************
atoi:      ldn     rf           ; get first character
           smi     '-'          ; is it negative
           lbnz    atoi0        ; jump if so
           ldi     1            ; indicate negative
           stxd                 ; save it
           inc     rf           ; move past minus
           lbr     atoi0a
atoi0:     ldi     0            ; indicate not negative
           stxd                 ; save on stack
atoi0a:    mov     r7,r2        ; keep the last position for moment
#ifdef BIT32
           ldi     10           ; need 10 work bytes on the stack
#else
           ldi     5
#endif
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
atoi3:     glo     re           ; were any valid digits found
           lbnz    atoi4        ; jump if so
           ldi     0            ; otherwise result is zero
           plo     r7
           phi     r7
           plo     r8
           phi     r8
atoidn:    glo     r2           ; clear work bytes off stack
#ifdef BIT32
           adi     10
#else
           adi     5
#endif
           plo     r2
           ghi     r2
           adci    0
           phi     r2
           irx                  ; recover sign flag
           ldx
           shr                  ; move to df
           lbnf    atoidd       ; jump if not negative
#ifdef BIT32
           glo     r8           ; 2s compliment return value
           xri     0ffh
           adi     1
           plo     r8
           ghi     r8
           xri     0ffh
           adci    0
           phi     r8
#endif
           glo     r7
           xri     0ffh
#ifdef BIT32
           adci    0
#else
           adi     1
#endif
           plo     r7
           ghi     r7
           xri     0ffh
           adci    0
           phi     r7
atoidd:    sep     sret         ; and return to caller
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
#ifdef BIT32
           ldi     32           ; 32 bits to process
#else
           ldi     16
#endif
           plo     r9
#ifdef BIT32
atoi5:     ldi     10           ; need to shift 10 cells
#else
atoi5:     ldi     5            ; need to shift 5 cells
#endif
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
#ifdef BIT32
           ghi     r8
           shrc
           phi     r8
           glo     r8
           shrc
           plo     r8
#endif
#ifdef BIT32
           ldi     10           ; need to check 10 cells
#else
           ldi     5            ; need to check 5 cells
#endif
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


; **************************************************
; ***** Convert R7:R8 to bcd in M[RF] (32-bit) *****
; ***** Convert R7    to bcd in M[RF] (16-bit) *****
; **************************************************
tobcd:     push    rf           ; save address
#ifdef BIT32
           ldi     10           ; 10 bytes to clear
#else
           ldi     5            ; 5 bytes to clear
#endif
           plo     re
tobcdlp1:  ldi     0
           str     rf           ; store into answer
           inc     rf
           dec     re           ; decrement count
           glo     re           ; get count
           lbnz    tobcdlp1     ; loop until done
           pop     rf           ; recover address
#ifdef BIT32
           ldi     32           ; 32 bits to process
#else
           ldi     16           ; 16 bits to process
#endif
           plo     r9
#ifdef BIT32
tobcdlp2:  ldi     10           ; need to process 10 cells
#else
tobcdlp2:  ldi     5            ; need to process 5 cells
#endif
           plo     re           ; put into count
           push    rf           ; save address
tobcdlp3:  ldn     rf           ; get byte
           smi     5            ; need to see if 5 or greater
           lbnf    tobcdlp3a    ; jump if not
           adi     8            ; add 3 to original number
           str     rf           ; and put it back
tobcdlp3a: inc     rf           ; point to next cell
           dec     re           ; decrement cell count
           glo     re           ; retrieve count
           lbnz    tobcdlp3     ; loop back if not done
#ifdef BIT32
           glo     r8           ; start by shifting number to convert
           shl
           plo     r8
           ghi     r8
           shlc
           phi     r8
           glo     r7
           shlc
#else
           glo     r7
           shl
#endif
           plo     r7
           ghi     r7
           shlc
           phi     r7
           shlc                 ; now shift result to bit 3
           shl
           shl
           shl
           str     rf
           pop     rf           ; recover address
           push    rf           ; save address again
#ifdef BIT32
           ldi     10           ; 10 cells to process
#else
           ldi     5            ; 5 cells to process
#endif
           plo     re
tobcdlp4:  lda     rf           ; get current cell
           str     r2           ; save it
           ldn     rf           ; get next cell
           shr                  ; shift bit 3 into df
           shr
           shr
           shr
           ldn     r2           ; recover value for current cell
           shlc                 ; shift with new bit
           ani     0fh          ; keep only bottom 4 bits
           dec     rf           ; point back
           str     rf           ; store value
           inc     rf           ; and move to next cell
           dec     re           ; decrement count
           glo     re           ; see if done
           lbnz    tobcdlp4     ; jump if not
           pop     rf           ; recover address
           dec     r9           ; decrement bit count
           glo     r9           ; see if done
           lbnz    tobcdlp2     ; loop until done
           sep     sret         ; return to caller

; ***************************************************
; ***** Print number in R7:R8 as signed integer *****
; ***************************************************
rt_itoa:   inc     rd           ; get number off stack
#ifdef BIT32
           lda     rd 
           plo     r8
           lda     rd
           phi     r8
#endif
           lda     rd
           plo     r7
           ldn     rd
           phi     r7
           glo     r2           ; make room on stack for buffer
#ifdef BIT32
           smi     11
#else
           smi     6
#endif
           plo     r2
           ghi     r2
           smbi    0
           phi     r2
           mov     rf,r2        ; RF is output buffer
           inc     rf
           ghi     r7           ; get high byte
           shl                  ; shift bit to DF
           lbdf    itoan        ; negative number
itoa1:     sep     scall        ; convert to bcd
           dw      tobcd
           mov     rf,r2
           inc     rf
#ifdef BIT32
           ldi     10
#else
           ldi     5
#endif
           plo     r8
#ifdef BIT32
           ldi     9            ; max 9 leading zeros
#else
           ldi     4            ; max 4 leading zeros
#endif
           phi     r8
ioalp:     lda     rf
           lbz     itoaz        ; check leading zeros
           str     r2           ; save for a moment
           ldi     0            ; signal no more leading zeros
           phi     r8
           ldn     r2           ; recover character
itoa2:     adi     030h
           sep     scall
           dw      f_type
itoa3:     dec     r8
           glo     r8
           lbnz    ioalp
           glo     r2           ; pop work buffer off stack
#ifdef BIT32
           adi     11
#else
           adi     6
#endif
           plo     r2
           ghi     r2
           adci    0
           phi     r2
           sep     sret         ; return to caller
itoaz:     ghi     r8           ; see if leading have been used up
           lbz     itoa2        ; jump if so
           smi     1            ; decrement count
           phi     r8
           lbr     itoa3        ; and loop for next character
itoan:     ldi     '-'          ; show negative
           sep     scall
           dw      f_type
#ifdef BIT32
           glo     r8           ; 2s compliment
           xri     0ffh
           adi     1
           plo     r8
           ghi     r8
           xri     0ffh
           adci    0
           phi     r8
#endif
           glo     r7
           xri     0ffh
#ifdef BIT32
           adci    0
#else
           adi     1
#endif
           plo     r7
           ghi     r7
           xri     0ffh
           adci    0
           phi     r7
           lbr     itoa1        ; now convert/show number






; ******************************************
; ***** Runtime library code ends here *****
; ******************************************

start:     mov     r2,07fffh           ; put stack at top of memory
           ghi     ra                  ; copy argument address to rf
           phi     rf
           glo     ra
           plo     rf
           sep     scall               ; display message
           dw      f_inmsg
#ifdef BIT32
           db      'SBRUN32 V0.1',10,13,0
#else
           db      'SBRUN16 V0.1',10,13,0
#endif
loop1:     lda     rf                  ; look for first less <= space
           smi     33
           bdf     loop1
           dec     rf                  ; backup to char
           ldi     0                   ; need proper termination
           str     rf
           ghi     ra                  ; back to beginning of name
           phi     rf
           glo     ra
           plo     rf
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     0                   ; flags for open
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           lbnf    opened              ; jump if file was opened
           ldi     high errmsg         ; get error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; display it
           dw      o_msg
           lbr     o_wrmboot           ; and return to os
opened:    mov     rf,program          ; point to program buffer
           mov     rc,2                ; need to read first 2 bytes
           sep     scall               ; read them
           dw      o_read
           mov     rf,program          ; point back to read bytes
           lda     rf                  ; get first byte
           smi     'S'                 ; must be S
           lbnz    wrongver            ; jump if not correct file type
           lda     rf                  ; get second byte
#ifdef BIT32
           smi     32                  ; must be 32-bit file
#else
           smi     16                  ; must be 16-bit file
#endif
           lbnz    wrongver            ; jump if not correct file type
           mov     rf,program          ; point to program buffer
           mov     rc,7f00h            ; set to read maximum amount
           sep     scall               ; read the header
           dw      o_read
           glo     rc                  ; need to find final address
           adi     program.0
           plo     rf
           ghi     rc
           adci    program.1
           phi     rf
           push    rf                  ; save it for now
           sep     scall               ; close the file
           dw      o_close

           mov     rc,program          ; point to loaded program
           mov     rd,07effh           ; set TBC stack
           mov     rb,07000h           ; basic data
           ldi     022h                ; location for end of memory
           plo     rb
           ldi     06fh                ; high byte
           str     rb
           inc     rb
           ldi     0ffh                ; low byte
           str     rb
           inc     rb
           pop     rf                  ; get free address
           ghi     rf                  ; and store it
           str     rb
           inc     rb
           glo     rf
           str     rb
           ldi     pstart.0            ; need address of program start
           plo     rb                  ; set into basic segment
           ldi     program.1           ; get program start
           str     rb                  ; and store
           inc     rb
           ldi     program.0
           str     rb
           dec     rb
           ldn     rc                  ; get first byte
           smi     0ffh                ; see if jump table present
           lbnz    mainlp              ; jump if not
           inc     rc                  ; move to first entry
jt1:       lda     rc                  ; get first byte of entry
           str     r2                  ; store it for or
           lda     rc                  ; get next byte
           or                          ; need to check for zero terminator
           lbz     jtdn                ; terminator found
           inc     rc                  ; move past address
           inc     rc
           lbr     jt1                 ; and keep looking for end
jtdn:      ghi     rc                  ; write new start offset
           str     rb
           inc     rb
           glo     rc
           str     rb

mainlp:    lda     rc                  ; get next command byte
           plo     re                  ; save it
           shl                         ; commands addresses are two bytes
           plo     rf                  ; store low offset
           ldi     0                   ; need high of offset
           shlc                        ; shift in the carry
           phi     rf                  ; rf now has offset
           glo     rf                  ; now add in command table address
           adi     cmdtab.0            ; add low of command table
           plo     rf                  ; store it here
           ghi     rf                  ; now high byte
           adci    cmdtab.1            ; of command table address
           phi     rf                  ; rf now points to entry
           mov     ra,jump+1           ; point to jump address
           lda     rf
           str     ra
           inc     ra
           lda     rf
           str     ra
           glo     re                  ; recover original command byte
jump:      lbr     0                   ; will be changed to command handler

wrongver:  sep     scall               ; close the file
           dw      o_close
           mov     rf,vermsg           ; point to error messge
           sep     scall               ; display it
           dw      f_msg
           lbr     o_wrmboot           ; and return to Elf/OS

op_lb:     lda     rc                  ; retrieve next program byte
           str     rd                  ; store onto stack
           dec     rd                  ; and decrement
           lbr     mainlp              ; back to main loop

op_ln:     lda     rc                  ; read high byte of number
           str     rd                  ; place on stack
           dec     rd 
           lda     rc                  ; get low byte of number
           str     rd                  ; place on stack
           dec     rd                  ; and decrement
#ifdef BIT32
           lda     rc
           str     rd
           dec     rd
           lda     rc
           str     rd
           dec     rd
#endif
           lbr     mainlp              ; back to main loop

op_sv:     inc     rd                  ; point to number on stack
           lda     rd                  ; get low byte
           plo     rf                  ; store here
           lda     rd                  ; get high byte
           phi     rf                  ; rf now has number to store
#ifdef BIT32
           lda     rd
           plo     r7
           lda     rd
           phi     r7
#endif
           ldn     rd                  ; get variable address
           plo     rb                  ; set into basic pointer
#ifdef BIT32
           ghi     r7
           str     rb
           inc     rb
           glo     r7
           str     rb
           inc     rb
#endif
           ghi     rf                  ; store value into variable
           str     rb
           inc     rb
           glo     rf                  ; low byte
           str     rb
           lbr     mainlp              ; then back to main loop

op_fv:     inc     rd                  ; point to variable number
           ldn     rd                  ; get variable address
           plo     rb                  ; rb now points to variable data
           lda     rb                  ; retrieve msb
           str     rd                  ; place onto satck
           dec     rd
#ifdef BIT32
           lda     rb                  ; retrieve msb
           str     rd                  ; place onto satck
           dec     rd
           lda     rb                  ; retrieve msb
           str     rd                  ; place onto satck
           dec     rd
#endif
           ldn     rb                  ; retrieve it
           str     rd                  ; place onto stack
           dec     rd
           lbr     mainlp              ; then back to main loop

op_ad:     sep     scall               ; call runtime add
           dw      rt_add
           lbr     mainlp              ; back to main loop


op_mp:     inc     rd                  ; point to second number
           mov     r8,rd               ; set r8 for multiply
           inc     rd                  ; point to first number
           inc     rd
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           mov     r7,rd               ; r7 now points to first number
           sep     scall               ; call multiply routine
           dw      rt_mul
           dec     rd                  ; point rd to correct spot
           lbr     mainlp              ; back to main loop

op_dv:     inc     rd                  ; point to second number
           mov     r8,rd               ; set r8 for divide
           inc     rd                  ; point to first number
           inc     rd
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           mov     r7,rd               ; r7 now points to first number
           sep     scall               ; call multiply routine
           dw      rt_div
           dec     rd                  ; point rd to correct spot
           lbr     mainlp              ; back to main loop

op_an:     sep     scall               ; call runtime AND routine
           dw      rt_and
           lbr     mainlp              ; back to main loop

op_or:     sep     scall               ; call runtime OR routine
           dw      rt_or
           lbr     mainlp              ; back to main loop

op_xr:     sep     scall               ; call runtime XOR routine
           dw      rt_xor
           lbr     mainlp              ; back to main loop

op_su:     sep     scall               ; call runtime SUB routine
           dw      rt_sub
           lbr     mainlp              ; back to main loop

op_pn:     sep     scall               ; all runtime ITOA
           dw      rt_itoa
           lbr     mainlp              ; all done

op_nl:     sep     scall               ; print new line
           dw      f_inmsg
           db      10,13,0
           lbr     mainlp              ; then back to main loop

op_pt:     ldi     9                   ; tab character
           sep     scall               ; display it
           dw      f_type
           lbr     mainlp              ; then back to main

op_pc:     lda     rc                  ; get next program byte
           plo     rf                  ; save it
           ani     07fh                ; strip high bit
           sep     scall               ; display it
           dw      f_type
           glo     rf                  ; recover byte
           shl                         ; shift high bit to df
           lbnf    op_pc               ; jump if more to print
           lbr     mainlp              ; otherwise back to main loop

joffset:   ldi     pstart.0+1          ; offset to program start
           plo     rb
           glo     rc                  ; get low of pc
           sex     rb                  ; point x to program start
           add
           plo     rc                  ; put into pc
           dec     rb                  ; point to msb
           ghi     rc                  
           adc
           phi     rc                  ; rc now has proper program counter
           sex     r2                  ; put x back
           lbr     mainlp              ; back to main loop


op_j:      ani     07fh                ; strip high bit
           phi     rf                  ; save it
           lda     rc                  ; get next byte from program
           plo     rc                  ; put into low of pc
           ghi     rf                  ; get high byte
           phi     rc                  ; rc now has target of jump
           lbr     joffset             ; add in program offset

op_js:     smi     030h                ; strip code
           phi     rf                  ; save it
           lda     rc                  ; get next byte from program
           plo     rf                  ; put into low of pc
           ghi     rc                  ; save current pc
           str     rd
           dec     rd
           glo     rc
           str     rd
           dec     rd
           mov     rc,rf               ; now jump to subroutine
           lbr     joffset             ; add in program offset

op_rt:     inc     rd                  ; recover calling address
           lda     rd
           plo     rc
           ldn     rd
           phi     rc
           lbr     mainlp              ; and then continue execution

op_ne:     sep     scall               ; call runtime to negate number
           dw      rt_neg
           lbr     mainlp              ; back to main loop

op_cp:     sep     scall               ; call runtime compare
           dw      rt_cmp
           lbdf    op_cp_gd            ; jump if comparison succeeded
           lbr     mainlp              ; otherwise main loop
op_cp_gd:  inc     rc                  ; skip next 2 bytes
           inc     rc
           lbr     mainlp              ; and back to main loop

;           smi     1                   ; check for 1 <
;           lbz     op_cp_lt            ; jump if so
;           smi     1                   ; check for =
;           lbz     op_cp_eq            ; jump if so
;           smi     1                   ; check for <=
;           lbz     op_cp_le
;           smi     1                   ; check for >
;           lbz     op_cp_gt
;           smi     1                   ; check for <>
;           lbz     op_cp_ne
;op_cp_ge:  glo     rf                  ; see if equal
;           lbz     op_cp_gd            ; skip next if so
;           ghi     rf                  ; get df
;           shr                         ; shift back into df
;           lbnf    op_cp_gd            ; jump if positive
;           lbr     mainlp              ; otherwise continue
;op_cp_lt:  glo     rf                  ; need to see if equal
;           lbz     mainlp              ; fails if they were
;           ghi     rf                  ; get df
;           shr                         ; shift for check
;           lbdf    op_cp_gd            ; jump if true
;           lbr     mainlp              ; otherwise continue
;op_cp_eq:  glo     rf                  ; need to see if equal
;           lbz     op_cp_gd            ; jump if so
;           lbr     mainlp              ; otherwise continue
;op_cp_le:  glo     rf                  ; see if equal
;           lbz     op_cp_gd            ; skip next if so
;           ghi     rf                  ; get df
;           shr                         ; shift back into df
;           lbdf    op_cp_gd            ; jump if negative
;           lbr     mainlp              ; otherwise continue
;op_cp_gt:  glo     rf                  ; need to see if equal
;           lbz     mainlp              ; fails if they were
;           ghi     rf                  ; get df
;           shr                         ; shift for check
;           lbnf    op_cp_gd            ; jump if greater
;           lbr     mainlp              ; otherwise continue
;op_cp_ne:  glo     rf                  ; need to see if equal
;           lbnz    op_cp_gd            ; jump if not
;           lbr     mainlp              ; otherwise continue
;op_cp_gd:  inc     rc                  ; skip next 2 bytes
;           inc     rc
;           lbr     mainlp              ; and jump to main loop

op_pe:     inc     rd                  ; get address from stack
           lda     rd
           plo     rf
           ldn     rd
           phi     rf
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           ldi     0                   ; high byte of peek'd value is zero
#ifdef BIT32
           str     rd
           dec     rd
           str     rd
           dec     rd
#endif
           str     rd
           dec     rd
           ldn     rf                  ; peek byte
           str     rd                  ; and put on stack
           dec     rd
           lbr     mainlp              ; back to main loop

op_po:     inc     rd                  ; retrieve value from stack
           lda     rd
           plo     rf
           lda     rd
           phi     rf
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           lda     rd                  ; get poke address
           plo     r9
           ldn     rd
           phi     r9
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           glo     rf                  ; get low byte of value
           str     r9                  ; and store it
           lbr     mainlp              ; then back to main loop

op_de:     inc     rd                  ; get address from stack
           lda     rd
           plo     rf
           ldn     rd
           phi     rf
#ifdef BIT32
           inc     rd
           inc     rd
           ldi     0
           str     rd
           dec     rd
           str     rd
           dec     rd
#endif
           lda     rf                  ; read msb of byte
           str     rd                  ; and put on stack
           dec     rd
           ldn     rf                  ; peek low byte
           str     rd                  ; and put on stack
           dec     rd
           lbr     mainlp              ; back to main loop

op_do:     inc     rd                  ; retrieve value from stack
           lda     rd
           plo     rf
           lda     rd
           phi     rf
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           lda     rd                  ; get poke address
           plo     r9
           ldn     rd
           phi     r9
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           ghi     rf                  ; get high byte
           str     r9                  ; and poke it
           inc     r9                  ; point to lsb
           glo     rf                  ; get low byte of value
           str     r9                  ; and store it
           lbr     mainlp              ; then back to main loop

op_sp:     inc     rd                  ; just move stack 2 places
           inc     rd
           lbr     mainlp              ; and back to main loop

op_ds:     inc     rd                  ; get value on stack
           lda     rd
           plo     rf
           ldn     rd
           phi     rf                  ; rf now has value on stack
           dec     rd                  ; move stack back down
           dec     rd
           ghi     rf                  ; now push value again
           str     rd
           dec     rd
           glo     rf
           str     rd
           dec     rd
           lbr     mainlp              ; back to main loop

op_ws:     lbr     o_wrmboot           ; return to Elf/OS

op_us:     sep     scall               ; call ml subroutine
usr_addr:  dw      0
           ghi     rf                  ; msb of return value
           str     rd                  ; store on stack
           dec     rd
           glo     rf                  ; lsb
           str     rd
           dec     rd
           lbr     mainlp              ; back to main loop

op_ou:     inc     rd                  ; get value from stack
           lda     rd                  ; lsb
           str     r2                  ; store for out
           lda     rd                  ; msb
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           lda     rd                  ; now get port
           ani     07h                 ; clear any odd bits
           adi     060h                ; convert to actual instruction
           plo     re                  ; save for a moment
           mov     rf,ioinst           ; point to instruction
           glo     re                  ; retrieve instructon
           str     rf                  ; and store it
ioinst:    db      0                   ; out instruction will be placed here
           dec     r2                  ; undo out increment
           lbr     mainlp              ; back to main loop

op_in:     inc     rd                  ; need to get port
           lda     rd                  ; now get port
           ani     07h                 ; clear any odd bits
           adi     068h                ; convert to actual instruction
           plo     re                  ; save for a moment
           mov     rf,inpinst          ; point to instruction
           glo     re                  ; retrieve instructon
           str     rf                  ; and store it
inpinst:   db      0                   ; out instruction will be placed here
           ldi     0                   ; msb of result is zero
#ifdef BIT#2
           str     rd
           dec     rd
           str     rd
           dec     rd
#endif
           str     rd                  ; place on stack
           dec     rd
           ldn     r2                  ; get input byte
           str     rd                  ; and place on stack
           dec     rd
           lbr     mainlp              ; then back to main loop

op_fg:     inc     rd                  ; do not need value on stack
           inc     rd
#ifdef BIT32
           inc     rd
           inc     rd
#endif
           sep     scall               ; get flags
           dw      flags
op_fg4:    plo     re                  ; save for a moment
           ldi     0                   ; msb of result is zero
#ifdef BIT32
           str     rd                  ; place on stack
           dec     rd
           str     rd                  ; place on stack
           dec     rd
#endif
           str     rd                  ; place on stack
           dec     rd
           glo     re                  ; get flags state
           str     rd                  ; and store onto stack
           dec     rd
           lbr     mainlp              ; back to main loop

op_gl:     sep     scall               ; display ?
           dw      f_inmsg
           db      '? ',0
           mov     rf,buffer           ; point to input buffer
           push    rc                  ; rc gets clobbeted by f_input
           sep     scall               ; get input from user
           dw      f_input
           pop     rc
           mov     rf,buffer           ; point to input text
           sep     scall               ; Convert ascii to binary
           dw      atoi
           ghi     r7                  ; and push input number to it
           str     rd
           dec     rd
           glo     r7
           str     rd
           dec     rd
#ifdef BIT32
           ghi     r8                  ; and push input number to it
           str     rd
           dec     rd
           glo     r8
           str     rd
           dec     rd
#endif
           sep     scall
           dw      f_inmsg
           db      10,13,0
           lbr     mainlp              ; back to main loop

op_pl:     inc     rd                  ; retrieve y value from stack
           lda     rd
           plo     rf
           lda     rd
           lda     rd                  ; get x value from stack
           phi     rf
           push    rd                  ; save basic stack
           mov     rd,rf               ; move coordinates
           sep     scall               ; position cursor
           dw      gotoxy
           pop     rd                  ; recover basic stack
           lbr     mainlp              ; then back to main loop

op_cl:     ldi     00ch                ; form feed
           sep     scall               ; display it
           dw      f_type
           lbr     mainlp              ; then back to main loop

op_sx:     ani     07h                 ; only 0-7 allowed
           shr                         ; 2 bytes per stack entry
           str     r2                  ; store for add
           inc     rd                  ; rd now points at tos
           glo     rd                  ; add in offset
           add
           plo     rf                  ; rf will point to second item
           ghi     rd
           adci    0                   ; propagate carry
           phi     rf                  ; rf now points to second entry
           ldn     rd                  ; get lsb from tos
           plo     re                  ; set aside
           ldn     rf                  ; get byte from stack
           str     rd                  ; put into tos
           glo     re                  ; get byte from os
           str     rf                  ; and store into entry
           inc     rd                  ; now point at msb
           inc     rf
           ldn     rd                  ; get lsb from tos
           plo     re                  ; set aside
           ldn     rf                  ; get byte from stack
           str     rd                  ; put into tos
           glo     re                  ; get byte from os
           str     rf                  ; and store into entry
           dec     rd                  ; put stack back where it belongs
           dec     rd
           lbr     mainlp              ; back to main loop

op_tj:     mov     r7,program+1        ; point to jump table
           inc     rd
           lda     rd                  ; get line number being jumped to
           plo     r8
           ldn     rd                  ; get msb
           phi     r8                  ; r8 now has line number
op_tjlp:   lda     r7                  ; get table line msb
           smi     0ffh                ; check for end of table
           lbnz    op_tj1              ; jump if not
           ldn     r7                  ; need to check 2nd byte
           smi     0ffh                ; check it
           lbnz    op_tj1              ; jump if not
           sep     scall               ; print error
           dw      f_inmsg
           db      'Invalid jump. Terminating',10,13,0
           lbr     o_wrmboot           ; return to Elf/OS
op_tj1:    ldn     r7                  ; get lsb
           dec     r7                  ; point to msb
           str     r2                  ; store for comparison
           glo     r8                  ; lsb of jump
           sm                          ; compare
           lbnz    op_tjno             ; jump if no match
           ldn     r7                  ; get msb
           str     r2                  ; store for comparison
           ghi     r8                  ; get high of jump address
           sm
           lbnz    op_tjno             ; jump if not it
           inc     r7                  ; correct line found, move to address
           inc     r7
           lda     r7                  ; get msb of jump
           phi     rc                  ; place into pc
           ldn     r7                  ; get lsb of jump
           plo     rc
           lbr     joffset             ; jump to add program offset
op_tjno:   inc     r7                  ; move to next entry
           inc     r7
           inc     r7
           inc     r7
           lbr     op_tjlp             ; and loop back to check
          
op_ts:     inc     rd                  ; get line number from stack
           lda     rd
           plo     r8
           ldn     rd
           phi     r8
           ghi     rc                  ; push current pc
           str     rd
           dec     rd
           glo     rc
           str     rd
           dec     rd
           mov     r7,program+1        ; point to jump table
           lbr     op_tjlp             ; and find address for jump

; *********************************************************
; ***** Takes value in D and makes 2 char ascii in RF *****
; *********************************************************
wtoa:      plo     rf                ; save value
           ldi     0                 ; clear high byte
           phi     rf
           glo     rf                ; recover low
wtoalp:    smi     10                ; see if greater than 10
           lbnf    wtoadn            ; jump if not
           plo     rf                ; store new value
           ghi     rf                ; get high character
           adi     1                 ; add 1
           phi     rf                ; and put it back
           glo     rf                ; retrieve low character
           lbr     wtoalp            ; and keep processing
wtoadn:    glo     rf                ; get low character
           adi     030h              ; convert to ascii
           plo     rf                ; put it back
           ghi     rf                ; get high character
           adi     030h              ; convert to ascii
           phi     rf                ; put it back
           sep     sret              ; return to caller

; *********************************************
; ***** Send vt100 sequence to set cursor *****
; ***** RD.0 = y                          *****
; ***** RD.1 = x                          *****
; *********************************************
gotoxy:    ldi     27                ; escape character
           sep     scall             ; write it
           dw      f_type
           ldi     '['               ; square bracket
           sep     scall             ; write it
           dw      f_type
           glo     rd                ; get x
           sep     scall             ; convert to ascii
           dw      wtoa
           ghi     rf                ; high character
           sep     scall             ; write it
           dw      f_type
           glo     rf                ; low character
           sep     scall             ; write it
           dw      f_type
           ldi     ';'               ; need separator
           sep     scall             ; write it
           dw      f_type
           ghi     rd                ; get y
           sep     scall             ; convert to ascii
           dw      wtoa
           ghi     rf                ; high character
           sep     scall             ; write it
           dw      f_type
           glo     rf                ; low character
           sep     scall             ; write it
           dw      f_type
           ldi     'H'               ; need terminator for position
           sep     scall             ; write it
           dw      f_type
           sep     sret              ; return to caller


; ************************************
; *** make both arguments positive ***
; *** Arg1 RB                      ***
; *** Arg2 R7                      ***
; *** Returns D=0 - signs same     ***
; ***         D=1 - signs difer    ***
; ************************************
mdnorm:    ghi     rb                  ; get high byte if divisor
           str     r2                  ; store for sign check
           ghi     r7                  ; get high byte of dividend
           xor                         ; compare
           shl                         ; shift into df
           ldi     0                   ; convert to 0 or 1
           shlc                        ; shift into D
           plo     re                  ; store into sign flag
           ghi     rb                  ; need to see if RB is negative
           shl                         ; shift high byte to df
           lbnf    mdnorm2             ; jump if not
           ghi     rb                  ; 2s compliment on RB
           xri     0ffh
           phi     rb
           glo     rb
           xri     0ffh
           plo     rb
           inc     rb
mdnorm2:   ghi     r7                  ; now check r7 for negative
           shl                         ; shift sign bit into df
           lbnf    mdnorm3             ; jump if not
           ghi     r7                  ; 2 compliment on R7
           xri     0ffh
           phi     r7
           glo     r7
           xri     0ffh
           plo     r7
           inc     r7
mdnorm3:   glo     re                  ; recover sign flag
           sep     sret                ; and return to caller
; *** RC = RB/R7
; *** RB = remainder
; *** uses R8 and R9
div16:     sep     scall               ; normalize numbers
           dw      mdnorm
           plo     re                  ; save sign comparison
           ldi     0                   ; clear answer
           phi     rc
           plo     rc
           phi     r8                  ; set additive
           plo     r8
           inc     r8
           glo     r7                  ; check for divide by 0
           lbnz    d16lp1
           ghi     r7
           lbnz    d16lp1
           ldi     0ffh                ; return 0ffffh as div/0 error
           phi     rc
           plo     rc
           sep     sret                ; return to caller
d16lp1:    ghi     r7                  ; get high byte from r7
           ani     128                 ; check high bit
           lbnz    divst               ; jump if set
           glo     r7                  ; lo byte of divisor
           shl                         ; multiply by 2
           plo     r7                  ; and put back
           ghi     r7                  ; get high byte of divisor
           shlc                        ; continue multiply by 2
           phi     r7                  ; and put back
           glo     r8                  ; multiply additive by 2
           shl
           plo     r8
           ghi     r8
           shlc
           phi     r8
           lbr     d16lp1              ; loop until high bit set in divisor
divst:     glo     r7                  ; get low of divisor
           lbnz    divgo               ; jump if still nonzero
           ghi     r7                  ; check hi byte too
           lbnz    divgo
           glo     re                  ; get sign flag
           shr                         ; move to df
           lbnf    divret              ; jump if signs were the same
           ghi     rc                  ; perform 2s compliment on answer
           xri     0ffh
           phi     rc
           glo     rc
           xri     0ffh
           plo     rc
           inc     rc
divret:    sep     sret                ; jump if done
divgo:     ghi     rb                  ; copy dividend
           phi     r9
           glo     rb
           plo     r9
           glo     r7                  ; get lo of divisor
           stxd                        ; place into memory
           irx                         ; point to memory
           glo     rb                  ; get low byte of dividend
           sm                          ; subtract
           plo     rb                  ; put back into r6
           ghi     r7                  ; get hi of divisor
           stxd                        ; place into memory
           irx                         ; point to byte
           ghi     rb                  ; get hi of dividend
           smb                         ; subtract
           phi     rb                  ; and put back
           lbdf    divyes              ; branch if no borrow happened
           ghi     r9                  ; recover copy
           phi     rb                  ; put back into dividend
           glo     r9
           plo     rb
           lbr     divno               ; jump to next iteration
divyes:    glo     r8                  ; get lo of additive
           stxd                        ; place in memory
           irx                         ; point to byte
           glo     rc                  ; get lo of answer
           add                         ; and add
           plo     rc                  ; put back
           ghi     r8                  ; get hi of additive
           stxd                        ; place into memory
           irx                         ; point to byte
           ghi     rc                  ; get hi byte of answer
           adc                         ; and continue addition
           phi     rc                  ; put back
divno:     ghi     r7                  ; get hi of divisor
           shr                         ; divide by 2
           phi     r7                  ; put back
           glo     r7                  ; get lo of divisor
           shrc                        ; continue divide by 2
           plo     r7
           ghi     r8                  ; get hi of divisor
           shr                         ; divide by 2
           phi     r8                  ; put back
           glo     r8                  ; get lo of divisor
           shrc                        ; continue divide by 2
           plo     r8
           lbr     divst               ; next iteration

; *******************
; *** Process RND ***
; *******************
#ifdef BIT32
op_rn:     ldi     32                  ; need to get 32 bits
#else
op_rn:     ldi     16                  ; need to get 16 bits
#endif
rnd_lp:    stxd                        ; save count
           sep     scall               ; get random bit
           dw      fn_lfsr
           irx                         ; recover count
           ldx
           smi     1                   ; minus 1
           lbnz    rnd_lp              ; keep looping until all bits read
           mov     r7,lfsr
           lda     r7                  ; retrieve 16 bits wroth
           ani     07fh                ; no negative numbers
           stxd                        ; ont stack
           lda     r7
           stxd
#ifdef BIT32
           lda     r7                  ; retrieve a total of 32 bits
           stxd
           lda     r7
           stxd
#endif
           mov     r7,lfsr             ; make a 2nd copy of the random number
           lda     r7                  ; retrieve 16 bits wroth
           ani     07fh                ; no negative numbers
           stxd                        ; ont stack
           lda     r7
           stxd
#ifdef BIT32
           lda     r7                  ; retrieve a total of 32 bits
           stxd
           lda     r7
           ani     07fh                ; no negative numbers
           stxd
#endif
           mov     r8,rd               ; point to range
           inc     r8
           inc     r8
#ifdef BIT32
           inc     r8
           inc     r8
#endif
           mov     r7,r2               ; point to random number
           inc     r7
           ldn     r8                  ; copy range to stack
           dec     r8
           stxd
           ldn     r8
           stxd
#ifdef BIT32
           dec     r8
           ldn     r8
           stxd
           dec     r8
           ldn     r8
           stxd
#endif
           mov     r8,r2               ; use this copy for divide
           inc     r8
           sep     scall               ; and divide
           dw      rt_div
           irx                         ; remove copy of range from stack
           irx
#ifdef BIT32
           irx
           irx
#endif

           mov     r8,rd               ; point to range
           inc     r8
           mov     r7,r2               ; point to division result
           inc     r7
           sep     scall               ; now multiply
           dw      rt_mul

           mov     r7,r2               ; point to original random number
           inc     r7
           inc     r7
           inc     r7
#ifdef BIT32
           inc     r7
           inc     r7
#endif
           mov     r8,r2               ; point to multiplication result
           inc     r8

           sex     r8
           ldn     r7
           sm
           str     r7
           inc     r7
           inc     r8
           ldn     r7
           smb
           str     r7
#ifdef BIT32
           inc     r7
           inc     r8
           ldn     r7
           smb
           str     r7
           inc     r7
           inc     r8
           ldn     r7
           smb
           str     r7
#endif
           sex     r2
;           sep     scall               ; and subtract
;           dw      rt_sub

           mov     r8,rd               ; point to VM stack
           inc     r8
           mov     r7,r2               ; point to modulo value
           inc     r7
           inc     r7
           inc     r7
#ifdef BIT32
           inc     r7
           inc     r7
#endif
           lda     r7                  ; copy to VM stack
           str     r8
           inc     r8
           lda     r7                  ; copy to VM stack
           str     r8
#ifdef BIT32
           inc     r8
           lda     r7                  ; copy to VM stack
           str     r8
           inc     r8
           lda     r7                  ; copy to VM stack
           str     r8
#endif
           inc     r2                  ; now clean up system stack
           inc     r2
           inc     r2
           inc     r2
#ifdef BIT32
           inc     r2
           inc     r2
           inc     r2
           inc     r2
#endif
           lbr     mainlp              ; back to main loop


; ********************************
; *** Get random bit from LFSR ***
; ********************************
fn_lfsr:   ldi     high lfsr           ; point to lfsr
           phi     r7
           ldi     low lfsr
           plo     r7
           inc     r7                  ; point to lsb
           inc     r7
           inc     r7
           ldn     r7                  ; retrieve it
           plo     re                  ; put into re  ( have bit 0)
           shr                         ; shift bit 1 into first position
           str     r2                  ; xor with previous value
           glo     re
           xor
           plo     re                  ; keep copy
           ldn     r2                  ; get value
           shr                         ; shift bit 2 into first position
           str     r2                  ; and combine
           glo     re
           xor
           plo     re
           ldn     r2                  ; now shift to bit 4
           shr
           shr
           str     r2                  ; and combine
           glo     re
           xor
           plo     re
           ldn     r2                  ; now shift to bit 6
           shr
           shr
           str     r2                  ; and combine
           glo     re
           xor
           plo     re
           dec     r7                  ; point to lfsr msb
           dec     r7
           dec     r7
           ldn     r7                  ; retrieve it
           shl                         ; shift high bit to low
           shlc
           str     r2                  ; combine with previous value
           glo     re
           xor
           xri     1                   ; combine with a final 1
           shr                         ; shift new bit into DF
           ldn     r7                  ; now shift the register
           shrc
           str     r7
           inc     r7                  ; now byte 1
           ldn     r7                  ; now shift the register
           shrc
           str     r7
           inc     r7                  ; now byte 2
           ldn     r7                  ; now shift the register
           shrc
           str     r7
           inc     r7                  ; now byte 3
           ldn     r7                  ; now shift the register
           shrc
           str     r7
           shr                         ; shift result bit into DF
           sep     sret                ; and return


cmdtab:    dw      op_sx               ; 00  SX 0
           dw      op_sx               ; 01  SX 1
           dw      op_sx               ; 02  SX 2
           dw      op_sx               ; 03  SX 3
           dw      op_sx               ; 04  SX 4
           dw      op_sx               ; 05  SX 5
           dw      op_sx               ; 06  SX 6
           dw      op_sx               ; 07  SX 7
           dw      mainlp              ; 08
           dw      op_lb               ; 09  LB - Byte to stack
           dw      op_ln               ; 0a  LN - Number to stack
           dw      op_ds               ; 0b  DS - Duplicate top 2 stack values
           dw      op_sp               ; 0c  SP - Pop 2 stack values
           dw      op_in               ; 0d  IN - INP
           dw      op_pe               ; 0e  PE - Peek
           dw      op_po               ; 0f  PO - Poke
           dw      op_ou               ; 10  OU - Out
           dw      op_fg               ; 11  FG - Flg
           dw      op_fv               ; 12  FV - Fetch variable
           dw      op_sv               ; 13  SV - Store variable
           dw      op_de               ; 14  DE - Dpeek
           dw      op_do               ; 15  DO - Dpoke
           dw      op_pl               ; 16  PL - Plot
           dw      op_ne               ; 17  NE - Negate
           dw      op_ad               ; 18  AD - Add
           dw      op_su               ; 19  SU - Subtract
           dw      op_mp               ; 1a  MP - Multiply
           dw      op_dv               ; 1b  DV - Divide
           dw      op_cp               ; 1c  CP - Compare
           dw      op_ts               ; 1d  TS - Table gosub
           dw      op_tj               ; 1e  TJ - Table jump
           dw      mainlp              ; 1f
           dw      op_pn               ; 20  PN - Print Number
           dw      mainlp              ; 21
           dw      op_pt               ; 22  PT - Print tab
           dw      op_nl               ; 23  NL - Print New Line
           dw      op_pc               ; 24  PC - Print literal string
           dw      op_an               ; 25  AN - And
           dw      op_or               ; 26  OR - Or
           dw      op_gl               ; 27  GL - Input line
           dw      op_xr               ; 28  XR - Xor
           dw      mainlp              ; 29
           dw      op_cl               ; 2a  CL - Cls
           dw      op_rn               ; 2b  RN - Rnd
           dw      mainlp              ; 2c
           dw      op_ws               ; 2d  WS - Return to system
           dw      op_us               ; 2e  US - USR call
           dw      op_rt               ; 2f  RT - Return from IL subroutine
           dw      op_js               ; 30
           dw      op_js               ; 31
           dw      op_js               ; 32
           dw      op_js               ; 33
           dw      op_js               ; 34
           dw      op_js               ; 35
           dw      op_js               ; 36
           dw      op_js               ; 37
           dw      op_js               ; 38
           dw      op_js               ; 39
           dw      op_js               ; 3a
           dw      op_js               ; 3b
           dw      op_js               ; 3c
           dw      op_js               ; 3d
           dw      op_js               ; 3e
           dw      op_js               ; 3f
           dw      op_js               ; 40
           dw      op_js               ; 41
           dw      op_js               ; 42
           dw      op_js               ; 43
           dw      op_js               ; 44
           dw      op_js               ; 45
           dw      op_js               ; 46
           dw      op_js               ; 47
           dw      op_js               ; 48
           dw      op_js               ; 49
           dw      op_js               ; 4a
           dw      op_js               ; 4b
           dw      op_js               ; 4c
           dw      op_js               ; 4d
           dw      op_js               ; 4e
           dw      op_js               ; 4f
           dw      op_js               ; 50
           dw      op_js               ; 51
           dw      op_js               ; 52
           dw      op_js               ; 53
           dw      op_js               ; 54
           dw      op_js               ; 55
           dw      op_js               ; 56
           dw      op_js               ; 57
           dw      op_js               ; 58
           dw      op_js               ; 59
           dw      op_js               ; 5a
           dw      op_js               ; 5b
           dw      op_js               ; 5c
           dw      op_js               ; 5d
           dw      op_js               ; 5e
           dw      op_js               ; 5f
           dw      op_js               ; 60
           dw      op_js               ; 61
           dw      op_js               ; 62
           dw      op_js               ; 63
           dw      op_js               ; 64
           dw      op_js               ; 65
           dw      op_js               ; 66
           dw      op_js               ; 67
           dw      op_js               ; 68
           dw      op_js               ; 69
           dw      op_js               ; 6a
           dw      op_js               ; 6b
           dw      op_js               ; 6c
           dw      op_js               ; 6d
           dw      op_js               ; 6e
           dw      op_js               ; 6f
           dw      op_js               ; 70
           dw      op_js               ; 71
           dw      op_js               ; 72
           dw      op_js               ; 73
           dw      op_js               ; 74
           dw      op_js               ; 75
           dw      op_js               ; 76
           dw      op_js               ; 77
           dw      op_js               ; 78
           dw      op_js               ; 79
           dw      op_js               ; 7a
           dw      op_js               ; 7b
           dw      op_js               ; 7c
           dw      op_js               ; 7d
           dw      op_js               ; 7e
           dw      op_js               ; 7f
           dw      op_j                ; 80
           dw      op_j                ; 81
           dw      op_j                ; 82
           dw      op_j                ; 83
           dw      op_j                ; 84
           dw      op_j                ; 85
           dw      op_j                ; 86
           dw      op_j                ; 87
           dw      op_j                ; 88
           dw      op_j                ; 89
           dw      op_j                ; 8a
           dw      op_j                ; 8b
           dw      op_j                ; 8c
           dw      op_j                ; 8d
           dw      op_j                ; 8e
           dw      op_j                ; 8f
           dw      op_j                ; 90
           dw      op_j                ; 91
           dw      op_j                ; 92
           dw      op_j                ; 93
           dw      op_j                ; 94
           dw      op_j                ; 95
           dw      op_j                ; 96
           dw      op_j                ; 97
           dw      op_j                ; 98
           dw      op_j                ; 99
           dw      op_j                ; 9a
           dw      op_j                ; 9b
           dw      op_j                ; 9c
           dw      op_j                ; 9d
           dw      op_j                ; 9e
           dw      op_j                ; 9f
           dw      op_j                ; a0
           dw      op_j                ; a1
           dw      op_j                ; a2
           dw      op_j                ; a3
           dw      op_j                ; a4
           dw      op_j                ; a5
           dw      op_j                ; a6
           dw      op_j                ; a7
           dw      op_j                ; a8
           dw      op_j                ; a9
           dw      op_j                ; aa
           dw      op_j                ; ab
           dw      op_j                ; ac
           dw      op_j                ; ad
           dw      op_j                ; ae
           dw      op_j                ; af
           dw      op_j                ; b0
           dw      op_j                ; b1
           dw      op_j                ; b2
           dw      op_j                ; b3
           dw      op_j                ; b4
           dw      op_j                ; b5
           dw      op_j                ; b6
           dw      op_j                ; b7
           dw      op_j                ; b8
           dw      op_j                ; b9
           dw      op_j                ; ba
           dw      op_j                ; bb
           dw      op_j                ; bc
           dw      op_j                ; bd
           dw      op_j                ; be
           dw      op_j                ; bf
           dw      op_j                ; c0
           dw      op_j                ; c1
           dw      op_j                ; c2
           dw      op_j                ; c3
           dw      op_j                ; c4
           dw      op_j                ; c5
           dw      op_j                ; c6
           dw      op_j                ; c7
           dw      op_j                ; c8
           dw      op_j                ; c9
           dw      op_j                ; ca
           dw      op_j                ; cb
           dw      op_j                ; cc
           dw      op_j                ; cd
           dw      op_j                ; ce
           dw      op_j                ; cf
           dw      op_j                ; d0
           dw      op_j                ; d1
           dw      op_j                ; d2
           dw      op_j                ; d3
           dw      op_j                ; d4
           dw      op_j                ; d5
           dw      op_j                ; d6
           dw      op_j                ; d7
           dw      op_j                ; d8
           dw      op_j                ; d9
           dw      op_j                ; da
           dw      op_j                ; db
           dw      op_j                ; dc
           dw      op_j                ; dd
           dw      op_j                ; de
           dw      op_j                ; df
           dw      op_j                ; e0
           dw      op_j                ; e1
           dw      op_j                ; e2
           dw      op_j                ; e3
           dw      op_j                ; e4
           dw      op_j                ; e5
           dw      op_j                ; e6
           dw      op_j                ; e7
           dw      op_j                ; e8
           dw      op_j                ; e9
           dw      op_j                ; ea
           dw      op_j                ; eb
           dw      op_j                ; ec
           dw      op_j                ; ed
           dw      op_j                ; ee
           dw      op_j                ; ef
           dw      op_j                ; f0
           dw      op_j                ; f1
           dw      op_j                ; f2
           dw      op_j                ; f3
           dw      op_j                ; f4
           dw      op_j                ; f5
           dw      op_j                ; f6
           dw      op_j                ; f7
           dw      op_j                ; f8
           dw      op_j                ; f9
           dw      op_j                ; fa
           dw      op_j                ; fb
           dw      op_j                ; fc
           dw      op_j                ; fd
           dw      op_j                ; fe
           dw      op_j                ; ff
errmsg:    db      'File not found',10,13,0
vermsg:    db      'Invalid program file',10,13,0
fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0

endrom:    equ     $

base:      equ     $
dta:       equ     $
buffer:    equ     base
program:   equ     base+512

           org     7000h
pstart:    equ     $
lfsr:      equ     $+026h

