; ====================
; DIS-Z80 was published in the SUBSET column of Personal Computer World 1987.
; The routine disassembles a single Z80 instruction at address DE. 
; It is required to be followed by a routine called CHROP that outputs a 
; single ASCII character.
; It was originally developed for CP/M on an Amstrad CPC128.

; The original ORG was $0100. I have added $5000 to all addresses.
; The stated aim was to write a Z80 disassembly routine in as short a space
; as possible and, at just over 1K (1090 bytes), it is a rather incredible 
; program. 

; The SUBSET editor David Barrow was able to trim only one byte from John 
; Kerr's compact code. I've forgotten where so there's a challenge.
; ====================

; STRUCTURAL CONCEPTS
; DATA
;
; Disassembled line:
;		field 1: instruction 1st byte location (5 cols).
;		field 2: instruction bytes (12 cols).
;		field 3: mnemonic (5 cols).
;		field 4: operand(s) (13 cols).
;
; Location address	: ASCII hex (4 digits).
; Instruction bytes	: ASCII hex (2 digits sequence).
; Operand data &	: ASCII hex with appended "H" if >9,
;	addresses		:	and preceeding "0" if 1st digit >9.
; Operand offsets	: signed decimal, linked "+" or "-".

; PROGRAM DETAILS
;
; INPUT				DE addresses 1st byte of instruction to disassemble.
; OUTPUT			35 character disassembled line to output device.
; STATE CHANGES		DE updated to address 1st byte of next instruction.
;					AF BC HL changed.
; I/O ERRORS		None.
; OPTIMISATION		Not given.
; INTERRUPT EFFECT	May be interrupted and re-entered.
; LOCATION NEEDS	Not specific. Not relocatable. PROMable.
;					(Listing in this datasheet is assembled at 0100H)
; PROGRAM BYTES		695: code 206 + referenced tables:-
;						GROUP2 (27), GROUP1 (168), GROUP3 (86),
;						MONICS (208).
; STACK BYTES		46 maximum.
; CLOCK CYCLES		Not given.


DISASM	CALL 	ADRSP		; Output the source pointer.

       	LD 	BC,$0900		; Create an 18-byte output
       	LD 	HL,$2020	; buffer in the stack area.
FILBUF
        PUSH    HL			; Buffer initially contains
        DJNZ    FILBUF		; 18 ASCII spaces (20H).

       	LD 	H,B				; Copy SP into HL, so the
       	LD 	L,C				; first byte of the output
       	ADD 	HL,SP		; buffer is addressed by HL.

       	PUSH 	BC			; Save original IX and
       	EX 	(SP),IX			; initialize to zero.
       	PUSH 	BC			; Initialize temp storage
       	PUSH 	BC			; (workspace) to all zeros.
       	ADD 	IX,SP		; Point IX to workspace.

       	PUSH 	HL			; Save buffer pointer; point
       	LD 	HL,GROUP3		; to "ED" instruction group.

TRYNDX	CALL 	FETCH		; Fetch a byte of code.

       	LD 	B,C				; First check whether this
       	CP 	$ED				; is an "ED" instruction.
       	JR 	Z,CONFLG		; Yes; clear the index flag.

       	INC 	B			; Ready to set flag to "1"
       	CP 	$DD				; if the byte is 0DDH (an
       	JR 	Z,CONFLG		; instruction using IX).

       	INC 	B			; Ready to set flag to "2"
       	CP 	$FD				; if the byte is 0FDH (an
       	JR 	NZ,NOTNDX		; instruction using IY).

CONFLG	LD 	(IX+1),B		; Condition the index flag.
       	INC 	B			; Repeat index tests if the
       	DJNZ 	TRYNDX		; pre-byte was 0DDH or 0FDH.
       	JR 	NXBYTE			; Otherwise continue.

