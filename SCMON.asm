;--------------------------------------------
; S O U T H E R N   C R O S S   M O N I T O R
;--------------------------------------------
;
; Written by Craig R. S. Jones 
; Melbourne, Australia.
;
; VERSION 1.2  January 1993 Initial Release
;         1.21 July 1993
;         1.3  February 2003 (Unreleased)
;         1.4  March 2021
;         1.5  June 2021
;         1.6  September 2021
;         1.7  November 2022
;         1.8  March 2023
;         1.9  August 2026
;
; 16 bit multiply from Zaks 'Programming the Z80'
; Music and sound code from
; Talking Electronics TEC-1 monitor, MON-1
; by John Hardy and Ken Stone
;
; if defined use the 74C923 keyboard encoder else use software scanning
#DEFINE 74C923
;
;---------------
; RAM MEMORY MAP
;---------------
BOTRAM  .EQU  2000H          ;bottom of SRAM
TOPRAM  .EQU  3FFFH          ;top of SRAM
;
VARBLS  .EQU  TOPRAM-0FFH    ;monitor variables
BUFFER  .EQU  VARBLS-0100H   ;general purpose buffer area
ISTACK  .EQU  BUFFER         ;allow 256 byte stack
;
RAMEND  .EQU  ISTACK-0100H   ;end of user RAM
RAMSRT  .EQU  BOTRAM         ;start of user RAM
;
; I/O port addresses
;
IO0     .EQU  80H            ;IO port 0
IO1     .EQU  81H            ;IO port 1
IO2     .EQU  82H            ;IO port 2
IO3     .EQU  83H            ;IO port 3
DISPLY  .EQU  84H            ;display latch
SCAN    .EQU  85H            ;display scan latch
KEYBUF  .EQU  86H            ;keyboard buffer
IO7     .EQU  87H            ;spare IO address
;
; Bit-Bang Baud rate constants
;
B300    .EQU  0220H          ;300 baud
B1200   .EQU  0080H          ;1200 baud
B2400   .EQU  003FH          ;2400 baud
B4800   .EQU  001BH          ;4800 baud
B9600   .EQU  000BH          ;9600 baud
;
; key codes
;
KEYFN   .EQU  10H            ;Fn or Go key
KEYAD   .EQU  11H            ;Address key
KEYINC  .EQU  12H            ;Plus key
KEYDEC  .EQU  13H            ;Minus key

;-------------------------
; MONITOR GLOBAL VARIABLES
;-------------------------
;
    .ORG    VARBLS
;
VARIDX  .DS   16             ;reserve some space for indexed variables
SPSAVE  .DS   2              ;save the stack pointer
ADDR    .DS   2              ;temp address
DATA    .DS   1              ;temp data @ address
;
FUNTBL  .DS   2              ;Fn table address
;
; DALLAS SMARTWATCH REGISTERS
;
CALMDE  .DS   2              ;calendar mode
SWREG0  .DS   1              ;10ths, 100ths
SWREG1  .DS   1              ;seconds
SWREG2  .DS   1              ;minutes
SWREG3  .DS   1              ;hours
SWREG4  .DS   1              ;day
SWREG5  .DS   1              ;date
SWREG6  .DS   1              ;month
SWREG7  .DS   1              ;year
;
BAUD    .DS   2              ;bit bang baud rate
KEYTIM  .DS   2              ;beep delay
SPTEMP  .DS   2              ;temp system call SP
;
; BLOCK FUNCTIONS
;
COUNT   .DS   2              ;number of bytes to move
BLKSRT  .DS   2              ;block start address
BLKEND  .DS   2              ;block end address
BLKDST  .DS   2              ;destination address
;
FUNJMP  .DS   2              ;Fn Fn key jump address
;
; DISPLAY SCAN REGISTERS
;
DISBUF  .DS   6              ;display buffer
ONTIM   .DS   1              ;display scan on time
OFTIM   .DS   1              ;display scan off time
;
; MONITOR VARIABLES
;
;
;MODE
; B7 = Address= 0 / Data= 1
; B6 = Beep enabled= 1
; B5 = Auto-increment data entry state
;
MODE    .DS   2              ;display mode
ADRESS  .DS   2              ;user address
KEYDEL  .DS   2              ;auto increment delay
;
; SINGLE STEPPER TEMPORARY REGISTER STORAGE
;
REGPNT  .DS   2   ;register pointer
TMPPC   .DS   2   ;program counter PC
TMPAF   .DS   2   ;AF accumulator,flag
TMPBC   .DS   2   ;BC register pair
TMPDE   .DS   2   ;DE register pair
TMPHL   .DS   2   ;HL register pair
TMPIX   .DS   2   ;index register X
TMPIY   .DS   2   ;index register Y
TMPSP   .DS   2   ;stack pointer SP
;
; RESTART JUMP TABLE AND HARWARE TEST
;
RST08   .DS   2   ;restart 08h jump
RST10   .DS   2   ;restart 10h jump
RST18   .DS   2   ;restart 18h jump
RST20   .DS   2   ;restart 20h jump
RST28   .DS   2   ;restart 28h jump
RST38   .DS   2   ;int interrupt jump
RST66   .DS   2   ;nmi interrupt jump
RAMSUM  .DS   1   ;user ram checksum
SWATCH  .DS   1   ;smartwatch access and ram test location
SYSERR  .DS   2   ;system call error jump
BRKADD  .DS   2   ;break address
;----------------
; RESTART VECTORS
;----------------
;
; Restart 00H - RST 0
; when power is applied to the Southern Cross
; the Z80 starts executing instructions from here
;
        .ORG  0000H
RSTVEC  JP    RESET
;
; Restart 08H - RST 1
;
        .ORG  0008H
        PUSH  HL             ;save HL to restore later
        LD    HL,(RST08)     ;load the vector from RAM
        PUSH  HL             ;and save this jump address
        JR    CALLJMP
;
; Restart 10H - RST 2
;
        .ORG  0010H
        PUSH  HL
        LD    HL,(RST10)
        PUSH  HL
        JR    CALLJMP
;
; Restart 18H - RST 3
;
        .ORG  0018H
        PUSH  HL
        LD    HL,(RST18)
        PUSH  HL
        JR    CALLJMP
;
; Restart 20H - RST 4
;
        .ORG  0020H
        PUSH  HL
        LD    HL,(RST20)
        PUSH  HL
        JR    CALLJMP
;
; Restart 28H - RST 5
;
        .ORG  0028H
        PUSH  HL
        LD    HL,(RST28)
        PUSH  HL
        JR    CALLJMP
;
; Restart 30H - RST 6 - Monitor routines entry point
;
        .ORG  0030H
RST30   JP    SYSCALL
;
; Restart 38H - RST 7
; if interrupts are enabled,and an int occurs- 
; further interrupts are disabled, 
; the program counter is pushed onto the stack, 
; and execution starts here
;
        .ORG  0038H
        PUSH  HL
        LD    HL,(RST38)
        JP    (HL)
;
INTRET
        POP     HL
        RETI                 ;return from int
;
; Restart 66H NMI vector
; same as above but NMI cannot be disabled.
;
        .ORG    0066H
        PUSH    HL
        LD      HL,(RST66)
        JP      (HL)
;
NMIRET
        POP     HL
        RETN                ;return from NMI
;
; jump to the address on the stack and set the RETurn address
CALLJMP
        LD    HL,RSTRET     ;get the return address
        EX    (SP),HL       ;exchange the jump and return address
        JP    (HL)          ;jump to the subroutine
;
; return from restart
; restart calls return here
RSTRET
        POP   HL            ;get HL back and return
RETURN  RET
;
; Fn Fn default vector
;
        .ORG  00A0H
FN2VEC  .DW   0000H
;--------------------
; SYSTEM CALL HANDLER
;--------------------
; calls to basic IO and other routines
; within the monitor have been assigned
; system call numbers to avoid re-writing
; user software if monitor absolute addresses
; change in subsequent monitors
;
; Entry : c = call number
; see routines for entry and exit parameters
;
        .ORG  00D0H
SYSCALL DEC   SP
        DEC   SP            ;leave space for syscall
        LD    (SPTEMP),SP   ;points to syscall lo
        PUSH  AF
        PUSH  DE
        PUSH  HL            ;save registers
        LD    A,C           ;get call number
        AND   127           ;ensure in limits
        SLA   A             ;multiply by two
        LD    H,1           ;load jump table high byte
        LD    L,A           ;load index
        LD    A,(HL)
        INC   HL
        LD    D,(HL)        ;get jump address
        LD    HL,(SPTEMP)   ;point to syscall lo
        LD    (HL),A        ;put syscall lo on stack
        INC   HL
        LD    A,D
        LD    (HL),A        ;put syscall hi on stack
        POP   HL
        POP   DE
        POP   AF            ;restore registers
        RET                 ;jumps to system call
;
; Error trap
; halt the machine until Reset or Interrupt
;
TRAP    LD    HL,(SYSERR)
        JP    (HL)
;
STOP    HALT
;-----------------------
; SYSTEM CALL JUMP TABLE
;-----------------------
        .ORG    0100H
SYSJMP
        .DW   MAIN           ;0 restart monitor
        .DW   VERS           ;1 return software version number
        .DW   DISADD         ;2 covert address to seven segment code in display buffer
        .DW   DISBYT         ;3 convert data to seven segment code in display buffer
        .DW   CLRBUF         ;4 clear the seven segment display buffer
        .DW   SCAND          ;5 scan the seven segment displays
        .DW   CONBYT         ;6 convert a byte into seven segment code
        .DW   CONVHI         ;7 convert the high nibble into seven segment code
;
        .DW   CONVLO         ;8 convert the low nibble into seven segment code
        .DW   SKEYIN         ;9 scan the display until key press
        .DW   SKEYRL         ;10 scan the display until key release
        .DW   KEYIN          ;11 wait for a key press
        .DW   KEYREL         ;12 wait for key release
        .DW   MENU           ;13 menu handler
        .DW   CHKSUM         ;14 calculate 8 bit checksum
        .DW   MUL16          ;15 16 bit multiply
;
        .DW   RAND           ;16 random number generator
        .DW   INDEXB         ;17 8 bit index look up table to an 8 bit byte
        .DW   INDEXW         ;18 8 bit index look up table to a 16 bit word
        .DW   MUSIC          ;19 music sequencer
        .DW   TONE           ;20 output a tone
        .DW   BEEP           ;21 key entry beep
        .DW   SKATE          ;22 scan 8x8 display
        .DW   TXDATA         ;23 serial bit bang transmit
