;
; main.asm
;
; Created: 5/09/2018 11:54:46 AM
; Author : embeddedstevo
;
.equ CLOCK		= 8000000  
.equ BAUDRATE	= (CLOCK/ (31250 *16)) - 1

.def temp = r16;
.def addr = r17;
.def noteval = r18;
.def velocity = r19;
.def statusbyte = r20;
; Data control
.equ BUS = PORTB;
.equ CLINE = PORTC;
; Line control values
; x x x x x x BDIR B1 (B2 tied high)
.equ LATCH_ADDRESS = 0x03;
.equ WRITE_DATA =0x01;
.equ INACTIVE =0x00;
; AY 3-8910 Addresses 
.equ A_FINE =0x00;
.equ A_COURSE =0x01;
.equ B_FINE =0x02;
.equ B_COURSE =0x03;
.equ C_FINE =0x04;
.equ C_COURSE =0x05;
.equ N_REG = 0x06;
.equ CONTROL_REG =0x07;
.equ A_AMP =0x08;
.equ B_AMP =0x09;
.equ C_AMP =0x0A;

.CSEG
.ORG 0x00;

;-------------------------------------------------------
;init
;Function: Setup the AVR and clear the AY
;Registers Used: temp, addr
;Return: nothing
;-------------------------------------------------------

init:

;Set up IO
	LDI temp, 0xFF;
	OUT DDRC, temp;
	OUT DDRB, temp;
;this is to be used as a debug port
	OUT DDRA, temp;

;Set up the stack
	LDI temp, low(RAMEND)
	OUT SPL, temp;
	LDI temp, high(RAMEND);
	OUT SPH, temp;

; initialize USART   	
	LDI	temp, (1<<RXEN)|(1<<TXEN); 
	OUT	UCSRB, temp;
;Set up for 1 start bit, 1 stop bit
	LDI temp, (1<<UCSZ1)|(1<<UCSZ0)|(1<<URSEL);
	OUT UCSRC, temp;
;Set the baudrate for 31.25Kbps
	LDI	temp, high (BAUDRATE)	
	OUT	UBRRH, temp
	LDI	temp, low(BAUDRATE);
	OUT	UBRRL, temp

;Rest the AY 3-8910
	LDI addr, CONTROL_REG;
	LDI temp, 0xF8;
	CALL driveay;


;-------------------------------------------------------
;main
;Function: State machiene for the avr
;Registers Used: temp, addr, velocity
;Return: nothing
;-------------------------------------------------------

main:
	CALL getByte;
	CPI temp, 0x80;
	BRLO statusByteCall;
	MOV statusbyte, temp;
	
;Get the lower nibble of the data and store in the addr register
	MOV addr, temp;
	ANDI addr, 0x0F;
;Mask the command nibble
	ANDI temp, 0xF0;

;Compare to see what command has been recieved	
	CPI temp, 0x90;
	BREQ noteOn;

	CPI temp, 0x80;
	BREQ noteOff;

	CPI temp, 0xB0;
	BREQ allOff;

	RJMP main;
;Status byte, last sequence of MIDI messages are followed by data and not a command message,
;reuse the saved command message in statusbyte.
statusByteCall:
	PUSH temp;
	MOV temp, statusbyte;
	MOV addr, temp;
	ANDI addr, 0x0F;
	ANDI temp, 0xF0;
	
	CPI temp, 0x90;
	BREQ statusbyteOn;
	CPI temp, 0x80;
	BREQ statusbyteOff;
	POP temp; Just in Case
	RJMP main;
	
;Get the next two bytes for a note on command
noteOn:
	CALL getbyte;
	MOV noteval, temp;
	CALL getByte;
	MOV velocity, temp;
	CALL driveNote;
	RJMP main;

;Get one byte for a note off command
noteOff:
	CALL getbyte;
	MOV noteval, temp;
	CALL getbyte;
