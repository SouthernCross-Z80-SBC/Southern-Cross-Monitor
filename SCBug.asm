;------------------
; SC SERIAL MONITOR
;------------------
; press the function key twice to start the monitor
; comms parameters are 9600,n,8,2
;
;set the vector to the serial monitor
        .ORG  00A0H
        .DW   SCBUG
;
;serial monitor system calls
;
        .ORG  0100H+(2*34)
        .DW   SNDMSG          ;34 send a zero terminated string
        .DW   BITASC          ;35 convert a byte to an ASCII string as bits
        .DW   WRDASC          ;36 convert a word to ASCII
        .DW   BYTASC          ;37 convert a byte to ASCII
        .DW   NYBASC          ;38 convert a nibble to ASCII
        .ORG  0100H+(2*40)
        .DW   ILPSZ           ;40 in-line print string
        .ORG  0100H+(2*45)
        .DW   SCBUG           ;45 serial monitor  entry point
        .ORG  0100H+(2*47)
        .DW   ESCMORE         ;47 list more or escape
        .DW   ASC2HEX         ;48 convert ASCII to hexadecimal
        .DW   INSBUF          ;49 put a char into a buffer
        .DW   SPCBUF          ;50 put a space into a buffer
        .DW   BCRLF           ;51 put a CR LF into a buffer
;------------
; ASCII CODES
;------------
ESC     .EQU  1BH
CR      .EQU  0DH
LF      .EQU  0AH
;
        .ORG  1000H
;
SCBUG   LD    HL,B9600       ;initialise the baud rate
        CALL  SERINI         ;set up tx output pin
;---------------------
; START UP THE MONITOR
;---------------------
COLD    LD    (SPSAVE),SP    ;save stack pointer
        LD    HL,SSSTEP
        LD    (RST38),HL     ;hijack the single stepper
        LD    HL,0000H
        LD    (BRKADD),HL    ;clear the break address
;
;send VT100 terminal commands for clear screen,cursor home
;
        CALL  ILPSZ
        .DB   27,"[H",27,"[2J",0
;
; output the header
;
        CALL  PCBTYP
        CALL  SNDMSG         ;board type
        CALL  ILPSZ
        .DB " Southern Cross Serial Monitor ",0
        CALL  VERS
        CALL  SNDMSG         ;monitor version
        CALL  TXCRLF
        CALL  KBDTYP
        CALL  SNDMSG         ;keyboard type
        CALL  ILPSZ
        .DB " Keyboard",0
        CALL  ILPSZ
        .DB CR,LF,"H for command list",CR,LF,0
;
; display the prompt and wait for commands
;
START2  LD    A,'>'
        CALL  TXDATA         ;display the prompt
START3  CALL  RXDATA         ;get a character from the console
        LD    C,A            ;save ASCII character for later
        AND   0DFH           ;turn lower case into upper case
;
; if the command is not in the command list reject it
;
        LD    HL,MONMENU
        LD    B,(HL)         ;number of commands
        INC   HL
START4  CP    (HL)           ;in the list?
        JR    Z,START5       ;ok do it
        INC   HL
        DJNZ  START4         ;keep looking
        JR    START3         ;not a valid command
;
;process the command
;
START5  LD    A,C            ;get original ASCII char back
        CALL  TXDATA         ;to echo it
        AND   0DFH           ;and turn back into upper case
        LD    HL,MONMENU     ;to use the menu handler
        CALL  MENU           ;key in ACC, execute menu
;
; the menu function call leaves the return address of the menu call
; on the stack so called subroutines come back here with a RET
;
WARM    CALL  TXCRLF         ;start on a new line
        JP    START2         ;get ready for a new command
;
; scbug monitor commands
;
MONMENU .DB   11
        .DB   'D','H','T','M','G','I','S','R','L','B','X'
        .DW   DSPLAY,HELP,SSTOGL,MODIFY,GOJUMP
        .DW   INTHEX,PGMRET,DISREG,LISTA,BPOINT,EXIT