;
        .DW   RXDATA         ;24 serial bit bang receive
        .DW   ASCHEX         ;25 convert ASCII character to hexadecimal
        .DW   WWATCH         ;26 write to smartwatch
        .DW   RWATCH         ;27 read from smartwatch
        .DW   ONESEC         ;28 smartwatch one second delay 40
        .DW   RLSTEP         ;29 relay board sequencer
        .DW   DELONE         ;30 one second delay
        .DW   SCANKEY        ;31 scan the keyboard for a key press
;
        .DW   INTELH         ;32 receive INTEL hex file
        .DW   SPLIT          ;33 separate a byte into two right justidied nibbles
        .DW   TRAP           ;34
        .DW   TRAP           ;35
        .DW   TRAP           ;36
        .DW   TRAP           ;37
        .DW   TRAP           ;38
        .DW   PCBTYP         ;39 return PCB type SC
;
        .DW   TRAP           ;40
        .DW   KBDTYP         ;41 return keyboard type 74c923 or software scanned
        .DW   UPDATE         ;42 update the display buffer
        .DW   VARRAM         ;43 return variable base address
        .DW   SERINI         ;44 initialise bit bang serial
        .DW   TRAP           ;45
        .DW   MSDELAY        ;46 millisecond delay
        .DW   TRAP           ;47
;
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP

        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP

        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP

        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP

        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
        .DW TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP,TRAP
;------------------------------
; POWER UP RESET / MANUAL RESET
;------------------------------
        .ORG    0200H
;
; wait for smart socket
; to recover from power down
;
RESET   LD    A,55H
        LD    (SWATCH),A     ;write to RAM
        XOR   A
        OUT   (DISPLY),A     ;write nothing to
        OUT   (SCAN),A       ;on board IO
        IN    A,(KEYBUF)     ;to help debugging
        LD    A,(SWATCH)     ;read from RAM
        CP    55H            ;is it ready?
        JP    NZ,RESET       ;keep trying
;
; load stack pointer
;
RESET1  LD    SP,ISTACK      ;initialise monitor stack pointer
        IM    1              ;set interrupt mode 1 - use the automated interrupt
;
; set up restart vectors
;
        LD    HL,TXDATA      ;bit-banged serial transmit
        LD    (RST08),HL
        LD    HL,RXDATA      ;bit-banged serial receive (blocking)
        LD    (RST10),HL
        LD    HL,RETURN
        LD    (RST18),HL
        LD    (RST20),HL
        LD    (RST28),HL
        LD    HL,NMIRET
        LD    (RST66),HL     ;NMI vector
        LD    HL,SSTEP       ;single stepper interrupt
        LD    (RST38),HL     ;INT vector
        LD    HL,STOP
        LD    (SYSERR),HL    ;invalid system call error
;
; perform checksum on user RAM
;
        LD    HL,RAMSRT      ;start of user RAM
        LD    DE,RAMEND      ;end of user RAM
        CALL  CHKSUM
        LD    (RAMSUM),A     ;RAM checksum
;
; set up default variables
;
        LD    HL,FUNLST
        LD    (FUNTBL),HL    ;function key table
        LD    HL,(FN2VEC)    ;Fn Fn default vector
        LD    (FUNJMP),HL    ;fn fn jump
        XOR   A
        LD    (REGPNT),A     ;init single stepper
        LD    (MODE),A       ;start with speaker on
;
        LD    HL,B9600       ;default baud rate
        CALL  SERINI         ;initialise the serial port
;
; initialise display scan variables
;
        LD    HL,0100H
        LD    (KEYDEL),HL    ;auto-inc/dec delay
        LD    HL,1000H
        LD    (KEYTIM),HL    ;delay time instead of a beep
#IFDEF 74C923
        LD    A,20H
#ELSE
        LD    A,08H
#ENDIF
        LD    (OFTIM),A      ;display off time

        CALL  BEEP
        CALL  BEEP

; initialise the 'display on' time
#IFDEF 74C923
        LD    A,08H
#ELSE
        LD    A,10H
#ENDIF
        LD    (ONTIM),A      ;display on time
    
        EI                   ;enable interrupts
;-----------------
; SET UP MAIN LOOP
;-----------------
MAIN    LD    SP,ISTACK      ;initialise/reset stack
        LD    HL,RAMSRT
        LD    (ADRESS),HL    ;default start address
        LD    A,(MODE)
        OR    80H            ;start off in data mode
        LD    (MODE),A
;
; scan the displays until a key is pressed
;
MAIN1   CALL  UPDATE
MAIN2   CALL  SKEYIN         ;wait for a key
        LD    HL,MENLST      ;use the menu handler
        CALL  MENU           ;routine for each key
        CALL  UPDATE         ;update buffer and
        CALL  SKEYRL         ;wait for key release
        JP    MAIN2
;
; main menu key table
;
MENLST  .DB 20
        .DB 00H,01H,02H,03H,04H,05H,06H,07H
        .DB 08H,09H,0AH,0BH,0CH,0DH,0EH,0FH
        .DB 10H,11H,12H,13H
        .DW HEXKEY,HEXKEY,HEXKEY,HEXKEY
        .DW HEXKEY,HEXKEY,HEXKEY,HEXKEY
        .DW HEXKEY,HEXKEY,HEXKEY,HEXKEY
        .DW HEXKEY,HEXKEY,HEXKEY,HEXKEY
        .DW FUNKEY,ADDKEY,INCKEY,DECKEY
;---------------------------------------------------
; ENTER HEX KEY AS LEAST SIGNIFICANT ADDRESS OR DATA
;---------------------------------------------------
HEXKEY  CALL  BEEP
        LD    HL,MODE
        BIT   7,(HL)         ;addr or data mode?
        JP    Z,HEXKY2       ;in addr mode
;
; in data mode
;
HEXKY1  BIT   5,(HL)
        JR    Z,DATENT
;
; auto increment the address in data entry mode
;
        RES   5,(HL)         ;clear the auto increment flag
        CALL  DATENT1
        LD    HL,(ADRESS)
        INC   HL             ;auto increment the address
        LD    (ADRESS),HL
        RET

DATENT  SET   5,(HL)         ;set auto increment flag

DATENT1 LD    HL,(ADRESS)
        SLA   (HL)           ;from the current
        SLA   (HL)           ;address,move the
        SLA   (HL)           ;lsn to the msn.
        SLA   (HL)           ;put the key in
        OR    (HL)           ;the new data back at
        LD    (HL),A         ;the current address
        RET
;
; in address mode
;
HEXKY2  LD    HL,(ADRESS)
        SLA   L              ;current address
        RL    H              ;and do a 16 bit
        SLA   L              ;left shift 4 times
        RL    H              ;to make room
        SLA   L              ;for the new key
        RL    H
        SLA   L
        RL    H
        OR    L              ;it in the least
        LD    L,A            ;significant nibble
        LD    (ADRESS),HL    ;save current address
        RET
;-------------
; CHANGE MODES
;-------------
ADDKEY  CALL  BEEP
        LD    A,(MODE)
        XOR   80H            ;toggle mode
        LD    (MODE),A
        CALL  AUTRST         ;reset auto increment mode
        RET
;--------------------------
; RESET AUTO-INCREMENT MODE
;--------------------------
AUTRST  LD    A,(MODE)
        RES   5,A            ;reset auto-increment mode
        LD    (MODE),A
        RET
;------------------
; INCREMENT ADDRESS
;------------------
INCKEY  CALL  AUTRST         ;reset auto-increment mode
        CALL  BEEP
INCKY1  LD    HL,(ADRESS)
        INC   HL             ;inc address
        LD    (ADRESS),HL
        CALL  UPDATE
        LD    HL,(KEYDEL)    ;auto repeat delay
INCKY2  CALL  SCAND
        CALL  SCANKEY
        BIT   5,A            ;return if
        JR    Z,INCKY3       ;key released
        AND   1FH            ;strip unused bits
        CP    KEYINC         ; '+'
        JR    NZ,INCKY3      ;not '+' key
        LD    DE,0001H
        SBC   HL,DE
        JP    NC,INCKY2      ;scan display for keydel
        JP    INCKY1         ;inc address
INCKY3  RET
;------------------
; DECREMENT ADDRESS
;------------------
DECKEY  CALL  AUTRST         ;reset auto-increment mode
        CALL  BEEP
DECKY1  LD    HL,(ADRESS)
        DEC   HL             ;dec address
        LD    (ADRESS),HL
        CALL  UPDATE
        LD    HL,(KEYDEL)    ;auto repeat delay
DECKY2  CALL  SCAND
        CALL  SCANKEY
        BIT   5,A            ;return if
        JR    Z,DECKY3       ;key released
        AND   1FH
        CP    KEYDEC         ; '-'
        JR    NZ,DECKY3      ;not '-' key
        LD    DE,0001H
        SBC   HL,DE
        JP    NC,DECKY2      ;scan display for keydel
        JP    DECKY1         ;inc address 
DECKY3  RET
;-----------------------------------------
; UPDATE DISPLAY BUFFER TO CURRENT ADDRESS
;-----------------------------------------
;
; update the display buffer with the 
; current address, the data at the current address
; and set the decimal points to
; address or data mode
;
;   entry : none
;   exit :  modifies a
;
UPDATE  PUSH  HL
        PUSH  BC
        LD    HL,(ADRESS)    ;get address
        CALL  DISADD         ;and data, put in
        LD    A,(HL)
        CALL  DISBYT         ;display buffer
;
; in address or data mode?
;
        LD    HL,MODE
        BIT   7,(HL)         ;data or addr mode?
        JP    Z,ADMODE       ;address mode
;
; show data mode
;
        BIT   5,(HL)         ;auto-inc mode?
        JP    Z,UPDATE1
        LD    HL,DISBUF
        LD    B,1            ;turn on one DP for auto-inc
        JP    SETDP
;
UPDATE1 LD    HL,DISBUF      ;set the dp's
        LD    B,2            ;in the data
        JP    SETDP          ;display
;
; show address mode
;
ADMODE  LD    HL,DISBUF+2
        LD    B,4            ;set the dp's in the address display
;
; set decimal point
;
; set dp in the byte pointed to by hl
;
SETDP   SET   7,(HL)         ;set bit 7 for dp
        INC   HL             ;point to next byte
        DJNZ  SETDP          ;more bits to set
        POP   BC
        POP   HL
        RET
;-----------------------------------------
; RETURN THE BASE ADDRESS OF RAM VARIABLES
;-----------------------------------------
;
;   entry: none
;   exit: HL = base address of variables
;
VARRAM  LD    HL,VARBLS
              RET