;We can ingore the last byte and just silence the register with a velocity of 0.
	LDI velocity, 0x00;
	CALL driveNote;
	RJMP main;
;---------------------------------------------------------------------------------
;Statusbyte equivalents
statusbyteOn:
	POP noteval;
	CALL getByte;
	MOV velocity, temp;
	CALL driveNote;
	RJMP main;
statusbyteOff:
	POP noteval;
	CALL getByte;
;Important to keep! running status will be thrown off by byte slot otherwise
	MOV velocity, temp; 
	CALL driveNote;
	RJMP main;
;-------------------------------------------------------------------------------------

;Channel message, check to see if the second byte is 0x7B (silence registers)
allOff:
	CALL getbyte;
	MOV noteval, temp;
	CALL getbyte;
	MOV velocity, temp;

	CPI noteval, 0x7B
	BRNE next;
	CALL silenceAllChannels;
next: 
	RJMP main;

;-------------------------------------------------------
;getByte
;Function: To poll the UART until data has been recived
;Registers Used: temp
;Return: UDR value in temp
;-------------------------------------------------------
getbyte:
;Always polling to see if there is a byte coming
	SBIS UCSRA, RXC;
	RJMP getbyte;
	IN temp, UDR;

	RET;

;-------------------------------------------------------
;drivenote
;Function: Using channel, midi note number and velocity
;load all appropriate registers in the AY 3-8910
;Registers Used: temp, addr, noteval and velocuty
;Return: nothing
;-------------------------------------------------------
driveNote:
;Check to see if the channel value is greater than 3
	CPI addr, 0x03;
	BRSH end

;Tone periods are split across two registers, Left shift to times by 2
	LSL addr;
;Toner periods are held across 2 bytes, left shift the midi note value to times by 2
	LSL noteval;

;get note from look up table
	LDI ZL, low((toneperiods<<1));
	ADD ZL, noteval;
	LDI ZH, high((toneperiods<<1)); 
	LPM temp, Z+;
;Write the fine tune tone period to register Rx;
	CALL driveAy;

;Set Up next Address for coursetune
	INC addr;
;Write the course tune tone period to register Rx+1
	LPM temp, Z;
	CALL driveAy;

;Reallig the orignal address so it has no offset
	LDI temp, A_AMP;
	DEC addr;
	LSR addr;
	ADD temp, addr;
	MOV addr, temp;
;Scale the velocity value to fit a 4 bit value 
	LSR velocity;
	LSR velocity;	
	LSR velocity;
	LSR velocity;
	MOV temp, velocity;
;Write the velocity value to the velocity register
	CALL driveAy;	

end:
	RET

;---------------------------------------------------------------
;Drive Ay Function to write data to the AY 3-8910
;Regsiters User: Addr, temp;
;Assume addr holds the destination register for the AY 3-8910
;Assume temp holds the data to be written to the register
;--------------------------------------------------------------
driveay:
	PUSH temp;
;State1: Bring the Control Line to Latch Address;
	LDI temp, LATCH_ADDRESS;
	OUT CLINE, temp;

;State2: Put address on bus;
	OUT BUS, addr;
	NOP

;State3: Bring control Line back to inactive state;
	LDI temp, INACTIVE;
	OUT CLINE, temp;

;State4: Bring the Control line to Write Data;
	LDI temp, WRITE_DATA;
	OUT CLINE, temp;

;State5: Put data on the bus
	POP temp;
	OUT BUS, temp;

;State6: Bring the control line to inactive state;
	LDI temp, INACTIVE;
	OUT CLINE, temp;
	
	CLR temp;
	OUT BUS, TEMP;
	
	RET;

;---------------------------------------------------------------
;Silence all channels in the AY 3-8910
;Regsiters User: Addr, temp;
;Returns nothing
;--------------------------------------------------------------
silenceAllChannels:

	LDI addr, A_AMP;
	LDI temp, 0x00;