;-----------------------------
; GET A BYTE FROM THE TERMINAL
;-----------------------------
;get the high nibble
GETCHR  CALL  RXDATA
        CP    ESC            ;ESC exits routine
        JR    Z,GETOUT
        LD    B,A            ;save the ASCII character to echo later
        CALL  ASC2HEX        ;convert to lower nibble hex value
        JR    NC,GETCHR      ;reject non hex chars
        LD    HL,DATA
        LD    (HL),A         ;save the high nibble
;
        LD    A,B            ;get the ASCII character back
        CALL  TXDATA         ;and echo valid hex
;
; get the low nibble
;
GETNYB  CALL  RXDATA
        CP    ESC            ;escape exits routine
        JR    Z,GETOUT
        LD    B,A            ;save the ASCII character to echo later
        CALL  ASC2HEX        ;convert to lower nibble hex value
        JR    NC,GETNYB      ;reject non hex chars
;
        RLD                  ;do a BCD rotate left to combine the nibbles
;
        LD    A,B            ;get the ASCII character back
        CALL  TXDATA         ;and echo valid hex
;
        LD    A,(HL)         ;put the byte in ACC to return
        CALL  GETOUT         ;make sure we clear the carry by setting it,
        CCF                  ;and then complementing it
        RET
GETOUT  SCF                  ;set the carry flag to exit back to menu
        RET
;------------------------------
; GO <ADDR>
; TRANSFERS EXECUTION TO <ADDR>
;------------------------------
GOJUMP  CALL  OUTSP
        CALL  GETCHR         ;get address high byte
        RET   C              ;ESC 
        LD    (ADDR+1),A     ;save address high
        CALL  GETCHR         ;get address low byte
        RET   C              ;ESC
        LD    (ADDR),A       ;save address low
;
; wait for a CR or ESC
;
GOJMP1  CALL  RXDATA
        CP    ESC            ;ESC key?
        RET   Z              ;Z=1 yes, exit
        CP    CR             ;CR?
        JR    NZ,GOJMP1      ;Z=0 no, keep waiting
        CALL  TXCRLF
        LD    HL,(ADDR)
        JP    (HL)           ;jump to user address
;---------------
; OUTPUT A SPACE
;---------------
OUTSP   LD    A,' '
        JP    TXDATA
;-------------
; OUTPUT CRLF
;------------
TXCRLF  LD    A,CR
        CALL  TXDATA
        LD    A,LF
        JP    TXDATA
;---------------------
; DISPLAY COMMAND HELP
;---------------------
HELP    CALL  ILPSZ
        .DB   CR,LF,"D AAAA<CR>  Display Data at Address AAAA"
        .DB   CR,LF,"T           Toggle Single Stepper Hardware"
        .DB   CR,LF,"M AAAA      Modify Address AAAA"
        .DB   CR,LF,"G AAAA<CR>  GO from AAAA"
        .DB   CR,LF,"I           Download INTEL Hex"
        .DB   CR,LF,"S           Single Step"
        .DB   CR,LF,"R           Display Registers"
        .DB   CR,LF,"L AAAA<CR>  List Disassembly from AAAA"
        .DB   CR,LF,"B           View/change breakpoint address"
        .DB   CR,LF,"X           Exit"
        .DB   CR,LF,"H           This Help Message",CR,LF,0
        RET
;-----------
; BREAKPOINT
;-----------
;
; save a breakpoint address
;
BPOINT  CALL  ILPSZ
        .DB   CR,LF,"Current Breakpoint : ",0

;show the current break address
        LD    DE,(BRKADD)
        LD    HL,BUFFER
        CALL  WRDASC         ;convert address in de to ASCII
        LD    HL,BUFFER
        CALL  WRDOUT         ;output the address
        CALL  OUTSP

        CALL  ILPSZ
        .DB   CR,LF,"Enter new Breakpoint : ",0

;get a new break address
        CALL  GETCHR
        RET   C              ;ESC
        LD    (BRKADD+1),A   ;save address high
        CALL  GETCHR
        RET   C              ;ESC
        LD    (BRKADD),A     ;save address low
        RET