;-----------
; BOARD TYPE
;-----------
; returns the type of board the monitor is built for
; entry = none
; exit: hl -> 'SC-1'  acc = 01h
;
PCBTYP  LD    HL,TYPESZ
        LD    A,(TYPEBF)
        RET
;---------------
; VERSION NUMBER
;---------------
;returns the software version number
;
;   entry : none
; exit : hl -> version number string
;        acc = bcd version number d7-d4 = major, d3-d0 minor
;
VERS    LD    HL,VERSZ
        LD    A,(VERBCD)
        RET
;--------------
; KEYBOARD TYPE
;--------------
; returns the type of keyboard used
; entry = none
; exit: hl -> keyboard type string
;       acc = 01h mm74c923 hardware encoder
;       acc = 02h software scanned
;
KBDTYP  LD    HL,KYBSZ
        LD    A,(KYBDBF)
        RET

TYPESZ  .DB   "SC-1",0
TYPEBF  .DB   01H

VERSZ   .DB   "1.9",0
VERBCD  .DB   19H

#IFDEF 74C923
KYBSZ   .DB   "Hardware",0
KYBDBF  .DB   01H 
#ELSE
KYBSZ   .DB   "Software",0
KYBDBF  .DB   02H 
#ENDIF

;-------------------------
; ADDRESS > DISPLAY BUFFER
;-------------------------
; convert HL to seven segment code
; and put in address display buffer.
;
; entry : HL = address to be displayed
;
; exit  : no registers modified
;
DISADD  PUSH  AF
        PUSH  HL
        PUSH  HL
        LD    A,H
        CALL  CONBYT
        LD    (DISBUF+4),HL
        POP   HL
        LD    A,L
        CALL  CONBYT
        LD    (DISBUF+2),HL
        POP   HL
        POP   AF
        RET
;---------------------------
; DATA BYTE > DISPLAY BUFFER
;---------------------------
; convert the acc to seven segment code
; and put in data display buffer.
;
; entry :  a = data display byte
;
; exit  : no registers modified
;
DISBYT  PUSH  HL
        CALL  CONBYT
        LD    (DISBUF),HL
        POP   HL
        RET
;---------------------------------------
; CONVERT BYTE TO 7 SEGMENT DISPLAY CODE
;---------------------------------------
; converts byte in acc to seven segment code
; for display
; entry : a = byte to be converted
; exit  : h = hi nibble seven segment code
;         l = lo nibble seven segment code
;         a = not modified
CONBYT  PUSH  AF
        PUSH  AF
        CALL  CONVHI         ;convert hi nibble
        LD    H,A
        POP   AF
        CALL  CONVLO         ;convert lo nibble
        LD    L,A
        POP   AF
        RET
;---------------------------------------------
; HEXADECIMAL TO SEVEN SEGMENT CODE CONVERSION
;---------------------------------------------
; converts nibble in acc to seven segment code
; for seven segment displays
; convhi = converts high nibble
; convlo = converts lo nibble
;
; entry : a = nibble to be converted
; exit  : a = seven segment code
;
CONVHI  RLCA
        RLCA
        RLCA                 ;move to lo nibble
        RLCA                 ;for conversion
CONVLO  PUSH  BC
        PUSH  HL
        LD    HL,SEGMNT      ;use the hex value
        AND   0FH            ;to index to the
        LD    C,A            ;the seven segment
        LD    B,00H          ;code for that value
        ADD   HL,BC          ;and return with
        LD    A,(HL)         ;code in a
        POP   HL
        POP   BC
        RET
;
; hexadecimal to 7 segment display code table
;
SEGMNT  .DB 3FH,06H,5BH,4FH ;0,1,2,3
        .DB 66H,6DH,7DH,07H ;4,5,6,7
        .DB 7FH,6FH,77H,7CH ;8,9,A,B
        .DB 39H,5EH,79H,71H ;C,D,E,F
;-------------
; SCAN DISPLAY
;-------------
; as the displays are multiplexed, the data for each
; display must be latched into the display segment
; latch in turn and the corresponding bit in the display
; scan latch turned on to display the data.
; two short delays are used to adjust the duty
; cycle and hence display brightness.
;
; the serial output is on D6 so it must be kept high! 
;
; entry : none
; exit  : no registers modified
;
SCAND   PUSH  AF
        PUSH  BC
        PUSH  HL             ;save registers
        LD    HL,DISBUF+5
        LD    C,20H
SCAND1  LD    A,(HL)
        OUT   (DISPLY),A     ;output character
        LD    A,C
        OR    40H            ;keep D6 high
        OUT   (SCAN),A       ;turn on display
        LD    A,(ONTIM)      ;do a short delay
        LD    B,A            ;to adjust on time
SCAND2  DJNZ  SCAND2         ;of display
        LD    A,B            ;b is now clear,
        OR    40H            ;keep D6 high
        OUT   (SCAN),A       ;use it to turn off scan.
        LD    A,(OFTIM)      ;do a short delay
        LD    B,A            ;to adjust off time
SCAND3  DJNZ  SCAND3         ;of display
        DEC   HL             ;point to next
        RRC   C              ;element in buffer
        JR    NC,SCAND1      ;display next element
        LD    A,B            ;b is now clear,
        OUT   (DISPLY),A     ;and clear display latch
        OR    40H            ;keep D6 high
        OUT   (SCAN),A       ;use it to turn off scan
        POP   HL
        POP   BC
        POP   AF             ;restore registers
        RET
;---------------------
; CLEAR DISPLAY BUFFER
;---------------------
CLRBUF  PUSH  HL
        PUSH  BC
        LD    HL,DISBUF
        LD    B,6
CLRBF1  LD    (HL),00H       ;put zero in 6
        INC   HL             ;locations pointed
        DJNZ  CLRBF1         ;to by HL
        POP   BC
        POP   HL
        RET
;--------------
; SCAN KEYBOARD
;--------------
; use the hardware or software scanned keyboard
;
; software scanned keyboard
; uses display scan drivers for columns
; and keyboard buffer as rows.
; make each data line high in turn and check
; if each individual pushbutton is pressed.
;
; entry : none
; exit  : a = 00h if no key detected
;         a = detected key bits 0-4
;             bit 5 = HIGH key available
; 
; Bit 6 of the keyboard buffer is the serial input
;
SCANKEY PUSH  BC
        PUSH  DE             ;save registers
        PUSH  HL
;
#IFDEF 74C923
;
;74c923 keyboard encoder
;
       IN  A,(KEYBUF)        ;read hardware encoder
       AND 3FH               ;strip unused bits
       POP HL
       POP DE
       POP BC
       RET
#ELSE
;
; software scan keyboard 
;
SCANKY1 XOR   A
        OUT   (DISPLY),A     ;clear display latch
        LD    B,A            ;key
        LD    D,A            ;count
        LD    E,01H          ;mask
SCANKY2 LD    C,08H          ;scan
SCANKY3 LD    A,C
        OR    40H            ;keep serial output bit high
        OUT   (SCAN),A       ;output scan
        NOP
        NOP
        NOP
        IN    A,(KEYBUF)     ;read key buffer
        AND   E              ;mask 
        JR    Z,SCANKY4      ;key not detected
        INC   D
        LD    L,B            ;save key
;
; end of rows?
;
SCANKY4 INC   B              ;next key
        SRA   C              ;shift scan right
        JR    NC,SCANKY3     ;next row
;
; end of columns?
;
        SLA   E              ;shift mask left
        BIT   5,E            ;end of keyscan?
        JR    Z,SCANKY2      ;next column
;
; end of scan
;
        LD    A,D
        CP    00H
        JR    Z,SCANKY6      ;no key pressed
        CP    01H
        JR    NZ,SCANKY1     ;more than one key pressed
;
; one key detected
;
        LD    A,40H          ;keep serial data out bit high
        OUT   (SCAN),A       ;clear scan reg
        LD    A,L            ;return key in ACC
        SET   5,A            ;set data available flag
        JR    SCANKY7
;
; no key
;
SCANKY6 LD    A,40H          ;keep serial data out bit high
        OUT   (SCAN),A       ;clear scan reg
        XOR   A              ;clear ACC
SCANKY7 POP   HL
        POP   DE
        POP   BC
        RET
#ENDIF
;-----------------------------
; SCAN DISPLAY UNTIL KEY PRESS
;-----------------------------
; entry : none
; exit  : a = key value 00h to 1fh
;         flag register modified
;
SKEYIN  CALL  SCAND          ;scan display
        CALL  SCANKEY
        BIT   5,A
        JR    Z,SKEYIN       ;no key press
        AND   1FH            ;strip unused bits
        RET
;-------------------------------
; SCAN DISPLAY UNTIL KEY RELEASE
;-------------------------------
; entry : none
; exit  : none
;
SKEYRL  PUSH  AF
SKEYL1  CALL  SCAND          ;scan display
        CALL  SCANKEY
        BIT   5,A
        JR    NZ,SKEYL1      ;key not released
        POP   AF
        RET
;-------------------
; WAIT FOR KEY PRESS
;-------------------
; entry : none
; exit  : a = key value 00h to 1fh
;         flag register modified
;
KEYIN   CALL  SCANKEY
        BIT   5,A
        JR    Z,KEYIN        ;no key press
        AND   1FH            ;strip unused bits
        RET
;---------------------
; WAIT FOR KEY RELEASE
;---------------------
; entry : none
; exit  : none
;
KEYREL  PUSH  AF
KEYRL1  CALL  SCANKEY
        BIT   5,A
        JR    NZ,KEYRL1
        POP   AF
        RET
;-----------------
; KEY MENU HANDLER
;-----------------
; compares acc against table of elements,
; if found jump to address corresponding to
; that element, returns if element not found.
; entry :  ACC = element to look for
;           HL = points to table
; exit  : element not found
;           HL holds address of last element
;         element found
;           control passes to jump address with
;           return address of menu call on stack
;
MENU    PUSH  AF
        PUSH  BC
        PUSH  DE             ;save registers
        PUSH  HL             ;calculate address
        LD    D,00H          ;of the jump table by
        LD    E,(HL)         ;adding the index to
        INC   HL             ;the elements
        ADD   HL,DE          ;to the addr of the
        LD    D,H            ;table
        LD    E,L
        POP   HL
        LD    B,(HL)         ;get number of entries
        INC   HL             ;point to list of entries