loop:
	CALL driveAy;
	INC addr;
	CPI addr, 0x0B;
	BRNE loop;

	RET;

;--------------------------------------------------------------
;TonePeriod Lookup table
;Generated for a 1MHZ clock
;--------------------------------------------------------------
.org 0x200
toneperiods: .db 0x84 , 0x0e , 0x84 , 0x0e , 0x20 , 0x0b , 0x20 , 0x0b , 0x6a , 0x08 , 0x6a , 0x08 , 0x31 , 0x06 , 0x58 , 0x04 , 0x58 , 0x04 , 0xc7 , 0x02 , 0x70 , 0x01 , 0x46 , 0x00 , 0x42 , 0x0f , 0x5c , 0x0e , 0x90 , 0x0d , 0xd9 , 0x0c , 0x35 , 0x0c , 0xa0 , 0x0b , 0x9d , 0x0a , 0x2c , 0x0a , 0xc4 , 0x09 , 0xa , 0x09 , 0x6b , 0x08 , 0x23 , 0x08 , 0xa1 , 0x07 , 0x2e , 0x07 , 0xc8 , 0x06 , 0x6c , 0x06 , 0xf4 , 0x05 , 0xad , 0x05 , 0x4e , 0x05 , 0x16 , 0x05 , 0xc9 , 0x04 , 0x70 , 0x04 , 0x35 , 0x04 , 0x0 , 0x04 , 0xc1 , 0x03 , 0x89 , 0x03 , 0x58 , 0x03 , 0x2b , 0x03 , 0xfa , 0x02 , 0xce , 0x02 , 0xa7 , 0x02 , 0x84 , 0x02 , 0x5e , 0x02 ,  0x38 , 0x02 , 0x1a , 0x02 , 0xfc , 0x01 , 0xe0 , 0x01 , 0xc4 , 0x01 , 0xac , 0x01 , 0x93 , 0x01 , 0x7d , 0x01 , 0x67 , 0x01 , 0x53 , 0x01 , 0x40 , 0x01 , 0x2d , 0x01 , 0x1c , 0x01 , 0xc , 0x01 , 0xfe , 0x00 , 0xef , 0x00 , 0xe1 , 0x00 , 0xd5 , 0x00 , 0xc8 , 0x00 , 0xbd , 0x00 , 0xb3 , 0x00 , 0xa9 , 0x00 , 0x9f , 0x00 , 0x96 , 0x00 , 0x8e , 0x00 , 0x86 , 0x00 , 0x7e , 0x00 , 0x77 , 0x00 , 0x70 , 0x00 , 0x6a , 0x00 , 0x64 , 0x00 , 0x5e , 0x00 , 0x59 , 0x00 , 0x54 , 0x00 , 0x4f , 0x00 , 0x4b , 0x00 , 0x47 , 0x00 , 0x43 , 0x00 , 0x3f , 0x00 , 0x3b , 0x00 , 0x38 , 0x00 , 0x35 , 0x00 , 0x32 , 0x00 , 0x2f , 0x00 , 0x2c , 0x00 , 0x2a , 0x00 , 0x27 , 0x00 , 0x25 , 0x00 , 0x23 , 0x00 , 0x21 , 0x00 , 0x1f , 0x00 , 0x1d , 0x00 , 0x1c , 0x00 , 0x1a , 0x00 , 0x19 , 0x00 , 0x17 , 0x00 , 0x16 , 0x00 , 0x15 , 0x00 , 0x13 , 0x00 , 0x12 , 0x00 ,  0x11 , 0x00 , 0x10 , 0x00 , 0xf , 0x00 , 0xe , 0x00 , 0xe , 0x00 , 0xd , 0x00 , 0xc , 0x00 , 0xb , 0x00 , 0xb , 0x00 , 0xa , 0x00 , 0x9 , 0x00 , 0x9 , 0x00 , 0x8 , 0x00 , 0x8 , 0x00 , 0x7 , 0x00;