NOTNDX	LD 	C,A				; Save byte; check if index
       	LD 	A,(IX+1)		; flag was set (Allows any
       	OR 	A				; series of 0DDH and/or OFDH
       	JR 	Z,NODISP		; bytes, as per Zilog spec).

       	LD 	A,C				; If so, check for presence
       	CP 	$CB				; of any displacement.
       	JR 	Z,GETDIS		; 0CBH needs a displacement.

       	AND 	$44			; A displacement is required
       	CP 	4				; if opcode has bit 2 set
       	JR 	Z,GETDIS		; and bit 6 reset.

       	LD 	A,C				; A displacemnet is required
       	AND 	$C0			; if opcode has bit 6 set
       	CP 	$40				; and bit 7 reset.
       	JR 	NZ,NODISP

GETDIS	CALL 	FETCH		; Get displacement if needed
       	LD 	(IX+2),A		; and save it in workspace.

NODISP	LD 	HL,GROUP1		; "Main" instruction gorup.
       	LD 	A,C				; Recover opcode & check
       	CP 	$CB				; for OCBH ("bit" group).
       	JR 	NZ,NEWMSK		; No; start the search.

       	LD 	HL,GROUP2		; Yes; point to "CB" group.

NXBYTE	CALL 	FETCH		; Fetch the last non-data
       	LD 	C,A				; byte and store it in C.

NEWMSK	LD 	A,(HL)			; Fetch a mask from table.
       	OR 	A				; Mask value of 0 indicates
       	JR 	Z,TABEND		; end of table; quit search.

       	AND 	C			; Otherwise mask the opcode
       	INC 	HL			; and address the mode byte.

NEWMOD	LD 	B,(HL)			; Fetch the mode byte in B.
       	INC 	HL			; Point to the match byte.
       	INC 	B			; Test if the mode is 0FFH
       	JR 	Z,NEWMSK		; and if so, get a new mak.

TRYMAT	CP 	(HL)			; Is the masked opcode
       	INC 	HL			; equal to the match byte?
       	JR 	Z,GETNDX		; Stop searching if it is.

       	BIT 	7,(HL)		; index byte bit 7 is set if
       	INC 	HL			; address mode changes.
       	JR 	Z,TRYMAT		; No change; try next match.

       	JR 	NEWMOD			; Change; get a new mode.

GETNDX	LD 	A,(HL)			; Matched: fetch mnemonic
       	AND 	$7F			; index, mask bit 7, and
       	DEC 	B			; restore the mode byte.

TABEND	POP 	HL			; Save the source pointer
       	PUSH 	DE			; below the output buffer
       	PUSH 	HL			; pointer on stack.

       	EX 	DE,HL			; Point HL to start of the
       	LD 	HL,MONICS		; mnemonics table.
       	CALL 	XTRACT		; Copy mnemonic to buffer.

       	POP 	HL			; Restore output pointer
       	LD 	DE,5			; and adjust to align
       	ADD 	HL,DE		; any operands present.
       	POP 	DE			; Restore source pointer.

       	LD 	A,B				; Test high-order B to see
       	AND 	$F0			; if any "first" operand
       	JR 	Z,SECOND		; is present.

       	RRA					; Yes; move the operand
       	RRA					; index into the lower
       	RRA					; half of A.
       	RRA					; Then save
       	PUSH 	BC			; operand and opcode.

       	LD 	B,A				; Operand index in B.
       	LD 	A,C				; Restore opcode to A.
       	CALL 	OPRND1		; Process the operand.

       	POP 	BC			; Restore the operand byte
       	LD 	A,B				; and opcode; test
       	AND 	$0F			; low-order B for any
       	JR 	Z,OPDONE		; "second" operand.

       	LD 	(HL),44  		; Opearnd index in B.
       	INC 	HL			; Restore opcode to A.

SECOND	LD 	A,B				; Check for the presence
       	AND 	$0F			; of a "second" operand.

       	LD 	B,A				; Operand index in B.
       	LD 	A,C				; Restore opcode to A.
       	CALL 	NZ,OPRND2	; Process any operand.

OPDONE	LD 	A,3				; Check how many bytes
       	SUB 	(IX+0)		; have been fetched.

       	POP 	HL			; Discard workspace.
       	POP 	HL
       	POP 	IX			; Restore index register.

       	JR 	C,OUTEXT		; 4 or more bytes fetched.

       	INC 	A			; Less than four bytes
       	LD 	B,A				; fetched; so output
       	ADD 	A,B			; enough spaces to
       	ADD 	A,B			; align the mnemonics.
       	LD 	B,A