MENU1   CP    (HL)           ;compare with entry
        JR    Z,MENU2        ;found value in table
        INC   HL             ;next entry in list
        INC   DE             ;next entry in
        INC   DE             ;jump table
        DJNZ  MENU1          ;check more entries
        POP   DE
        POP   BC
        POP   AF
        RET                  ;not in table
;
; found element in the table
; pass control to the jump handler
;
MENU2   LD    A,(DE)         ;get the jump addr
        LD    L,A            ;from the table
        inc   de             ;and jump to
        LD    A,(DE)         ;the jump address
        LD    H,A            ;for that entry
        POP   DE
        POP   BC
        POP   AF             ;restore registers
        JP    (HL)
;-------------------
; CALCULATE CHECKSUM
;-------------------
; calculates checksum between start and end (inclusive)
;
; entry : HL = start of block to sum
;         DE = end of block to sum
; exit  : ACC =  checksum
;         flag register modified
;
CHKSUM  PUSH  HL
        PUSH  DE
        INC   DE             ;end of block+1
        XOR   A              ;clear checksum
CHKSM1  ADD   A,(HL)         ;compute checksum
        INC   HL             ;point to next element
        AND   A              ;set carry
        PUSH  HL
        SBC   HL,DE          ;subtract
        POP   HL
        JR    C,CHKSM1       ;more elements
        POP   DE
        POP   HL
        RET
;--------------------------
; ACCESS BYTE LOOK UP TABLE
;--------------------------
; use 8 bit index to access byte look
; up table
; entry :  ACC = number of element in table
;           HL = address of look up table
; exit :    HL = address of element number in ACC
;
INDEXB  PUSH  DE
        LD    E,A            ;use de as index
        LD    D,0            ;to element in table
        ADD   HL,DE          ;by adding to hl
        POP   DE
        RET
;--------------------------
; ACCESS WORD LOOK UP TABLE
;--------------------------
; use 8 bit index to access word look
; up table
; entry :  ACC = number of element in table
;           HL = address of look up table
; exit :    HL = address of 2 byte element number in ACC
;
INDEXW  PUSH  DE
        LD    E,A
        SLA   E              ;multiply by two
        ld    d,0
        ADD   HL,DE
        POP   DE
        RET
;-------------------------------
; GENERATE A QUASI-RANDOM NUMBER
;-------------------------------
; generate an 16 bit random number
; using linear congruential method.
;
;     Rn+1 = (aRn+c) MOD m
;
; refresh register used for Rn and c
;   entry : none
;   exit  : HL = random word
;   no registers modified
;
RAND    PUSH  AF
        PUSH  BC
        PUSH  DE             ;save registers
;
; calculate aRn
;
        LD    A,R            ;get a random seed from the refresh register
        LD    E,A            ;multiply random number
        LD    D,0            ;(rn) by
        LD    HL,0548H       ;constant (a)
        CALL  MUL16
;
; calculate aRn+c
;
        LD    A,R            ;add it to another
        LD    B,0            ;read of the
        LD    C,A            ;the refresh
        ADD   HL,BC          ;register (c)
        POP   DE
        POP   BC
        POP   AF             ;restore registers
        RET
;----------------------
; 16 BIT MULTIPLICATION
;----------------------
; 16 bit multiply
;  entry : HL = multiplicand (mpd)
;          DE = multiplier (mpr)
;  exit  : HL = result
; from Zaks 'Programming the Z80'
;
MUL16   PUSH  AF
        PUSH  BC
        LD    C,H            ;mpr(H)
        LD    A,L            ;mpr(L)
        LD    B,16           ;bit counter
        LD    HL,0           ;clear result
MULT    SRL   C              ;mpr (H)
        RRA                  ;mpr (L)
        JR    NC,MULT1       ;test carry
        ADD   HL,DE          ;add mpd to result
MULT1   EX    DE,HL
        ADD   HL,HL          ;double -shift mpd left
        EX    DE,HL
        DJNZ  MULT           ;done?
        POP   BC
        POP   AF
        RET
; music routine
; adapted from talking electronics TEC-1
; monitor MON-1
; by John Hardy and Ken Stone
;
;----------------
; MUSIC SEQUENCER
;----------------
; sequences through a table of notes
; 1EH = repeat tune until reset
; 1FH = play once and return
;  entry : HL = address of note table
;  exit : no registers modified
MUSIC   PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL             ;save registers
        PUSH  HL
        EX    DE,HL          ;get address of music
;
; play each note in turn
;
STEP    LD    A,(DE)         ;get element from table
        AND   1FH            ;strip unused bits
;
; if element is 00h pause for a while
;
        CP    00H
        JP    NZ,STEP1
        LD    BC,1000H
PAUSE   DEC   BC
        LD    A,B
        OR    C
        JP    NZ,PAUSE       ;loop until DE = 0
        INC   DE             ;point to next element
        JP    STEP
;
; if element is 1EH repeat tune
;
STEP1   CP    1EH
        JP    NZ,STEP2
        POP   DE             ;get table address back
        PUSH  DE             ;save it for later
        JP    STEP
;
; if element is 1FH return
;
STEP2   CP    1FH            ;end of tune table?
        JP    NZ,STEP3
        POP   HL
        POP   HL
        POP   DE
        POP   BC
        POP   AF
        RET
;
; now play the note
;
STEP3   LD    B,A            ;save element in B
        LD    HL,PERIOD      ;point to period/2 table
        CALL  INDEXB         ;get period/2
        LD    A,(HL)         ;get element
        PUSH  AF             ;save for later
        LD    A,B            ;get element back in a
        LD    HL,LENGTH      ;point to duration/2 table
        CALL  INDEXB         ;get duration/2
        LD    A,(HL)         ;get element
        LD    L,A
        LD    H,0            ;hl = duration/2
        POP   AF
        CALL  TONE           ;do note routine
        INC   DE
        JP    STEP           ;step to next element
;
; period/2 of note
;
PERIOD  .DB 8CH,83H,7CH,75H,70H,67H,62H,5CH
        .DB 57H,52H,4EH,48H,45H,41H,3CH,39H
        .DB 36H,32H,2FH,2CH,2AH,27H,25H,23H
;
; note duration/2
;
LENGTH  .DB 19H,1AH,1CH,1DH,1EH,20H,23H,25H
        .DB 27H,29H,2CH,2EH,31H,33H,37H,3AH
        .DB 3DH,41H,45H,49H,4DH,52H,57H,5CH
        .DB 10H
;
; tone routine
; adapted from Talking Electronics TEC-1
; monitor MON-1
; by John Hardy and Ken Stone
;
;--------------
; OUTPUT A TONE
;--------------
;
; entry : ACC = period/2 of note
;         HL  = duration/2 of note
; exit  : no registers modified
TONE    PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    DE,0001H
        LD    C,A
        ADD   HL,HL          ;double duration
        XOR   A
TONE1   XOR   80H            ;toggle speaker bit
        OR    40H            ;keep D6 high
        OUT   (SCAN),A       ;output speaker bit
        LD    B,C
TONE2   PUSH  BC
        LD    B,02H
TONE3   DJNZ  TONE3          ;delay for period/2
        POP   BC
        DJNZ  TONE2          ;delay for period/2
        SBC   HL,DE          ;end of note?
        JR    NZ,TONE1       ;do again
        POP   HL
        POP   DE
        POP   BC
        POP   AF
        RET
;---------------
; KEY ENTRY BEEP
;---------------
BEEP    PUSH  HL
        PUSH  AF
        LD    HL,MODE
        BIT   6,(HL)         ;beep enabled?
        JR    Z,BEEP2        ;beep is enabled
;
; do keypress delay
;
        PUSH  DE            ;do a short
        LD    DE,0001H      ;delay to prevent
        LD    HL,(KEYTIM)   ;recognition
BEEP1   SBC   HL,DE         ;of double
        JR    NC,BEEP1      ;key strokes
        POP   DE
        JR    BEEP3
;
; output keypress tones
;
BEEP2   LD    A,24H
        LD    HL,0030H
        CALL  TONE           ;do first tone
        LD    A,0EH
        LD    HL,0050H
        CALL  TONE           ;do second tone
BEEP3   POP   AF
        POP   HL
        RET
;----------------------------------------
; BREAKPOINT AND SINGLE STEPPING ROUTINES
;----------------------------------------
; displays and modifies registers after breakpoint
; (RST 38H) or single step interrupt (if hardware
; attached).
; insert RST 38H (FFH) in program to examine
; and modify registers.
;
SSTEP   POP   HL             ;get hl back
        PUSH  AF             ;save af for later
        LD    (TMPHL),HL
        LD    (TMPDE),DE
        LD    (TMPBC),BC
        LD    (TMPIX),IX
        LD    (TMPIY),IY     ;save registers
        POP   HL             ;get af back
        LD    (TMPAF),HL     ;save AF
        POP   HL             ;get pc return address
        LD    (TMPPC),HL     ;save PC
        LD    (TMPSP),SP     ;save stack pointer
;
; step through,display and edit registers
;
        CALL  BEEP
        LD    A,(REGPNT)     ;get current reg
        AND   7              ;make sure in limits
        LD    (REGPNT),A     ;save it
SSTEP1  CALL  SETREG         ;set up display buffer
        CALL  SKEYRL         ;wait for a key
        CALL  SKEYIN         ;wait for key release
        LD    HL,REGTBL      ;handle the key
        CALL  MENU           ;and update display
        JP    SSTEP1         ;before returning to loop
;
; register display key table
;
REGTBL  .DB 14H
        .DB 00H,01H,02H,03H,04H,05H,06H,07H
        .DB 08H,09H,0AH,0BH,0CH,0DH,0EH,0FH
        .DB 10H,11H,12H,13H
        .DW REGKEY,REGKEY,REGKEY,REGKEY
        .DW REGKEY,REGKEY,REGKEY,REGKEY
        .DW REGKEY,REGKEY,REGKEY,REGKEY
        .DW REGKEY,REGKEY,REGKEY,REGKEY
        .DW RETMON,RETPGM,INCSTP,DECSTP
;
; register name characters
;
REGNAM  .DW 7339H
        .DW 7771H,7C39H,5E79H
        .DW 7438H,0676H,066EH
        .DW 6D73H
;--------------
; EDIT REGISTER
;--------------
REGKEY  CALL  BEEP
        PUSH  AF             ;save key for later
        LD    A,(REGPNT)
;
; edit register
;
        LD    HL,TMPPC
        CALL  INDEXW
        LD    C,(HL)
        INC   HL
        LD    B,(HL)         ;get reg contents
        SLA   C
        RL    B
        SLA   C
        RL    B
        SLA   C
        RL    B              ;shift register
        SLA   C              ;four bits
        RL    B              ;left and
        POP   AF             ;put the key
        OR    C              ;into the lsn
        LD    C,A            ;and put the
        LD    (HL),B         ;register back
        DEC   HL             ;where it belongs
        LD   (HL),C
        RET