;-----------------------------------------------
; T COMMAND TOGGLE SINGLE STEPPER (IF INSTALLED)
;-----------------------------------------------
; The single stepper is (now) controlled by bit 7
; of the REFRESH register:
; B7 = 1 single stepper is enabled
; B7 = 0 single stepper is disabled
; 
; The previous version of the single stepper hardware
; used the spare IO port (PORT7) to toggle a flip-flop.
; 
SSTOGL  CALL  ILPSZ
        .DB   CR,LF,"IO7 Single Step Toggle",CR,LF,0
; can't tell if the single stepper is on or off
; so we will just toggle the flip flop
        OUT   (IO7),A        ;toggle hardware latch
;
; toggle REFRESH register Bit 7
;
        LD    A,R
        BIT   7,A
        JR    Z,STOGL1       ;single step is OFF turn ON
        RES   7,A
        LD    R,A            ;turn OFF single stepper
        CALL  ILPSZ
        .DB   "REFRESH D7 Single Stepper is OFF",CR,LF,0
        RET
STOGL1  SET   7,A
        LD    R,A            ;turn ON single stepper
        CALL  ILPSZ
       .DB    "REFRESH D7 Single Stepper is ON",CR,LF,0
        RET
;----------------------------
; M DISPLAY AND MODIFY MEMORY
;----------------------------
MODIFY  CALL  OUTSP
;
;get the address
;
        CALL  GETCHR
        RET   C              ;ESC
        LD    (ADDR+1),A     ;save address high
        CALL  GETCHR
        RET   C
        LD    (ADDR),A       ;save address low
;
; display on a new line
;
MDIFY1  CALL  TXCRLF
        LD    DE,(ADDR)
        LD    HL,BUFFER
        CALL  WRDASC         ;convert address in de to ASCII
        LD    HL,BUFFER
        CALL  WRDOUT         ;output the address
        CALL  OUTSP
;
; get the data at the address
;
        LD    HL,(ADDR)
        LD    A,(HL)
;
; display the data
;
        LD    HL,BUFFER
        CALL  BYTASC         ;convert the data byte in ACC to ASCII
        LD    HL,BUFFER
        CALL  BYTOUT         ;output the byte
        CALL  OUTSP
;
; get new data,exit or continue
;
        CALL  GETCHR
        RET   C              ;ESC
        LD    B,A            ;save it for later
        LD    HL,(ADDR)
        LD    (HL),A         ;put the byte at the current address
        LD    A,B
        CP    (HL)
        JR    Z,MDIFY2
        LD    A,'?'
        CALL  TXDATA         ;not the same data, probably no ram there
;
; increment the address
;
MDIFY2  INC   HL
        LD    (ADDR),HL
        JP    MDIFY1
;-----------------------
; RECEIVE INTEL HEX FILE
;-----------------------
INTHEX  CALL  ILPSZ
        .DB   CR,LF,"Send INTEL Hex File...",0
        CALL  INTELH
        JR    NZ,ITHEX1
        CALL  ILPSZ
        .DB   CR,LF,"File Received OK",CR,LF,0
        RET
ITHEX1  CALL  ILPSZ
        .DB   CR,LF,"Checksum Error",CR,LF,0
        RET
;-----------------
; LIST DISASSEMBLY
;-----------------
LISTA   CALL  OUTSP
        CALL  GETCHR         ;get address high byte
        RET   C              ;ESC 
        LD    (ADDR+1),A     ;save address high
        CALL  GETCHR         ;get address low byte
        RET   C              ;ESC
        LD    (ADDR),A       ;save address low
        LD    DE,(ADDR)
;
; wait for CR or ESC
;
LISTA1  CALL  RXDATA
        CP    ESC
        RET   Z
        CP    CR
        JR    NZ,LISTA1
        LD    A,LF
        CALL  TXDATA
;
; list 10 lines
;
LISTA2  LD    A,CR
        CALL  TXDATA
        LD    B,10
LISTA3  PUSH  BC
        CALL  DISASM          ;disassemble the address
        CALL  TXCRLF
        POP   BC
        DJNZ  LISTA3          ;disassemble 10 lines