SPACES	LD 	A,$20			; Output spaces
       	CALL 	CHROP		; to start of
       	DJNZ 	SPACES		; mnemonic field.
       	
OUTEXT	LD 	B,18			; Set buffer byte count.

PUTOUT	DEC 	SP			; Copy stored text, byte
       	POP 	HL			; at a time, from output
       	LD 	A,H				; buffer on stack to
       	CALL 	CHROP		; the output channel.
       	DJNZ 	PUTOUT

       	RET					; Instruction disassembled.

;***********************

GROUP2	.DB 	$C0,$36,$40
	.DB 	$04,$80,$2D,$C0,$BE
	.DB 	$FF,$F8,$06,$00,$33
	.DB 	$08,$38,$10,$35,$18
	.DB 	$3A,$20,$3F,$28,$40
	.DB 	$30,$00,$38,$C1


GROUP1	.DB 	$FF,$00,$00
	.DB 	$24,$07,$32,$0F,$37
	.DB 	$17,$31,$1F,$36,$27
	.DB 	$0D,$2F,$0B,$37,$3D
	.DB 	$3F,$06,$76,$14,$C9
	.DB 	$30,$D9,$12,$F3,$0F
	.DB 	$FB,$91,$72,$C6,$02
	.DB 	$CE,$01,$DE,$BC,$02
	.DB 	$D6,$42,$E6,$03,$EE
	.DB 	$43,$F6,$25,$FE,$8C
	.DB 	$04,$08,$93,$01,$10
	.DB 	$10,$18,$9D,$AF,$22
	.DB 	$A2,$FA,$2A,$A2,$A7
	.DB 	$32,$A2,$7A,$3A,$A2
	.DB 	$03,$C3,$1C,$CD,$85
	.DB 	$97,$D3,$AA,$79,$DB
	.DB 	$9B,$5F,$E3,$93,$0E
	.DB 	$E9,$9C,$05,$EB,$93
	.DB 	$DF,$F9,$A2,$FF,$C0
	.DB 	$B6,$40,$A2,$FF,$F8
	.DB 	$76,$80,$02,$88,$01
	.DB 	$98,$BC,$06,$90,$42
	.DB 	$A0,$03,$A8,$43,$B0
	.DB 	$25,$B8,$8C,$FF,$C7
	.DB 	$0B,$04,$16,$05,$8E
	.DB 	$B2,$06,$A2,$20,$C0
	.DB 	$B0,$23,$C2,$1C,$C4
	.DB 	$85,$10,$C7,$BB,$FF
	.DB 	$CF,$D3,$01,$A2,$0D
	.DB 	$03,$16,$0B,$8E,$FD
	.DB 	$09,$82,$60,$C1,$2B
	.DB 	$C5,$AC,$FF,$E7,$21
	.DB 	$20,$9D,$FF,$EF,$E7
	.DB 	$02,$A2,$7E,$0A,$A2


GROUP3	.DB 	$FF,$00,$44
	.DB 	$23,$45,$2F,$4D,$2E
	.DB 	$4E,$00,$67,$39,$6F
	.DB 	$34,$70,$00,$71,$00
	.DB 	$A0,$21,$A1,$0A,$A2
	.DB 	$1A,$A3,$29,$A8,$1F
	.DB 	$A9,$08,$AA,$18,$AB
	.DB 	$28,$B0,$20,$B1,$09
	.DB 	$B2,$19,$B3,$27,$B8
	.DB 	$1E,$B9,$07,$BA,$17
	.DB 	$BB,$A6,$FF,$C7,$B8
	.DB 	$40,$9B,$8B,$41,$AA
	.DB 	$FF,$CF,$FD,$42,$3C
	.DB 	$4A,$81,$AD,$43,$A2
	.DB 	$DA,$4B,$A2,$FF,$E7
	.DB 	$40,$46,$95,$FF,$F7
	.DB 	$C7,$47,$A2,$7C,$57
	.DB 	$A2,$FF,$00

;_______________