;------------------
; RETURN TO MONITOR
;------------------
RETMON  CALL  BEEP
        CALL  SKEYRL
        EI                   ;enable interrupts again
        JP    MAIN
;------------------
; RETURN TO PROGRAM
;------------------
RETPGM  LD    SP,(TMPSP)     ;put stack pointer back
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
        EI                   ;enable interrupts
        RET                  ;and return to program
;----------------------
; display next register
;----------------------
INCSTP  CALL  BEEP
        LD    A,(REGPNT)
        CP    7              ;end of reg table?
        jp    z,INCSP1
        INC   A
        LD    (REGPNT),A
        RET
INCSP1  XOR   A
        LD   (REGPNT),A
        RET
;--------------------------
; display previous register
;--------------------------
DECSTP  CALL  BEEP
        LD    A,(REGPNT)
        CP    0              ;start of reg table?
        JP    Z,DECSP1
        DEC   A
        LD    (REGPNT),A
        RET
DECSP1  LD    A,7
        LD    (REGPNT),A
        RET
;-----------------
; display register
;-----------------
SETREG  LD    A,(REGPNT)
        LD    HL,TMPPC       ;start of table
        CALL  INDEXW         ;get element address
        LD    E,(HL)
        INC   HL
        LD    D,(HL)
        EX    DE,HL          ;load register contents
        CALL  DISADD
;
; display register name
;
        LD    HL,REGNAM
        CALL  INDEXW
        LD    A,(HL)
        LD    (DISBUF+0),A
        INC   HL
        LD    A,(HL)
        LD    (DISBUF+1),A
        RET
;------------------
; function key menu
;------------------
; when the Fn key is pressed, Fn is displayed in the
; data displays, the current address remains in the
; address displays. The program then waits for a
; keypress which will select 1 of 16 routines.
;
FUNKEY  CALL  AUTRST
        CALL  BEEP
FUNKY1  LD    HL,(ADRESS)
        CALL  DISADD          ;disp addr to remove dp's
        LD    HL,7154H        ;Fn
        LD    (DISBUF),HL     ;display Fn
        CALL  SKEYRL         ;wait for key release
FUNKY2  CALL  SKEYIN
        LD    HL,(FUNTBL)    ;use the menu handler
        CALL  MENU           ;routine for each key
;
; return to main
;
CANCEL  CALL  BEEP
CANCL1  CALL  UPDATE         ;update display buffer
        CALL  SKEYRL         ;wait for key release
        RET
;
; function menu key table
;
FUNLST  .DB 11H
        .DB 00H,01H,02H,03H,04H,05H,06H,07H
        .DB 08H,09H,0AH,0BH,0CH,0DH,0EH,0FH
        .DB 10H ;FN KEY
        .DW GOEXEC,INTELFN,ADDRA,ADDRB
        .DW BLKMVE,BLKSUM,BRANCH,TRACE
        .DW PLAY1,PLAY2,PLAY3,SWBEEP
        .DW SECRET,RELSQR,SCOPE,TIME
        .DW FUNFUN
;-----------------------
; call function function
;-----------------------
FUNFUN  LD    HL,(FUNJMP)
        JP    (HL)
;------------------------------------------
; function 0 - execute from current address
;------------------------------------------
GOEXEC  CALL  BEEP
        CALL  KEYREL
;   POP HL  ;remove exec return
        LD    HL,(ADRESS)
        JP    (HL)           ;start execuction
;------------------------------------
; function 1 receive intel hex format
;------------------------------------
INTELFN CALL  BEEP
        CALL  KEYREL
        CALL  INTELH
        JP    NZ,BLKMV1      ;show the error
        JP    CANCEL         ;just return if all ok
;--------------------------
; INTEL hex file downloader
;--------------------------
INTELH  XOR   A              ;clear
        LD    C,A            ;calculated checksum
;
; wait for the record mark ':'
;
WMARK   CALL  RXDATA         ;wait for the record mark
        CP    ':'            ;to be transmitted
        JR    NZ,WMARK
;
; get the record length
;
        CALL  GETBYT
        LD    B,A            ;the number of data bytes
;
; get the address
;
        CALL  GETBYT
        LD    H,A            ;the address high byte
        CALL  GETBYT
        LD    L,A            ;the address low byte
;
; get the record type
;
        CALL  GETBYT
        JR    NZ,CKSUM       ;end of file record
;
; C=checksum
; B=number of data bytes
; HL=destination address
;
LBYTES  CALL  GETBYT         ;get the record bytes
        LD    (HL),A         ;and save to RAM
        INC   HL             ;until there are
        DJNZ  LBYTES         ;no more
        CALL  CKSUM          ;checksum ok?
        JR    Z,INTELH       ;checksum ok, get next record
        RET                  ;checksum error a>0
;
; the sum of all the bytes (except record mark )
; including the checksum equals zero
;
CKSUM   CALL  GETBYT
        LD    A,C
        OR    00H            ;checksum ok  a=0
        RET
;
; get and convert two characters to byte
;
GETBYT  CALL  RXDATA         ;get the high nibble
        BIT   6,A            ;convert ASCII A-F
        JR    Z,GETBYT1      ;into lower
        ADD   A,09H          ;nibble hex
GETBYT1 AND   0FH
        SLA   A
        SLA   A
        SLA   A
        SLA   A
        LD    D,A
        CALL  RXDATA         ;get the low nibble
        BIT   6,A            ;convert ascii a-f
        JR    Z,GETBYT2      ;into lower
        ADD   A,09H          ;nibble hex
GETBYT2 AND   0FH
        OR    D              ;make a byte
        PUSH  AF
        ADD   A,C            ;add to
        LD    C,A            ;the checksum
        POP   AF             ;and return the received byte
        RET
;-------------------------------
; CONVERT ASCII CHARACTER TO HEX
;-------------------------------
; converts ascii 0-9,a-f into hex lsn
;  entry : a= ascii 0-9,a-f
;  exit  : a= hex 0-f in lsn
;  a and f registers modified
;
ASCHEX  BIT   6,A
        JR    Z,ASCHX1
        ADD   A,09H
ASCHX1  AND   0FH
        RET
;------------------------------------
; BIT BANG SERIAL PORT INITIALISATION
;------------------------------------
; set the serial transmit pin high so the 
; host can see that we are preparing to transmit
; 
; entry : HL = baud rate
;         HL = 0 use existing baud constant
; exit  : HL preserved
;       ; AF modified
;
SERINI  LD    A,40H
        OUT   (SCAN),A       ;turn off the display make serial tx high
        LD    B,50
        CALL  MSDELAY        ;wait so the host sees tx high
        LD    A,H
        OR    L
        RET   Z              ;hl is zero don't update the baud rate
        LD   (BAUD),HL       ;update the baud rate
        RET 
;------------------
; MILLISECOND DELAY
;------------------
; approx. 1 millisecond delay
; 
; entry : B = 1 to 255 milliseconds
; exit  : B = 0
;
MSDELAY PUSH  BC             ;11T
        LD    B,233          ;7T
MSDEL1  NOP                  ;4T
        DJNZ  MSDEL1         ;NZ=13T,Z=8T
        POP   BC             ;10T
        DJNZ  MSDELAY        ;NZ=13T,Z=8T
        RET                  ;10T
;------------------------
; SERIAL TRANSMIT ROUTINE
;------------------------
; transmit byte serially on DOUT
;
; entry : ACC = byte to transmit
;  exit : no registers modified
;
TXDATA  PUSH  AF
        PUSH  BC
        PUSH  HL
        LD    HL,(BAUD)
        LD    C,A
;
; transmit start bit
;
        XOR   A
        OUT   (SCAN),A
        CALL  BITIME
;
; transmit data
;
        LD    B,08H
        RRC   C
NXTBIT  RRC   C              ;shift bits to D6,
        LD    A,C            ;lsb first and output
        AND   40H            ;them for one bit time.
        OUT   (SCAN),A
        CALL  BITIME
        DJNZ  NXTBIT
;
; send stop bits
;
        LD    A,40H
        OUT   (SCAN),A       ;make D6 high
        CALL  BITIME         ;transmit
        CALL  BITIME         ;two stop bits
        POP   HL
        POP   BC
        POP   AF
        RET
;-----------------------
; SERIAL RECEIVE ROUTINE
;-----------------------
; receive serial byte from DIN
;
; entry : none
;  exit : ACC= received byte if carry clear
;
; registers modified ACC and F
;
RXDATA  PUSH  BC
        PUSH  HL
;
; wait for start bit
;
RXDAT1  IN    A,(KEYBUF)
        BIT   7,A
        JR    NZ,RXDAT1      ;no start bit
;
; detected start bit
;
        LD    HL,(BAUD)
        SRL   H
        RR    L              ;delay for half bit time
        CALL  BITIME
        IN    A,(KEYBUF)
        BIT   7,A
        JR    NZ,RXDAT1      ;start bit not valid
;
; detected valid start bit,read in data
;
        LD    B,08H
RXDAT2  LD    HL,(BAUD)
        CALL  BITIME         ;delay one bit time
        IN    A,(KEYBUF)
        RL    A
        RR    C              ;shift bit into data reg
        DJNZ  RXDAT2
        LD    A,C
        OR    A              ;clear carry flag
        POP   HL
        POP   BC
        RET
;---------------
; BIT TIME DELAY
;---------------
; delay for one serial bit time
;  entry : HL = delay time
; no registers modified
;
BITIME  PUSH  HL
        PUSH  DE
        LD    DE,0001H
BITIM1  SBC   HL,DE
        JP    NC,BITIM1
        POP   DE
        POP   HL
        RET
;-----------------------------
; FUNCTION 2 - ENTER ADDRESS 1
;-----------------------------
ADDRA   CALL  BEEP
        LD    HL,(ADRESS)    ;copy current
        LD    (BLKSRT),HL    ;address as start
        LD    HL,3900H       ;address [
        CALL  SDELAY
        JP    CANCL1
;-----------------------------
; FUNCTION 3 - ENTER ADDRESS 2
;-----------------------------
ADDRB   CALL  BEEP
        LD    HL,(ADRESS)    ;copy current
        LD    (BLKEND),HL    ;address as end
        LD    HL,000FH       ;address ]
        CALL  SDELAY
        JP    CANCL1