;
; list more or exit
;
        CALL  ESCMORE
        JR    Z,LISTA2
        RET
;------------------
; LIST MORE OR EXIT
;------------------
ESCMORE CALL  ILPSZ
        .DB   "[ESC]quit,[SPACE]more",0
ESCMOR1 CALL  RXDATA
        JR    C,ESCMOR1
        CP    ' '            ;space continues
        RET   Z
        CP    ESC            ;escape key exits
        JR    NZ,ESCMOR1
        CP    1              ;clear zero flag
        RET
;------------------------
; EXIT BACK TO SC MONITOR
;------------------------
; we saved the stack pointer when we entered scbug
; we will use it now to return from where we came from
;
EXIT    LD    HL,SSTEP       ;restore the 
        LD    (RST38),HL     ;default interrupt vector
        CALL  ILPSZ
        .DB   CR,LF,"Bye...",CR,LF,0
;
        LD    SP,(SPSAVE)    ;restore stack pointer
        RET
;----------------------------------------
; CONVERT ASCII CHARACTER INTO HEX NIBBLE
;----------------------------------------
; this routine is for masking out keyboard
; entry other than hexadecimal keys
;
;converts ASCII 0-9,A-F into hex LSN
;entry : ACC = ASCII 0-9,A-F
;exit  : carry =  1
;          ACC = hex 0-F in LSN
;      : carry = 0
;          ACC = out of range character & 7FH
; a and f registers modified
;
ASC2HEX AND   7FH            ;strip out parity
        CP    '0'
        JR    C,AC2HEX4      ;less than 0
        CP    3AH
        JR    NC,AC2HEX2     ;more than 9
        AND   0FH            ;convert to nibble
AC2HEX1 SCF                  ;set the carry - is hex
        RET
;
AC2HEX2 CP    'A'
        JR    C,AC2HEX4      ;less than A
        CP    47H
        JR    NC,AC2HEX3     ;more than F
        SUB   07H            ;convert to nibble
        JR    AC2HEX1
        
AC2HEX3 CP    'a'
        JP    C,AC2HEX4      ;less than a
        CP    67H
        JR    NC,AC2HEX4     ;more than f
        AND   0DFH
        SUB   07H            ;convert to nibble
        JR    AC2HEX1
AC2HEX4 AND   0FFH           ;reset the carry - not hex
        RET
;------------------
; D DISPLAY MEMORY 
;------------------
DSPLAY  CALL  OUTSP          ;a space
        CALL  GETCHR
        RET   C
        LD    (ADDR+1),A     ;save address high
        CALL  GETCHR
        RET   C
        LD    (ADDR),A       ;save address low
;
; wait for CR or ESC
;
DPLAY1  CALL  RXDATA
        CP    ESC
        RET   Z
        CP    CR
        JR    NZ,DPLAY1
        LD    A,LF
        CALL  TXDATA
;
; list 8 lines
;
DPLAY2  LD    A,CR
        CALL  TXDATA
        LD    B,8
DPLAY3  PUSH  BC
        CALL  DPLINE
        LD    (ADDR),DE      ;save the new address
        POP   BC
        DJNZ  DPLAY3          ;display 8 lines
;
; list more or exit
;
        CALL  ESCMORE
        JR    Z,DPLAY2
        RET
;-------------------------
; DISPLAY A LINE OF MEMORY
;-------------------------
DPLINE  LD    DE,(ADDR)      ;address to be displayed
        LD    HL,BUFFER      ;HL -> output string
;
; display the address
;
        CALL  WRDASC         ;convert address in de to ASCII
        CALL  SPCBUF
;
; display 16 bytes
;
        LD    B,16
DLINE1  LD    A,(DE)
        CALL  BYTASC
        CALL  SPCBUF
        INC   DE
        DJNZ  DLINE1
        CALL  SPCBUF
;
; now display the ASCII character
; if you are displaying non-memory areas the bytes read and the ASCII could
; be different between the two passes!
;
        LD    DE,(ADDR)
        LD    B,16
DLINE2  LD    A,(DE)
        CP    20H
        JR    C,DOT
        CP    7FH
        JR    NC,DOT
        JP    NDOT