MONICS	.DB 	$BF
	.DB 	'A','D','C'+$80   	; ADC 
	.DB 	'A','D','D'+$80   	; ADD 
	.DB 	'A','N','D'+$80   	; AND 
	.DB 	'B','I','T'+$80   	; BIT 
	.DB 	'C','A','L','L'+$80	; CALL 
	.DB 	'C','C','F'+$80   	; CCF
	.DB 	'C','P','D','R'+$80	; CPDR
	.DB 	'C','P','D'+$80   	; CPD
	.DB 	'C','P','I','R'+$80	; CPIR
	.DB 	'C','P','I'+$80   	; CPI
	.DB 	'C','P','L'+$80   	; CPL
	.DB 	'C','P'+$80      	; CP 
	.DB 	'D','A','A'+$80   	; DAA
	.DB 	'D','E','C'+$80   	; DEC 
	.DB 	'D','I'+$80      	; DI
	.DB 	'D','J','N','Z'+$80	; DJNZ 
	.DB 	'E','I'+$80      	; EI
	.DB 	'E','X','X'+$80   	; EXX
	.DB 	'E','X'+$80      	; EX 
	.DB 	'H','A','L','T'+$80	; HALT
	.DB 	'I','M'+$80      	; IM 
	.DB 	'I','N','C'+$80   	; INC 
	.DB 	'I','N','D','R'+$80	; INDR
	.DB 	'I','N','D'+$80   	; IND
	.DB 	'I','N','I','R'+$80	; INIR
	.DB 	'I','N','I'+$80   	; INI
	.DB 	'I','N'+$80      	; IN 
	.DB 	'J','P'+$80      	; JP 
	.DB 	'J','R'+$80      	; JR 
	.DB 	'L','D','D','R'+$80	; LDDR
	.DB 	'L','D','D'+$80   	; LDD
	.DB 	'L','D','I','R'+$80	; LDIR
	.DB 	'L','D','I'+$80   	; LDI
	.DB 	'L','D'+$80      	; LD 
	.DB 	'N','E','G'+$80   	; NEG
	.DB 	'N','O','P'+$80   	; NOP
	.DB 	'O','R'+$80      	; OR 
	.DB 	'O','T','D','R'+$80	; OTDR
	.DB 	'O','T','I','R'+$80	; OTIR
	.DB 	'O','U','T','D'+$80	; OUTD
	.DB 	'O','U','T','I'+$80	; OUTI
	.DB 	'O','U','T'+$80   	; OUT 
	.DB 	'P','O','P'+$80   	; POP 
	.DB 	'P','U','S','H'+$80	; PUSH 
	.DB 	'R','E','S'+$80   	; RES 
	.DB 	'R','E','T','I'+$80	; RETI
	.DB 	'R','E','T','N'+$80	; RETN
	.DB 	'R','E','T'+$80   	; RET
	.DB 	'R','L','A'+$80   	; RLA
	.DB 	'R','L','C','A'+$80	; RLCA
	.DB 	'R','L','C'+$80   	; RLC 
	.DB 	'R','L','D'+$80   	; RLD
	.DB 	'R','L'+$80      	; RL 
	.DB 	'R','R','A'+$80   	; RRA
	.DB 	'R','R','C','A'+$80	; RA
	.DB 	'R','R','C'+$80   	; RRC 
	.DB 	'R','R','D'+$80   	; RRD
	.DB 	'R','R'+$80      	; RR 
	.DB 	'R','S','T'+$80   	; RST 
	.DB 	'S','B','C'+$80   	; SBC 
	.DB 	'S','C','F'+$80   	; SCF
	.DB 	'S','E','T'+$80   	; SET 
	.DB 	'S','L','A'+$80   	; SLA 
	.DB 	'S','R','A'+$80   	; SRA 
	.DB 	'S','R','L'+$80   	; SRL 
	.DB 	'S','U','B'+$80   	; SUB 
	.DB 	'X','O','R'+$80   	; XOR 


; OPRNDZ		Operand Disassembler. To disassembler and output a valid
;				Z80 machine code operand.
; OPRND1		Entry point for certain modes (see DATA)
; OPRND2		Entry point for certain modes (see DATA)