;------------------------
; FUNCTION 4 - BLOCK MOVE
;------------------------
BLKMVE  CALL  BEEP
        LD    HL,(ADRESS)    ;COPY CURRENT
        LD    (BLKDST),HL    ;ADDRESS AS
        LD    HL,390FH       ;DESTINATION
        CALL  SDELAY
;
; calculate number of bytes to move
;
        LD    HL,(BLKEND)
        LD    DE,(BLKSRT)
        AND   A
        SBC   HL,DE
        INC   HL             ;make move inclusive
        LD    (COUNT),HL
        JR    NC,BLKMV3      ;if ok move block
;
; show error
;
BLKMV1  LD    HL,0079H       ;show error e
BLKMV2  CALL  BEEP
        LD    (DISBUF),HL    ;and wait
        CALL  SKEYIN         ;for keypress
        CALL  BEEP
        CALL  SKEYRL
        JP    CANCL1
;
; move block
;
BLKMV3  CALL  MOVE
        JP    CANCL1
;-----------
; BLOCK MOVE
;-----------
MOVE    LD    BC,(COUNT)
        LD    HL,(BLKSRT)    ;start addr
        LD    DE,(BLKDST)    ;destination addr
        LDIR
        RET
;-------------------------------
; SCAN DISPLAY UNTIL KEY RELEASE
;-------------------------------
SDELAY  LD    (DISBUF),HL    ;show HL
        LD    B,255          ;in data displays
SDELY1  CALL  SCAND          ;until key
        DJNZ  SDELY1         ;is released
        CALL  SKEYRL
        RET
;---------------------------
;FUNCTION 5 - BLOCK CHECKSUM
;---------------------------
BLKSUM  CALL  BEEP
        LD    HL,396DH       ;cs
        CALL  SDELAY         ;show prompt
        LD    DE,(BLKSRT)
        LD    HL,(BLKEND)
        AND   A
        SBC   HL,DE
        INC   HL             ;make checksum inclusive
        LD    (COUNT),HL
        JR    NC,BLKSM1      ;if ok sum block
;
; show error
;
        JP    BLKMV1
;
; calculate checksum
;
BLKSM1  LD    HL,(BLKSRT)
        LD    DE,(BLKEND)
        CALL  CHKSUM         ;do the checksum,
        CALL  DISBYT         ;display
        LD    HL,(COUNT)     ;number of bytes
        CALL  DISADD         ;summed and
        CALL  BEEP
        CALL  SKEYIN         ;checksum until
        CALL  BEEP           ;a key is pressed
        CALL  SKEYRL
        JP    CANCL1
;----------------------------------------
; FUNCTION 6 - RELATIVE BRANCH CALCULATOR
;----------------------------------------
BRANCH  CALL  BEEP
        LD    HL,507CH       ;'rb'
        CALL  SDELAY
        LD    HL,(ADRESS)    ;get current address
        LD    DE,(BLKSRT)
        INC   DE             ;point to PC+2
        AND   A
        SBC   HL,DE          ;subtract
;
; test high byte of result to
; determine if backward branch
;
        LD    A,H
        CP    255            ;backward branch?
        JP    NZ,BRNCH1      ;check if forward
;
; check if we have branched beyond -128
;
        LD    A,L
        BIT   7,A
        JR    NZ,BRNCH2      ;branch is within limits
        JP    BLKMV1         ;too far back
;
; test high byte of result to
; determine if forward branch
;
BRNCH1  CP    0              ;forward branch?
        JP    NZ,BLKMV1      ;too far in any direction
;
; check if we have branched beyond +128
;
        LD    A,L
        BIT   7,A
        JP    NZ,BLKMV1      ;too far forward
;
; within limits, put in RAM
; and show as current address
;
BRNCH2  LD    HL,(BLKSRT)
        LD    (ADRESS),HL
        LD    (HL),A
        JP    CANCL1
;-----------------------------------------
; FUNCTION 7 - TOGGLE HARDWARE SINGLE STEP
;-----------------------------------------
TRACE   CALL  BEEP
;
; toggle IO7 for the original single-stepper
;
        OUT   (IO7),A        ;toggle hardware latch
;
; toggle the refresh register bit 7
;
        LD    A,R
        BIT   7,A
        JR    Z,TRACE1       ;single step is off turn on
        XOR   A
        LD    R,A            ;turn off single stepper
        LD    HL,703FH       ;show 'T0' off
        JP    TRACE2
TRACE1
        LD    A,80H
        LD    R,A            ;turn on single stepper
        LD    HL,7006H       ;show 'T1'on
TRACE2  CALL  SDELAY
        JP    CANCL1
;-------------------------
; FUNCTION 8 - PLAY TUNE 1
;-------------------------
PLAY1   CALL  BEEP
        CALL  KEYREL
        LD    HL,TUNE1
        CALL  MUSIC
        JP    CANCL1
;-------------------------
; FUNCTION 9 - PLAY TUNE 2
;-------------------------
PLAY2   CALL  BEEP
        CALL  KEYREL
        LD    HL,TUNE2
        CALL  MUSIC
        JP    CANCL1
;------------------------------
; FUNCTION A - PLAY TUNE IN RAM
;------------------------------
PLAY3   CALL  BEEP
        CALL  KEYREL
        LD    HL,(ADRESS)
        CALL  MUSIC
        JP    CANCL1
;-----------------------------
; FUNCTION B - TOGGLE KEY BEEP
;-----------------------------
SWBEEP  CALL  BEEP
        LD    A,(MODE)
        XOR   40H
        LD    (MODE),A
        JP    CANCL1
;
; TUNE 1
; from Talking Electronics TEC-1 MONITOR, 
; MON-1 by John Hardy and Ken Stone
;
TUNE1   .DB 06H,06H,0AH,0DH,06H,0DH,0AH,0DH
        .DB 12H,16H,14H,12H,0FH,11H,12H,0FH
        .DB 0DH,0DH,0DH,0AH,12H,0FH,0DH,0AH
        .DB 08H,06H,08H,0AH,0FH,0AH,0DH,0FH
        .DB 06H,06H,0AH,0DH,06H,0DH,0AH,0DH
        .DB 12H,16H,14H,12H,0FH,11H,12H,0FH
        .DB 0DH,0DH,0DH,0AH,12H,0FH,0DH,0AH
        .DB 08H,06H,08H,0AH,06H,12H,00H,1EH
;
; TUNE 2
; from Talking Electronics TEC-1 monitor, 
; MON-1 by John Hardy and Ken Stone
;
TUNE2   .DB 0BH,0AH,08H,0AH,0AH,0AH,06H,06H
        .DB 06H,0BH,0AH,08H,0AH,0AH,0AH,0AH
        .DB 0AH,0AH,0BH,0AH,08H,0AH,0AH,0AH
        .DB 06H,06H,06H,0AH,08H,0AH,0DH,0DH
        .DB 0DH,0DH,0DH,00H,0DH,05H,08H,0BH
        .DB 0BH,0BH,06H,06H,06H,0BH,0AH,08H
        .DB 0AH,0AH,0AH,06H,06H,06H,0BH,0AH
        .DB 06H,08H,08H,08H,08H,08H,0AH,0BH
        .DB 0AH,08H,06H,06H,06H,06H,06H,06H
        .DB 00H,00H,00H,1EH
;---------------------------
; FUNCTION C - SECRET NUMBER
;---------------------------
SECRET  CALL  BEEP           ;wait for key release
        CALL  KEYREL         ;and clear display buffer
        CALL  CLRBUF
        LD    IX,VARIDX      ;use ix for local variables
;
; separate nibbles in random number
;
        CALL  RAND
        LD    (IX+11),L
        LD    (IX+12),H      ;random number
        LD    A,(IX+11)      ;separate the random
        CALL  SPLIT          ;number into
        LD    (IX+4),L       ;four nibbles
        LD    (IX+5),H       ;to make checking
        LD    A,(IX+12)      ;against the
        CALL  SPLIT          ;guess easier
        LD    (IX+6),L
        LD    (IX+7),H
        XOR   A
        LD    I,A            ;clear number of tries
        LD    HL,0
        LD    (IX+8),L
        LD    (IX+9),H
        CALL  DISADD         ;and display guess
;
; scan the keyboard
;
SECRT1  CALL  SKEYIN         ;wait for key
        LD    HL,SECNUM
        CALL  MENU           ;execute key handler
        CALL  SKEYRL         ;wait for key release
        JP    SECRT1
;
; secret number key table
;
SECNUM  .DB 12H
        .DB 00H,01H,02H,03H,04H,05H,06H,07H
        .DB 08H,09H,0AH,0BH,0CH,0DH,0EH,0FH
        .DB 10H,11H
        .DW EDTKEY,EDTKEY,EDTKEY,EDTKEY
        .DW EDTKEY,EDTKEY,EDTKEY,EDTKEY
        .DW EDTKEY,EDTKEY,EDTKEY,EDTKEY
        .DW EDTKEY,EDTKEY,EDTKEY,EDTKEY
        .DW ENDKEY,CHKKEY
;
; edit guess key
;
EDTKEY  PUSH  AF
        LD    L,(IX+8)
        LD    H,(IX+9)       ;get current guess
        SLA   L
        RL    H              ;and do a 16 bit
        SLA   L              ;left shift 4 times
        RL    H              ;to make room
        SLA   L              ;for the new key
        RL    H
        SLA   L
        RL    H
        POP   AF
        OR    L              ;it in the least
        LD    L,A            ;significant nibble
        LD    (IX+8),L
        LD    (IX+9),H       ;save guess
        CALL  DISADD
        CALL  BEEP
        RET
;
; quit game
;
ENDKEY  CALL  BEEP           ;wait for key release
        CALL  KEYREL         ;and return to
        JP    MAIN           ;monitor
;
; see if its the right guess
;
CHKKEY  CALL  BEEP
        LD    A,I
        INC   A
        DAA                  ;inc bcd No. of tries
;
; briefly show guess No.
;
        LD    I,A
        CALL  DISBYT
        LD    B,255
CHKKY1  CALL  SCAND
        DJNZ  CHKKY1
;
; separate guess into nibbles
;
        LD    A,(IX+8)       ;get current guess
        CALL  SPLIT          ;number into
        LD    (IX+0),L       ;four nibbles
        LD    (IX+1),H       ;to make checking
        LD    A,(IX+9)       ;against the
        CALL  SPLIT          ;guess easier
        LD    (IX+2),L
        LD    (IX+3),H