DOT     LD    A,'.'
NDOT    CALL  INSBUF
        INC   DE
        DJNZ  DLINE2
;
; terminate and display string
;
        CALL  BCRLF
        LD    HL,BUFFER
        CALL  SNDMSG
        RET
;----------------------
; SEND ASCII HEX VALUES
;----------------------
; entry:
;        HL -> 1,2 or 4 byte SZ
;
; output the 4 byte, WRDOUT
; the 2 byte, BYTOUT
; or the single byte, NYBOUT
; ASCII string at HL
;
WRDOUT  CALL  BYTOUT         ;call nybout 4 times
BYTOUT  CALL  NYBOUT         ;call nybout 2 times
NYBOUT  LD    A,(HL)         ;call nybout once
        OR    A
        JR    Z,NYBOUT1      ;found a null terminator,exit
        CALL  TXDATA
        INC HL
NYBOUT1 RET
;----------------
;convert to ASCII
;----------------
;
; convert a word,a byte or a nibble to ASCII
;
; entry:  WRDASC           DE = word to convert
;         BYTASC            A = byte to convert
;         NYBASC (B3-B0) of A = nibble to convert
;         HL = character buffer address
;
; exit :  HL = points to last character+1
;         af is modified
;
WRDASC  LD    A,D            ;convert and
        CALL  BYTASC         ;output D
        LD    A,E            ;then E
;
;convert a byte to ASCII 
;
BYTASC  PUSH  AF             ;save a for second nibble
        RRCA                 ;shift high nibble across
        RRCA
        RRCA
        RRCA
        CALL  NYBASC         ;call nibble converter
        POP AF               ;restore low nibble
;
; convert a nibble to ASCII
;
NYBASC  AND   0FH            ;mask off high nibble
        ADD   A,90H          ;convert to
        DAA                  ;ASCII
        ADC   A,40H
        DAA
; save in string
; add a character to build the string,
; add a zero byte terminator each add
;
INSBUF  LD    (HL),A
        INC   HL
        XOR   A              ;clear A
        LD    (HL),A         ;terminate the string
        RET 
;
; put a space in the buffer
;
SPCBUF  LD    A,' '
        JP    INSBUF
;
; put a CR,LF in the buffer
;
BCRLF   LD    A,CR
        CALL  INSBUF
        LD    A,LF
        JP    INSBUF
;----------------------
; SERIAL SINGLE STEPPER
;----------------------
SSSTEP  POP   HL             ;get HL back
        PUSH  AF             ;save af for later
        LD    (TMPHL),HL
        LD    (TMPDE),DE
        LD    (TMPBC),BC
        LD    (TMPIX),IX
        LD    (TMPIY),IY     ;save registers
        POP   HL             ;get af back
        LD    (TMPAF),HL     ;save af
        POP   HL             ;get pc return address
        LD    (TMPPC),HL     ;save pc
        LD    (TMPSP),SP     ;save stack pointer
;
; check for active breakpoint
;
        LD    HL,(BRKADD)    ;if brkadd is zero
        LD    A,H            ;no breakpoint is set
        OR    L
        JR    Z,SSTEPA       ;Z=1 brkadd is zero
;
; breakpoint set, check for address match
;
        LD    BC,(TMPPC)
        AND   A
        SBC   HL,BC          ;compare HL with BC
        JP    NZ,PGMRET      ;continue, no match
;
; breakpoint reached, clear the breakpoint
; 
        LD    HL,0000H
        LD    (BRKADD),HL
;
SSTEPA  CALL  DISREG         ;display registers
;
;return to monitor
;
        EI                   ;re-enable interrupts
        JP    WARM           ;exit the interrupt routine
;
; return to interrupted program
;
PGMRET  LD    SP,(TMPSP)     ;put stack pointer back
        LD    HL,(TMPPC)     ;put return
        PUSH  HL             ;address back on stack
        LD    HL,(TMPAF)
        PUSH  HL             ;save af reg for later
        LD    IY,(TMPIY)
        LD    IX,(TMPIX)
        LD    BC,(TMPBC)
        LD    DE,(TMPDE)     ;restore registers
        POP   AF             ;restore AF
        LD    HL,(TMPHL)     ;restore HL
        EI                   ;re-enable interrupts
        RET                  ;and return to program