; STRUCTURAL CONCEPTS
; DATA
;
;		Operand:	Standard Z80 assembler format.
;					The operand mode is determined by an input
;					index (1 - 15) and by point of entry:-
;
;		Index		OPRND1				OPRND2
;		------------------------------------------------------
;		1			RST address			Relative address
;		2			Condition			Immediate byte
;		3			Bit number			Immediate word
;		4			Interrupt mode		AF,AF'
;		5			(SP)				DE,HL
;		6			Register pair		8-bit source
;		------------------------------------------------------
;		7					A
;		8					(C)
;		9					(port number)
;		A					(Absolute address)
;		B					8-bit destination
;		C					I or R
;		D					16-bit register
;		E					Address in 16-bit register
;		F					Index register
;
; PROGRAM DETAILS
; INPUT
;					A = opcode.
;					B = operand index.
;					DE addresses next instruction byte.
;					HL addresses next free byte in output buffer.
;					(IX+0) = no. of instruction bytes fetched.
;					(IX+1) = index register flag (1=IX, 2=IY, else 0).
;					(IX+2) = displacement for any indexed instruction.
;
; OUTPUT			Operand is in output buffer.
;					DE and HL are updated.
; STATE CHANGES		AF BC are changed.
;					IX IY (IX+0,1,2) are unchanged.
;*****************

OPRND1	DJNZ 	CONDIT		; First entry point; is mode
RSTADR	AND 	$38			; a restart address? If so,
       	JR 	DA				; isolate opcode bits 5-3.

OPRND2	DJNZ 	DAT8		; 2nd entry point; is mode
RELADR	CALL 	FETCH		; PC relative? If so, fetch
       	LD 	C,A				; displacement & extend
       	RLA					; sign; put full 16-bit
       	SBC 	A,A			; signed displacemnet into
       	LD 	B,A				; BC.
       	EX 	DE,HL			; Move source pointer to HL,
       	PUSH 	HL			; save it on stack, compute
       	ADD 	HL,BC		; destination address & send
       	JR 	DHL				; to the output buffer.

CONDIT	RRA					; Opcode bits 2-0 are not
       	RRA					; needed for any of the
       	RRA					; following modes (OPRND1).
       	DJNZ 	BITNUM		; Is operand a condition?
       	BIT 	4,A			; If so, check whether the
       	JR 	NZ,ABS			; address mode is relative
       	AND 	3			; or absolute. If relative,
ABS   	AND 	7			; adjust condition index.
       	ADD 	A,$14		; Index condition in table.
       	JR 	PS1				; Copy it to the output buffer.

DAT8  	DJNZ 	DAT16		; Is operand immediate byte?

D8    	CALL 	FETCH		; Fetch a byte.
       	JR 	DA				; Send to output buffer.

BITNUM	DJNZ 	INTMOD		; Is operand a bit number?
       	AND 	7			; Yes; isolate the index.

DA    	LD 	C,A				; Move 8-bit data for output
       	SUB 	A			; from A into AC (so A=0)
       	JR 	DAC				; and send to output buffer.

DAT16 	DJNZ 	EXAF		; Is operand an address?
D16   	CALL 	FETCH	; Fetch low-order byte.
       	LD 	C,A				; Save it in C.
       	CALL 	FETCH		; Fetch high order byte.

DAC   	EX 	DE,HL			; Exchange source & output
       	PUSH 	HL			; pointers. Save the source
       	LD 	H,A				; pointer & copy output data
       	LD 	L,C				; from AC into HL.

DHL   	LD 	C,$F8			; Specify hex conversion.
       	PUSH 	HL			; Save output for checking.
       	CALL 	CONVHL		; Perform ASCII conversion.
       	POP 	HL			; retrieve output value.

       	LD 	BC,$000A		; Check whether the value
       	OR 	A				; output was greater than 9.
       	SBC 	HL,BC		; Result of test in Cy.
       	
		POP 	HL			; Restore source & output
       	EX 	DE,HL			; pointers to their originall
       	RET 	C			; registers. Exit if output
       	LD 	(HL),'H'		; value was 9 or less; else
       	INC 	HL			; put "H" (denoting hex)
       	RET					; after the output & exit.

INTMOD	DJNZ 	STKTOP		; Is operand interrupt mode?
       	AND 	3			; Index the list of
       	ADD 	A,$1C		; interrupt modes (0,1,2)