;
; check for correct number,correct spot
;
        XOR   A
        LD    (IX+10),A      ;clear result
        LD    HL,VARIDX+4    ;point to random
        LD    DE,VARIDX      ;point to guess
        LD    B,4            ;number of digits
CHKKY2  LD    A,(HL)         ;get random
        EX    DE,HL
        CP    (HL)           ;same as guess?
        JR    NZ,CHKKY4      ;not same
        LD    A,(IX+10)
        ADD   A,10H          ;right position
        LD    (IX+10),A
CHKKY3  INC   HL             ;point to next
        EX    DE,HL          ;digit position
        INC   HL             ;and go
        DJNZ  CHKKY2         ;check other positions
        JP    CHKKY8
;
; check if number is there
;
CHKKY4  PUSH  BC
        PUSH  HL
        LD    B,4            ;check each digit
        LD    HL,VARIDX      ;to see if this
CHKKY5  CP    (HL)           ;number is in
        INC   HL             ;the wrong
        JR    NZ,CHKKY6      ;position
        LD    A,(IX+10)      ;and update
        INC   A              ;the result
        LD    (IX+10),A
        JP    CHKKY7
CHKKY6  DJNZ  CHKKY5
CHKKY7  POP   HL
        POP   BC
        JP    CHKKY3         ;check next digit
;
; check if correct
;
CHKKY8  LD    A,(IX+10)
        CP    40H            ;is it correct?
        JP    Z,CHKKY9       ;yes!
        LD    A,(IX+10)      ;not correct
        CALL  DISBYT         ;in data displays
        LD    A,I            ;was that the
        CP    20H            ;last guess?
        RET   NZ             ;no try again
;
; ran out of trys
;
        CALL  CLRBUF         ;display
        LD    L,(IX+11)
        LD    H,(IX+12)      ;the random number
        CALL  DISADD         ;and play
        LD    HL,LOSE        ;the lose
        JP    CHKKYA         ;music
;
; got the right answer
;
CHKKY9  LD    A,I            ;display how many
        CALL  DISBYT         ;and play the win
        LD    L,(IX+11)
        LD    H,(IX+12)
        LD    HL,WIN         ;music
;
; play music and wait for any key to restart
;
CHKKYA  CALL  MUSIC          ;play the music
        CALL  SKEYIN         ;wait for a key
        CALL  BEEP
        CALL  SKEYRL         ;wait for key release
        POP   HL             ;and restart the game
        JP    SECRET
;
; win and lose music
; from talking electronics TEC-1 monitor,
; MON-1 by John Hardy and Ken Stone
;
WIN     .DB 14H,12H,14H,17H,17H,12H,14H,10H,1FH
LOSE    .DB 01H,11H,01H,11H,01H,11H,1FH
;-------------------------------
; SEPARATE BYTE INTO TWO NIBBLES
;-------------------------------
; separates a byte into two
; right justified nibbles
; entry : ACC = byte to be separated
; exit  : H = MSN
;         L = LSN
;
SPLIT   PUSH  AF
        PUSH  BC
        LD    B,A            ;save byte
        AND   0FH            ;strip bits LSN
        LD    L,A            ;return LSN in L
        LD    A,B
        SRL   A
        SRL   A
        SRL   A              ;move MSN
        SRL   A              ;into LSN
        LD    H,A            ;return MSN in H
        POP   BC
        POP   AF
        RET
;-----------------------------------
; FUNCTION D - RELAY BOARD SEQUENCER
;-----------------------------------
RELSQR  CALL  BEEP
        CALL  KEYREL
        LD    HL,RLTEST      ;point to test sequence
        CALL  RLSTEP
        JP    CANCL1
;
; test sequence
;
RLTEST  .DB 55H,01H,0AAH,01H,00H,0FFH
;----------------
; RELAY SEQUENCER
;----------------
; sequences relays on relay board
; uses two bytes to specify output data and delay time
; delay time byte also determines if sequence is to stop
; or repeat.
;  table:
;  <byte1>,<byte2>
;  byte1 = data to go to output latch (uses port IO1)
;  byte2 = FF - repeat
;          00 - finished
;  entry : HL points to table of output data
;  exit : none modified
;
RLSTEP  PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL             ;save registers
        PUSH  HL
        EX    DE,HL          ;get address of data
;
RELSR1  LD    A,(DE)
        LD    C,A            ;get output data
        INC   DE
        LD    A,(DE)         ;get time delay
        CP    0
        JR    Z,RELSR4       ;end of sequence
        CP    255
        JR    Z,RELSR3       ;repeat sequence
        LD    B,A
        LD    A,C
        OUT   (IO1),A
        INC   DE
RELSR2  CALL  DELONE         ;1 sec delay
        DJNZ  RELSR2         ;more seconds to go
        JP    RELSR1
;
; repeat
;
RELSR3  POP   DE             ;get start address
        PUSH  DE             ;save for later
        JP    RELSR1
;
; finished
;
RELSR4  XOR   A
        OUT   (IO1),A        ;clear output reg
        POP   HL
        POP   HL
        POP   DE
        POP   BC
        POP   AF
        RET
;-----------------
; ONE SECOND DELAY
;-----------------
;
; entry : none
; exit : flag register modified
;
DELONE  PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    DE,0001H
        LD    HL,0870H
DELON1  LD    B,92H
DELON2  DJNZ  DELON2         ;inner loop
        SBC   HL,DE
        JP    NC,DELON1      ;outer loop
        POP   HL
        POP   DE
        POP   BC
        RET
;--------------------------
; FUNCTION E - KALEIDOSCOPE
;--------------------------
SCOPE   CALL  BEEP
        CALL  KEYREL
        CALL  RAND           ;generate random
        EX    DE,HL
        LD    HL,BUFFER      ;number and set up
        LD    A,E            ;the first quadrant
        CALL  SEED           ;with a random bit
        LD    A,D            ;pattern
        CALL  SEED
;
; generate mirror images
;
SCOPE2  LD    B,04H
        LD    HL,BUFFER
        LD    DE,BUFFER+7
SCOPE3  LD    A,(HL)         ;mirror the first
        LD    (DE),A         ;quadrant into
        INC   HL             ;the fourth
        DEC   DE             ;quadrant
        DJNZ  SCOPE3
;
; mirror across centre of display
;
        LD    B,8            ;mirror the first
        LD    HL,BUFFER      ;and fourth quadrant
        LD    A,(HL)         ;across the centre
        AND   0FH            ;of the display
        LD    (HL),A         ;into the second
SCOPE4  BIT   0,(HL)         ;and third quadrants.
        JP    Z,SCOPE5       ;checking if the
        SET   7,(HL)         ;bits in the LSN are
SCOPE5  BIT   1,(HL)         ;set, and setting the
        JP    Z,SCOPE6       ;corresponding
        SET   6,(HL)         ;mirror image
SCOPE6  BIT   2,(HL)         ;bit in the MSN
        JP    Z,SCOPE7       ;if they are.
        SET   5,(HL)         ;do this for
SCOPE7  BIT   3,(HL)         ;the eight rows
        JP    Z,SCOPE8       ;of data bytes
        SET   4,(HL)         ;in the display
SCOPE8  INC   HL
        DJNZ  SCOPE4         ;more rows to do
;
; display the pattern
;
        LD    DE,0001H       ;show the pattern
        LD    HL,0200H       ;for a period of time
SCOPE9  PUSH  HL
        LD    HL,BUFFER
        CALL  SKATE          ;scan 8x8
        POP   HL
        SBC   HL,DE
        JP    NZ,SCOPE9
;
; manipulate bits for next image
;
SCOPEA  LD    HL,BUFFER
        LD    A,5
        ADD   A,(HL)
        AND   0FH
        LD    (HL),A         ;add 5 to first LSN
        INC   HL
        LD    A,03H
        ADD   A,(HL)
        AND   0FH
        LD    (HL),A         ;add 3 to second LSN
        INC   HL
        LD    A,01H
        ADD   A,(HL)
        AND   0FH
        LD    (HL),A         ;add 1 to third LSN
        INC   HL
        LD    A,07H
        ADD   A,(HL)
        AND   0FH
        LD    (HL),A         ;add 15 to fourth LSN
        JP    SCOPE2         ;mirror bit pattern
;
; seed the first quadrant with random bits
;
SEED    LD    B,A            ;put the
        AND   0FH            ;random number
        LD    (HL),A         ;into the
        INC   HL             ;first quadrant
        LD    A,B            ;of the
        AND   240            ;display
        RRA
        RRA
        RRA
        RRA
        LD    (HL),A
        INC   HL
        RET
;-----------------
; SCAN 8X8 DISPLAY
;-----------------
; put the 8 RAM locations pointed to
; by HL on the 8x8 display,
; low byte on top row.
; routine period is 500us
; pulse width 15us  gives 3% duty
;
;  entry : HL = address of 8x8 buffer
;   exit : no registers modified
;
SKATE   PUSH  AF
        PUSH  BC
        PUSH  HL             ;save registers
        LD    C,80H
SKATE1  LD    A,(HL)
        OUT   (IO0),A        ;output X
        LD    A,C
        OUT   (IO2),A        ;output Y
        LD    B,02H
SKATE2  DJNZ  SKATE2         ;on time delay
        XOR   A
        OUT   (IO0),A
        OUT   (IO2),A        ;clear display latches
        LD    B,08H
SKATE3  DJNZ  SKATE3         ;off time delay
        INC   HL
        RRC   C
        JR    NC,SKATE1      ;more to output
        POP   HL
        POP   BC
        POP   AF
        RET
;----------------------------
; FUNCTION F - CLOCK CALENDAR
;----------------------------
TIME    CALL  BEEP
        CALL  KEYREL         ;wait for key release
        LD    IX,VARIDX      ;use IX for temp variables
        LD    A,(ONTIM)
        LD    (IX+0),A       ;save display scan delay
        LD    A,60H
        LD    (ONTIM),A      ;use new delay
        LD    (IX+1),A       ;start in time mode
;
; display time,check for key
;
TIME1   CALL  RWATCH         ;read the clock/calendar
        CALL  UPDBUF         ;update the display buffer
        CALL  SCAND
        CALL  SCANKEY
        BIT   5,A
        JR    Z,TIME1        ;no key keep looking
        AND   1FH
        LD    HL,TIMKEY
        CALL  MENU
        JR    TIME1
;
; clock menu
;
TIMKEY  .DB   4
        .DB   10H,11H,12H,13H
        .DW   CLKEXT,SETCLK,CALKEY,CALKEY
;
; exit clock calendar
;
CLKEXT  POP   HL             ;remove return
        LD    A,(IX+0)
        LD    (ONTIM),A      ;restore delay time
        JP    CANCEL