;----------------------
; DISPLAY THE REGISTERS
;----------------------
DISREG  CALL  REGSTR         ;display registers
        LD    HL,BUFFER
        CALL  SNDMSG
;
; show the disassembled instruction
;
        LD    DE,(TMPPC)
        CALL  DISASM
        CALL  TXCRLF
        RET
;-----------------------
; CREATE REGISTER STRING
;-----------------------
REGSTR  CALL  ILPSZ
        .DB   CR,LF,"PC   AF   BC   DE   HL   IX   IY   SP   SZ-H-VNC",CR,LF,0
;
; display the registers
;
        LD    B,08H          ;eight registers pairs
        LD    HL,BUFFER      ;->output buffer
        LD    IX,TMPPC       ;->start of saved register pairs
REGSTR1  LD    A,(IX+1)       ;put the ASCII for the
        CALL  BYTASC         ;high byte and low byte of the 
        LD    A,(IX+0)       ;register pair into
        CALL  BYTASC         ;the buffer
        INC   IX
        INC   IX             ;-> next register pair
        LD    A,' '
        LD    (HL),A        ;put a space between the registers
        INC   HL            ;point to the next register pair
        DJNZ  REGSTR1        ;Z=0 get next register pair
;
; display the flags
;
        LD    A,(TMPAF)      ;get the flags and
        CALL  BITASC         ;show them as bits
        JP    BCRLF          ;terminate the string and return
;-----------------------------------------
; send an ASCII string out the serial port
;-----------------------------------------
;
; sends a zero terminated string or 
; 255 characters max. out the serial port
;
;      entry: HL = pointer to zero terminated string
;      exit : same as entry
;
SNDMSG  PUSH  BC
        PUSH  HL
        PUSH  AF
        LD    B,255          ;255 chars max
SDMSG1  LD    A,(HL)         ;get the char
        OR    A              ;zero terminator?
        JR    Z,SDMSG2       ;found a zero terminator, exit
        CALL  TXDATA         ;transmit the char
        INC   HL
        DJNZ  SDMSG1         ;255 chars max!

SDMSG2  POP   AF
        POP   HL
        POP   BC
        RET
;------------------------------------------------------
; convert a byte into a string of ASCII ones and zeroes
;------------------------------------------------------
;
;  description : converts a byte, starting at bit 7,
;                into a string of ASCII
;                ones and zeroes.
;
;        entry:  HL = character buffer address
;        exit :  HL = points to last character+1, a zero terminator
;
;
BITASC  PUSH  BC
        LD    B,08H          ;look at all 8 bits
BTASC1  BIT   7,A            ;a 1 or a 0?
        JR    NZ,BTASC3
        LD    C,30H          ;it's a zero
BTASC2  LD    (HL),C
        JR    BTASC4
BTASC3  LD    C,31H          ;it's a one
        LD    (HL),C
BTASC4  INC   HL
        RLA
        DJNZ  BTASC1         ;next bit
        POP   BC
        RET
;-----------------------------------------
; print an-inline, zero terminated string
;-----------------------------------------
; put the string in the code like the example below
; the routine sends the string from the subroutine return address,to the zero terminator,
; then jumps to the next instruction address to resume the program. 
;
;      CALL ILPSZ
;      .DB  "STRING TO PRINT",0
;      NEXT INSTRUCTION
;
ILPSZ   POP   HL             ;return address is start of string
ILPSZ1  LD    A,(HL)         ;get character
        INC   HL             ;point to next character
        OR    A
        JP    Z,ILPSZ2       ;return if char = 0
        CALL  TXDATA         ;send it
        JR    ILPSZ1         ;and do it again
ILPSZ2  JP    (HL)           ;return to address after zero terminator
;
;DISASSEMBLER
;
#include "DIS-Z80.asm"
CHROP
        CALL   TXDATA
        RET
       .END