PS1   	JR 	PS3				; Copy to output buffer.

STKTOP	LD 	C,$13			; The constant operand (SP)
       	DEC 	B			; is entry number 19 in the
       	JR 	Z,PS2			; RGSTRS table.

REG16P	DJNZ 	COMMON		; Is the operand register pair?
       	RRA					; Isolate the two bits of the
       	AND 	3			; opcode which determine the
       	CP 	3				; pair. Is it AF?
       	JR 	NZ,RX			; No; go to double register.
       	DEC 	A			; Yes, adjust pointer.
       	JR 	RNX				; Copy out register name.

EXAF  	LD 	C,$0A			; The constant operand
       	DEC 	B			; AF,AF' is entry number 10
       	JR 	Z,PS2			; in the RGSTRS table.

EXDE  	INC 	C			; The constant operand DE,HL
       	DEC 	B			; is entry number 11 in the 
       	JR 	Z,PS2			; RGSTRS table.

REG8S 	DJNZ 	ACCUM		; Is operand 8-bit source?

R8    	AND 	7			; Get register number.
       	CP 	6				; Is it a memory location?
       	JR 	NZ,PS3			; No; so it's B/C/D/E/H/L/A.
       	LD 	(HL),'('		; Yes; put the left parenthesis
       	INC 	HL			; into the output buffer.
       	CALL 	REGX		; Copy register HL/IX/IY.
       	LD 	A,(IX+2)		; Retrieve offset; check if
       	OR 	A				; it is zero. If so, don't
       	JR 	Z,RP			; bother to print it.
       	LD 	(HL),43 		; Otherwise, put a "+" sign
       	RLCA				; into the output buffer, but
       	RRCA				; now test the offset sign.
       	JR 	NC,POS			; If negative, change  the
       	LD 	(HL),45			; sign to "-" and negate
       	NEG					; the offset.

POS   	INC 	HL			; Update the output pointer.
       	EX 	DE,HL			; Exchange pointers, saving
       	PUSH 	HL			; source pointer on stack.
       	LD 	H,B				; Put the absolute value
       	LD 	L,A				; of the offset into HL.
       	LD 	C,$FB			; Specify decimal and
       	CALL 	CONVHL		; perform ASCII convesion.
       	POP 	HL			; Restore pointers to their
       	EX 	DE,HL			; original registers.
       	JR 	RP				; Go put right parenthesis.

ACCUM 	RRA					; Opcode bits 2-0 can now
       	RRA					; be discarded by OPRND2.
       	RRA

COMMON	LD 	C,7				; OPRND1 and OPRND2 merge.
       	DEC 	B			; Accumulator addressing;
       	JR 	Z,PS2			; put "A" to output buffer.

PORTC 	DEC 	C			; Constant operand "(C)" is
       	DJNZ 	IDAT8		; entry number 6 in RGSTRS.
PS2   	LD 	A,C				; Copy string number into A.
PS3   	JR 	PS4				; Go copy out the string.

IDAT8 	DJNZ 	IDAT16		; Is operand a constant port
       	LD 	(HL),'('		; number? If so, that's just
       	INC 	HL			; like an immediate byte but
       	CALL 	D8			; inside brackets.
       	JR 	RP				; Close the brackets.

IDAT16	DJNZ 	REG8		; Is operand an address for
       	LD 	(HL),'('		; data? That's just like a
       	INC 	HL			; CALL or JP address but
       	CALL 	D16			; inside brackets.
       	JR 	RP				; Close the brackets.

REG8  	DEC 	B			; Use 8-bit source routine
       	JR 	Z,R8			; for an 8-bit destination.

IPAREF 	DJNZ 	REG16	; Is operand I or R?
       	AND 	9			; Yes, then copy the correct
       	JR 	PS4				; string from RGSTRS.

REG16 	RRA					; Is operand a
       	DJNZ 	IREG16		; 16-bit register?

R16   	AND 	3			; Check for index register.

RX    	CP  	2			; If it's an index register,
       	JR 	Z,REGX			; go use separate routine.

RNX   	ADD 	A,$0C		; Not an index register;
       	JR 	PS4				; point ot BC/DE/AF/SP.

