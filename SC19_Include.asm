;--------------------------------------------
; S O U T H E R N   C R O S S   M O N I T O R
;--------------------------------------------
;
;  MONITOR HEADER FILE
;
;  #INCLUDE  "SC19_Include.asm"
;
; Written by Craig R. S. Jones
; Melbourne, Australia.
;
; VERSION     1.9  August 2026
;
;---------------
; RAM MEMORY MAP
;---------------
BOTRAM  .EQU  2000H          ;bottom of SRAM
TOPRAM  .EQU  3FFFH          ;top of SRAM
;
VARBLS  .EQU  TOPRAM-0FFH    ;monitor variables
BUFFER  .EQU  VARBLS-0100H   ;general purpose buffer area
ISTACK  .EQU  BUFFER-0200H   ;initial monitor stack
;
RAMEND  .EQU  ISTACK-0400H   ;end of user RAM
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
SPTEMP  .DS   2              ;temp system call sp
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
; B7 = Address= 0 / Data= 1  Mode
; B6 = Beep enabled= 1
; B5 = Auto-increment Data entry state
;
MODE    .DS   2              ;display mode
ADRESS  .DS   2              ;user address
KEYDEL  .DS   2              ;auto increment delay
;
; SINGLE STEPPER TEMPORARY REGISTER STORAGE
;
REGPNT  .DS   2   ;register pointer
TMPPC   .DS   2   ;program counter
TMPAF   .DS   2   ;accumulator,flag
TMPBC   .DS   2   ;bc register pair
TMPDE   .DS   2   ;de register pair
TMPHL   .DS   2   ;hl register pair
TMPIX   .DS   2   ;index register x
TMPIY   .DS   2   ;index register y
TMPSP   .DS   2   ;stack pointer
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
SWATCH  .DS   1   ;ram test location
SYSERR  .DS   2   ;system call error jump
;--------------------
; SYSTEM CALL NUMBERS
;--------------------
;
;  LD   C,SYSTEM CALL NUMBER
;  RST  30H
;
MAIN           .EQU  0       ;restart monitor
VERS           .EQU  1 ;return software version number
DISADD         .EQU  2 ;covert address to seven segment code in display buffer
DISBYT         .EQU  3 ;convert data to seven segment code in display buffer
CLRBUF         .EQU  4 ;clear the seven segment display buffer
SCAND          .EQU  5 ;scan the seven segment displays
CONBYT         .EQU  6 ;convert a byte into seven segment code
CONVHI         .EQU  7 ;convert the high nibble into seven segment code
;
CONVLO         .EQU  8 ;convert the low nibble into seven segment code
SKEYIN         .EQU  9 ;scan the display until key press
SKEYRL         .EQU  10 ;scan the display until key release
KEYIN          .EQU  11 ;wait for a key press
KEYREL         .EQU  12 ;wait for key release
MENU           .EQU  13 ;menu handler
CHKSUM         .EQU  14 ;calculate 8 bit checksum
MUL16          .EQU  15 ;16 bit multiply
;
RAND           .EQU  16 ;random number generator
INDEXB         .EQU  17 ;8 bit index look up table to an 8 bit byte
INDEXW         .EQU  18 ;8 bit index look up table to a 16 bit word
MUSIC          .EQU  19 ;music sequencer
TONE           .EQU  20 ;output a tone
BEEP           .EQU  21 ;key entry beep
SKATE          .EQU  22 ;scan 8x8 display
TXDATA         .EQU  23 ;serial bit bang transmit
;
RXDATA         .EQU  24 ;serial bit bang receive
ASCHEX         .EQU  25 ;convert ASCII character to hexadecimal
WWATCH         .EQU  26 ;write to smartwatch
RWATCH         .EQU  27 ;read from smartwatch
ONESEC         .EQU  28 ;smartwatch one second delay 40
RLSTEP         .EQU  29 ;relay board sequencer
DELONE         .EQU  30 ;one second delay
SCANKEY        .EQU  31 ;scan the keyboard for a key press
;
INTELH         .EQU  32 ;receive INTEL hex file
SPLIT          .EQU  33 ;separate a byte into two right justidied nibbles
SNDMSG         .EQU  34 ;send a zero terminated string
BITASC         .EQU  35 ;convert a byte to an ASCII string as bits
WRDASC         .EQU  36 ;convert a word to ASCII
BYTASC         .EQU  37 ;convert a byte to ASCII
NYBASC         .EQU  38 ;convert a nibble to ASCII
PCBTYP         .EQU  39 ;return PCB type SC
;
ILPSZ          .EQU  40 ;in-line print string
KBDTYP         .EQU  41 ;return keyboard type 74c923 or software scanned
UPDATE         .EQU  42 ;update the display buffer
VARRAM         .EQU  43 ;return variable base address
SERINI         .EQU  44 ;initialise bit bang serial
SCBUG          .EQU  45 ;serial monitor  entry point
MSDELAY        .EQU  46 ;millisecond delay
ESCMORE        .EQU  47 ;list more or escape
ASC2HEX        .EQU  48 ;convert ASCII to hexadecimal
INSBUF         .EQU  49 ;put a char into a buffer
SPCBUF         .EQU  50 ;put a space into a buffer
BCRLF          .EQU  51 ;put a CR LF into a buffer
;END OF INCLUDE FILE