;
; toggle display mode
;
CALKEY  CALL  BEEP
        CALL  KEYREL
        LD    A,(IX+1)
        XOR   80H              ;toggle display
        LD    (IX+1),A
        RET
;----------------------
; UPDATE DISPLAY BUFFER
;----------------------
UPDBUF  BIT   7,(IX+1)       ;which display mode?
        JR    NZ,UPDBF2      ;calendar display
;
; time display
;
UPDBF1  LD    A,(SWREG1)
        CALL  CONBYT
        SET   7,L            ;set decimal point
        LD    (DISBUF),HL    ;show seconds (0-59)
        LD    A,(SWREG2)
        CALL  CONBYT
        SET   7,L            ;set decimal point
        LD    (DISBUF+2),HL  ;show minutes (0-59)
        LD    A,(SWREG3)
        CALL  CONBYT
        SET   7,L            ;set decimal point
        LD    (DISBUF+4),HL  ;show hours (0-23)
        RET
;
; calendar display
;
UPDBF2  LD    A,(SWREG7)
        CALL  CONBYT
        LD    (DISBUF),HL    ;show year (0-99)
;
; check mode for dd/mm/yy or mm/dd/yy
;
        LD    HL,CALMDE
        BIT   7,(HL)
        JR    NZ,UPDBF3      ;mm/dd/yy mode
;
; dd/mm/yy mode
;
        LD    A,(SWREG6)
        CALL  CONBYT
        LD    (DISBUF+2),HL  ;show month (1-12)
        LD    A,(SWREG5)
        CALL  CONBYT
        LD    (DISBUF+4),HL  ;show date (1-31)
        JR    UPDBF4
;
; mm/dd/yy mode
;
UPDBF3  LD    A,(SWREG6)
        CALL  CONBYT
        LD    (DISBUF+4),HL  ;show month (1-12)
        LD    A,(SWREG5)
        CALL  CONBYT
        LD    (DISBUF+2),HL  ;show date (1-31)
;
; show day
;
UPDBF4  LD    A,(SWREG4)     ;get day reg
        AND   07H
        JR    Z,UPDBF5       ;zero is illegal
        CP    07H
        JR    Z,UPDBF5       ;don't show saturday
        CPL                  ;work out
        SUB   01H            ;which decimal point
        AND   07H            ;to light
        LD    HL,DISBUF      ;adding the day
        LD    B,00H          ;to a display
        LD    C,A            ;buffer index
        ADD   HL,BC          ;and setting the
        SET   7,(HL)         ;decimal point
UPDBF5  RET                  ;in that display
;--------------
; SET TIME/DATE
;--------------
SETCLK  CALL  BEEP
        CALL  KEYREL
;
; edit the display buffer
;
SETCK1  CALL  UPDBUF         ;update display buffer
        CALL  SKEYIN
        CALL  KEYREL
        CP    10H            ;Fn key exits (no change)
        RET Z
        CP    11H            ;Ad key sets clock/calendar
        JR    Z,SETCK8
        CP    12H
        JR    Z,SETCK4       ;plus key
        CP    13H
        JR    Z,SETCK6       ;minus key
        CP    0AH            ;no A-F keys
        JR    NC,SETCK1
;
; is it set clock or set calendar?
;
        BIT   7,(IX+1)
        JR    NZ,SETCK2
;
; set clock display
;
        LD    HL,SWREG1
        RLD                   ;move the new key
        INC   HL              ;into the clock buffer
        RLD
        INC   HL
        RLD
        JR    SETCK1
;
; set calendar display
;
SETCK2  LD    HL,CALMDE
        BIT   7,(HL)
        JR    NZ,SETCK3      ;mm/dd/yy mode
;
; set calendar as dd/mm/yy
;
        LD    HL,SWREG7
        RLD                  ;move the new key
        DEC HL               ;into the cal buffer
        RLD
        DEC HL
        RLD
        JR  SETCK1
;
; set calendar as mm/dd/yy
;
SETCK3  LD    HL,SWREG7
        RLD                  ;move the new key
        DEC   HL             ;into the cal buffer
        DEC   HL
        RLD
        INC   HL
        RLD
        JR    SETCK1
;
; inc day
;
SETCK4  BIT   7,(IX+1)
        JR    Z,SETCK1
        LD    A,(SWREG4)
        CP    07H            ;is the day sunday?
        JR    NZ,SETCK5
        XOR   A              ;set monday
SETCK5  INC   A              ;day=day+1
        LD    (SWREG4),A
        JP    SETCK1
;
; dec day
;
SETCK6  BIT   7,(IX+1)
        JP    Z,SETCK1
        LD    A,(SWREG4)
        CP    01H            ;is the day monday?
        JR    NZ,SETCK7
        LD    A,08H          ;set sunday
SETCK7  DEC   A              ;day=day-1
        LD    (SWREG4),A
        JP    SETCK1
;
; set the clock/calendar with new data
;
SETCK8  CALL  BEEP
        CALL  KEYREL
        LD    A,(SWREG3)
        AND   3FH            ;24 hour mode
        LD    (SWREG3),A
        LD    A,(SWREG4)
        AND   07H            ;osc on,rst enabled
        LD    (SWREG4),A
        CALL  WWATCH         ;write changes
        RET
;---------------------
; READ FROM SMARTWATCH
;---------------------
; reads data from smartwatch, uses lookup table to
; write 64 bit access code to enable the smartwatch.
; reads all data into registers as ram cannot be read
; or written to while watch is enabled.
;
;  entry : none
;  exit  : no working registers modified
;          (alternate set modified)
;  contents of smartwatch written to swreg0 - swreg7
;
;
; enable smartwatch
;
RWATCH  PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    A,(SWATCH)     ;initiate pattern
        LD    HL,PATERN      ;write d0 of all the bytes
        LD    B,64           ;in the table to the ram to
RWACH1  LD    A,(HL)         ;enable the smartwatch
        LD    (SWATCH),A
        INC   HL
        DJNZ  RWACH1
;
; read data from watch
;
        LD    B,32
RWACH2  LD    A,(SWATCH)     ;shift the first 32 bits
        SRL   A              ;into the 16 bit registers
        RR    D              ;de and hl
        RR    E              ;then exchange them with
        RR    H              ;the alternate pair
        RR    L
        DJNZ  RWACH2
        EXX
        LD    B,32
RWACH3  LD    A,(SWATCH)     ;now shift the last 32 bits
        SRL   A              ;into the same 16 bit registers
        RR    D
        RR    E
        RR    H
        RR    L
        DJNZ  RWACH3
;
; save in watch registers
;
        LD    (SWREG4),HL    ;smartwatch read is complete
        LD    (SWREG6),DE    ;get the data
        EXX
        LD    (SWREG0),HL
        LD    (SWREG2),DE
        POP HL
        POP DE
        POP BC
        POP AF
        RET
;
; smartwatch access pattern
;
PATERN  .DB 0C5H,0E2H,71H,0B8H,5CH,2EH,17H,8BH
        .DB 3AH,1DH,8EH,47H,0A3H,0D1H,0E8H,74H
        .DB 0A3H,0D1H,0E8H,74H,3AH,1DH,8EH,47H
        .DB 5CH,2EH,17H,8BH,0C5H,0E2H,71H,0B8H
        .DB 0C5H,0E2H,71H,0B8H,5CH,2EH,17H,8BH
        .DB 3AH,1DH,8EH,47H,0A3H,0D1H,0E8H,74H
        .DB 0A3H,0D1H,0E8H,74H,3AH,1DH,8EH,47H
        .DB 5CH,2EH,17H,8BH,0C5H,0E2H,71H,0B8H
;--------------------
; WRITE TO SMARTWATCH
;--------------------
;
; write data to smartwatch by first accessing
; it using bit manipulation.
; data is written by firstly putting all 64 bits
; into registers as ram cannot be accessed once the
; smartwatch is enabled.
;
; entry : none
; the data to write to the smartwatch
; must be in swreg0 - swreg7
;  exit : no working registers modified
; (alternate set modified)
; get data to write to watch
;
WWATCH  PUSH  AF
        PUSH  BC
        PUSH  DE
        PUSH  HL
        LD    HL,(SWREG4)    ;set up the
        LD    DE,(SWREG6)    ;16 bit registers
        EXX
        LD    HL,(SWREG0)    ;with the data to be
        LD    DE,(SWREG2)    ;written to the smartwatch
;
; write 64 bit access code to enable smartwatch
;
        LD    A,(SWATCH)     ;initiate pattern
        LD    A,0C5H
        LD    C,80H          ;number of bytes
WWACH1  LD    B,80H          ;number of bits
WWACH2  LD    (SWATCH),A     ;write to ram
        RRC   A
        SRL   B
        JR    NC,WWACH2      ;more bits
        SRL   C
        JR    C,WWACH4       ;no more bytes
        BIT   0,A
        JR    NZ,WWACH3
        RRC   A
        RRC   A
        RRC   A
        RRC   A
        JR    WWACH1
WWACH3  CPL
        JR    WWACH1
;
; write data to watch
;
WWACH4  LD    B,32           ;shift the first 32 bits
WWACH5  SRL   D              ;out of the 16 bit registers
        RR    E              ;onto D0 and into
        RR    H              ;the smartwatch
        RR    L
        RLA
        LD    (SWATCH),A
        DJNZ  WWACH5
        EXX                  ;restore registers
        LD    B,32           ;get the other 32 bits from
WWACH6  SRL   D              ;the alternate register set
        RR    E              ;and shift them onto D0
        RR    H              ;and into the smartwatch
        RR    L
        RLA
        LD    (SWATCH),A
        DJNZ  WWACH6
        POP HL
        POP DE
        POP BC
        POP AF
        RET
;-----------------
; ONE SECOND DELAY
;-----------------
; uses smartwatch to delay for 1 second
; by waiting for seconds register to rollover
;
; first read gets a reference, subsequent reads
; wait until the seconds counter no longer
; reads the same as the reference value,
; then the routine returns
;
; entry : none
; exit : none modified
;
ONESEC  PUSH  AF
        PUSH  BC
        CALL  RWATCH         ;read watch
        LD    A,(SWREG1)
        LD    B,A            ;save ref count
ONESC1  CALL  RWATCH
        LD    A,(SWREG1)
        CP    B              ;same as ref?
        JP    Z,ONESC1       ;yes, so wait again
        POP   BC
        POP   AF
        RET
;
;Serial Monitor
;
#include "SCBug.asm"
        .END