IREG16	DJNZ 	REGX		; Is the operand an address
       	LD 	(HL),'('		; contained in a register?
       	INC 	HL			; Then just put brackets
       	CALL 	R16			; round the result from R16.

RP    	LD 	(HL),')'		; Put right parenthesis in 
       	INC 	HL			; output buffer, update
       	RET					; pointer, then exit.

REGX  	LD 	A,(IX+1)		; Use the index flag to
       	ADD 	A,$10		; select an index register.

PS4   	EX 	DE,HL			; Copy a string from RGSTRS.
       	PUSH 	HL			; Exchange pointers; save
       	LD 	HL,RGSTRS		; source pointer; point HL
       	CALL 	XTRACT		; to start of table and
       	POP 	HL			; copy out the string. Then
       	EX 	DE,HL			; restore pointers to their
       	RET					; original registers, exit.

;*************

RGSTRS	.DB 	'B'				+$80
	.DB 	'C'       			+$80
	.DB 	'D'       			+$80
	.DB 	'E'       			+$80
	.DB 	'H'       			+$80
	.DB 	'L'       			+$80
	.DB 	'(','C',')' 			+$80
	.DB 	'A'       			+$80
	.DB 	'I'       			+$80
	.DB 	'R'       			+$80
	.DB 	'A','F',',','A','F',$2F		+$80
	.DB 	'D','E',',','H','L'    		+$80
	.DB 	'B','C'             		+$80
	.DB 	'D','E'             		+$80
	.DB 	'A','F'             		+$80
	.DB 	'S','P'             		+$80
	.DB 	'H','L'             		+$80
	.DB 	'I','X'             		+$80
	.DB 	'I','Y'             		+$80
	.DB 	'(','S','P',')'       		+$80
	.DB 	'N','Z'             		+$80
	.DB 	'Z'                		+$80
	.DB 	'N','C'             		+$80
	.DB 	'C'                		+$80
	.DB 	'P','O'             		+$80
	.DB 	'P','E'             		+$80
	.DB 	'P'                		+$80
	.DB 	'M'                		+$80
	.DB 	'0'    				+$80
	.DB 	'?'    				+$80
	.DB 	'1'    				+$80
	.DB 	'2'    				+$80

;********************

CONVHL	SUB 	A

CVHL1 	PUSH 	AF
       	SUB 	A
       	LD 	B,16

CVHL2 	ADD 	A,C
       	JR 	C,CVHL3
       	SUB 	C

CVHL3 	ADC 	HL,HL
       	RLA
       	DJNZ 	CVHL2

       	JR 	NZ,CVHL1

       	CP 	10
       	INC 	B
       	JR 	NC,CVHL1

CVHL4 	CP 	10
       	SBC 	A,$69
       	DAA
       	LD 	(DE),A
       	INC 	DE
       	POP 	AF
       	JR 	NZ,CVHL4

       	RET

;****************

XTRACT	OR 	A
       	JR 	Z,COPY

SKIP  	BIT 	7,(HL)
       	INC 	HL
       	JR 	Z,SKIP

       	DEC 	A
       	JR 	NZ,SKIP

COPY  	LD 	A,(HL)
       	RLCA
       	SRL 	A
       	LD 	(DE),A

       	INC 	DE
       	INC 	HL
       	JR 	NC,COPY

       	RET

;*******************

FETCH 	LD 	A,(DE)
       	INC 	DE
       	INC 	(IX+0)
       	PUSH 	AF
       	CALL 	BYTSP
       	POP 	AF
       	RET

ADRSP 	LD 	A,D
       	CALL 	BYTOP
       	LD 	A,E

BYTSP 	CALL 	BYTOP
       	LD 	A,$20
       	JR 	CHROP

BYTOP 	PUSH 	AF
       	RRA
       	RRA
       	RRA
       	RRA
       	CALL 	HEXOP
       	POP 	AF

HEXOP 	AND 	$0F
       	CP 	10
       	SBC 	A,$69
       	DAA

; -----------------------------------
;
; End of John Kerr's DIS-Z80 routine.
; 
; The next routine outputs a character.
;
; -------------------------------------
