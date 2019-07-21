; <- everything after a semiconlon is a comment 
;#########################################################################################################################################################
;Copyright (c) 2019 Peter Shabino
;
;Permission is hereby granted, free of charge, to any person obtaining a copy of this hardware, software, and associated documentation files 
;(the "Product"), to deal in the Product without restriction, including without limitation the rights to use, copy, modify, merge, publish, 
;distribute, sublicense, and/or sell copies of the Product, and to permit persons to whom the Product is furnished to do so, subject to the 
;following conditions:
;
;The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Product.
;
;THE PRODUCT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF 
;MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
;FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION 
;WITH THE PRODUCT OR THE USE OR OTHER DEALINGS IN THE PRODUCT.
;#########################################################################################################################################################	
; 11May2019 V0 PJS New
; 12May2019 V1 PJS started carlieplex code using IRQs	
; 23May2019 V2 PJS mode switch, animation timer, and first mode (blue breating) done
; 01Jun2019 V3 PJS added mode saving to flash and new patterns (cap't, mistake #2, rainbow!)
; 18Jun2019 V4 PJS added breathing green, red, yellow, purple, orange, and pink. Also added solid version of all the previous colors plus blue. Updated timers on 2 animations to slow them down. 
; 20Jun2019 V5 PJS added 5 more color patterns to the 2 dot rotate and single dot chase	
    
; Pre compiler definition. Just like C these statements are processed before the compile happens. 
#define	CODE_VER_STRING "Peter Shabino 20Jun2019 code for Twinkle Twinkie Iron Badge V5 www.wire2wire.org!" ;Just in ROM !!!


; Wiring pin list just for easy referance no affect on the code
;****************************************************************************************
; port list [SSOP20]
; Vdd(1)
; Vss(20)
; RA0(19)	[ICSPDAT]
; RA1(18)	[ICSPCLK]
; RA2(17)	D1-6B D9,D15
; RA3(4)	[#MCLR] select button in
; RA4(3)	D1-6R D7,D13
; RA5(2)	D1-6G D8,D14
; RB4(13)	D7-12G D2,D17
; RB5(12)	D7-12R D1,D16
; RB6(11)	D7-12B D3,D18
; RB7(10)	
; RC0(16)	SCL
; RC1(15)	SDA
; RC2(14)	
; RC3(7)	
; RC4(6)	
; RC5(5)	D13-18B D6,D12
; RC6(8)	D13-18G D5,D11
; RC7(9)	D13-18R D4,D10
;****************************************************************************************


; The following links configure the "fuses" on older devices these could only be configured one time at programming. Some newer devices let you update some of them run time. 
; These are core options like clock source, speed, read protection, etc. 
; Easiest way to configure these in MPLABX is to go Windows->Target memory views->Configureation bits this will pop up a new tab in the lower right window with descriptions 
; of each bit and pull downs with the available settings. Once you make all yor choces click the "Generate Source Code to Output" button. When you click the button the 
; "Output - config bits source" tab will pop to the front with the following flags configured in it. Copy paste here and your done. 
#include "p16f15344.inc"
; CONFIG1
; __config 0xFFFC
 __CONFIG _CONFIG1, _FEXTOSC_OFF & _RSTOSC_EXT1X & _CLKOUTEN_OFF & _CSWEN_ON & _FCMEN_ON
; CONFIG2
; __config 0xF7FC
 __CONFIG _CONFIG2, _MCLRE_OFF & _PWRTE_ON & _LPBOREN_OFF & _BOREN_ON & _BORV_LO & _ZCD_OFF & _PPS1WAY_OFF & _STVREN_ON
; CONFIG3
; __config 0xFF9F
 __CONFIG _CONFIG3, _WDTCPS_WDTCPS_31 & _WDTE_OFF & _WDTCWS_WDTCWS_7 & _WDTCCS_SC
; CONFIG4
; __config 0xFFFF
 __CONFIG _CONFIG4, _BBSIZE_BB512 & _BBEN_OFF & _SAFEN_OFF & _WRTAPP_OFF & _WRTB_OFF & _WRTC_OFF & _WRTSAF_OFF & _LVP_OFF
; CONFIG5
; __config 0xFFFF
 __CONFIG _CONFIG5, _CP_OFF 
; max speed, BOR enabled, No boot block or SAF, no read or write protect enabled 

 
; <spaghetti> 
 
 
; No need to use this just a place to put named constants to make tweeking multi use constants easier  
;------------------
; constants
;------------------	
TMR1L_value		equ 0xC0		; the TMR1 values set the display scan rate. Too slow (smaller value) and it will filcker. Too high (larger value) and the firmware will endlessly get stuck in the IRQ loop.
TMR1H_value		equ	0xFF
max_color_depth	equ 0x10		; the max_color_depth sets how many bits of PWM the code tries to emulate. The more bits the more potential color combinations you can have. The draw back is this increases the number of full IRQ loops per cycle. Too high the display will filcker. 
mode_save		equ 0x8FE0 

	org	0FE0h 
	de	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
	de	0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF		
		
		
; there are 3 major memory ranges in the PIC. Ram, Flash, and user data
; -- Ram are fixed registers you can read and write from with a single cycle. Some control special functions like IO while otheres are just storage locations
; See page 38+ of http://ww1.microchip.com/downloads/en/DeviceDoc/PIC16-L-F15324-44-data-sheet-40001889B.pdf for the full map. 
; Due to the size of the memory map and the lack of bits in the instructions the map is broken up in to banks. You need to make sure the correct bank is selected before read/write our you will get the wrong data
; exception is the core register bank and the common RAM (I call it global below) which is at the same addresses in EVERY bank of ram. 
; -- Flash is where the user program is stored / run from. To byte wise reads from it are relatively easy. Writes are difficult and typically have to be done a word line at a time (32 words in this case). User has to manage the erase and program cycles. 
; this part only has a single page of flash. So no need to worry about crossing flash page boundarys (special care is needed to switch banks back and forth properly) 
; more info on page 32 of http://ww1.microchip.com/downloads/en/DeviceDoc/PIC16-L-F15324-44-data-sheet-40001889B.pdf.
; -- User data are special ranges that have different rules from the bulk flash area. Some parts have byte wise single instruction read / write. Otheres have special boot areas and so on. Not using any of those in this program. 
 
; the eq command allows setting a lable to a specific value. I use this to lay out my memory map here. No need to do this at all but your future self and others looking at the code will thank you later.  
;------------------
; vars (0x20 - 0x6f) bank 0
;------------------ 
led_seq		equ	0x20
led1r		equ	0x21
led1g		equ	0x22
led1b		equ	0x23
led2r		equ	0x24
led2g		equ	0x25
led2b		equ	0x26
led3r		equ	0x27
led3g		equ	0x28
led3b		equ	0x29
led4r		equ	0x2a
led4g		equ	0x2b
led4b		equ	0x2c
led5r		equ	0x2d
led5g		equ	0x2e
led5b		equ	0x2f
;led6r		equ	0x30  ; skip led not used (if enabled again remap everything...)
;led6g		equ	0x31
;led6b		equ	0x32
led7r		equ	0x30
led7g		equ	0x31
led7b		equ	0x32
led8r		equ	0x33
led8g		equ	0x34
led8b		equ	0x35
led9r		equ	0x36
led9g		equ	0x37
led9b		equ	0x38
led10r		equ	0x39
led10g		equ	0x3a
led10b		equ	0x3b
;led11r		equ	0x3e	; skip led not used (if enabled again remap everything...)
;led11g		equ	0x3f
;led11b		equ	0x40
;led12r		equ	0x41	; skip led not used (if enabled again remap everything...)
;led12g		equ	0x42
;led12b		equ	0x43
led13r		equ	0x3c
led13g		equ	0x3d
led13b		equ	0x3e
led14r		equ	0x3f
led14g		equ	0x40
led14b		equ	0x41
led15r		equ	0x42
led15g		equ	0x43
led15b		equ	0x44
led16r		equ	0x45
led16g		equ	0x46
led16b		equ	0x47
led17r		equ	0x48
led17g		equ	0x49
led17b		equ	0x4a
led18r		equ	0x4b
led18g		equ	0x4c
led18b		equ	0x4d
; space for full LED map if needed. 		
irq_temp	equ 0x56
fake_pwm	equ	0x57
debounce	equ 0x58
mode		equ	0x59
stat		equ 0x5a
bulk_red	equ 0x5b
bulk_green	equ 0x5c
bulk_blue	equ	0x5d
ann_seq0	equ 0x5e
ann_seq1	equ	0x5f
ann_seq2	equ	0x60
ann_seq3	equ	0x61
LFSR_0		equ	0x62		
LFSR_1		equ	0x63		
LFSR_2		equ	0x64		
LFSR_3		equ	0x65	
LFSR_count	equ	0x66
temp		equ 0x67

		
		
;------------------
; vars (0xa0 - 0xef) bank 1
;------------------ 

		
;------------------
; vars (0x120 - 0x16f) bank 2
;------------------ 

;------------------
; vars (0x1a0 - 0xaef) bank 3
;------------------ 

;------------------
; vars (0x220 - 0xe6f) bank 4
;------------------ 

;------------------
; vars (0x2a0 - 0x2ef) bank 5
;------------------ 

;------------------
; vars (0x320 - 0x32f) bank 6
;------------------ 
 
;------------------
; vars (0x70 - 0x7F) global regs (lats 16 bytes of every bank point back to these locations)
;------------------
gtemp		equ	0x70


; There are 2 special addresses in the memory map 0x0 and 0x4. 
; 0x0 is where the micro starts running when it comes out of reset. This is typically just a jump to the start of the initilization code. 
; 0x4 is where the micro jumps to ever time a interrup is active. 
;put the following at address 0000h
	org     0000h
	goto    START			    ;vector to initialization sequence


;###########################################################################################################################
; intrupt routine
; if reading thought the code for the first time skip down to the "START" lable and come back here later. 
;###########################################################################################################################
	;put the following at address 0004h
	org     0004h
	; following regs are autosaved to shadow register on interrupt. 
	; W
	; STATUS (except TO and PD)
	; BSR
	; FSR
	; PCLATH
	; the retfie instruction will restore them from the shadow regs. 
	; make sure to set to a known value when you start processing the interrupt as they could be set to anyting at this point. 

	;------------------
	movlw	d'14'
	movwf	BSR		
	;------------------
	btfss	PIR4, 0				; is timer 1 IRQ active
	goto	IRQ_not_tmr1
	bcf		PIR4, 0				; clear timer 1 flag
	
	;------------------
	movlw	d'4'
	movwf	BSR		
	;------------------
	; reset timer 1 (can be issues updating timer 1 while running. So stop then reset it) 
	bcf		T1CON, 0		; timer off
	movlw	TMR1H_value		; update values
	movwf	TMR1H
	movlw	TMR1L_value
	movwf	TMR1L
	bsf		T1CON, 0		; timer on

	
	;------------------	
	clrf    BSR			    ; bank 0
	;------------------	
	
	
	; turn off all the LEDs (make them inputs)
	movlw	0x34
	iorwf	TRISA, F
	movlw	0x70
	iorwf	TRISB, F
	movlw	0xE0
	iorwf	TRISC, F


	; make sure led_seq is in range if over will jump to who knows where
	movlw	0x0F				; 15 skipping unused LEDs
	subwf	led_seq, W			; C = 0 if W > F, C = 1 W <= F
	btfss	STATUS, C
	goto	IRQ_bank_scan
	clrf	led_seq	
	incf	fake_pwm, F			; update the PWM bank to the next step. 
	movlw	max_color_depth		; count 0 to full on 
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	clrf	fake_pwm
IRQ_bank_scan	
	
	; set the common pin high for the led selected. 
	movf	led_seq, W
	movwf	irq_temp
	bcf		STATUS, C
	rlf		irq_temp, f		; multiply by 2
	bcf		STATUS, C
	rlf		irq_temp, W		; multiply by 2
	; jump lookup table
	brw
	bsf		LATB, 5			; D1
	bcf		TRISB, 5		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATB, 4			; D2
	bcf		TRISB, 4		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATB, 6			; D3
	bcf		TRISB, 6		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATC, 7			; D4
	bcf		TRISC, 7		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATC, 6			; D5
	bcf		TRISC, 6		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
;	bsf		LATC, 5			; D6 skip not used
;	bcf		TRISC, 5		; make it a output
;	goto	IRQ_set_common_done
;	nop						; required for spacing on the jumps
	bsf		LATA, 4			; D7
	bcf		TRISA, 4		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATA, 5			; D8
	bcf		TRISA, 5		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATA, 2			; D9
	bcf		TRISA, 2		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATC, 7			; D10
	bcf		TRISC, 7		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
;	bsf		LATC, 6			; D11 skip not used
;	bcf		TRISC, 6		; make it a output
;	goto	IRQ_set_common_done
;	nop						; required for spacing on the jumps
;	bsf		LATC, 5			; D12 skip not used
;	bcf		TRISC, 5		; make it a output
;	goto	IRQ_set_common_done
;	nop						; required for spacing on the jumps
	bsf		LATA, 4			; D13
	bcf		TRISA, 4		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATA, 5			; D14
	bcf		TRISA, 5		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATA, 2			; D15
	bcf		TRISA, 2		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATB, 5			; D16
	bcf		TRISB, 5		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATB, 4			; D17
	bcf		TRISB, 4		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	bsf		LATB, 6			; D18
	bcf		TRISB, 6		; make it a output
	goto	IRQ_set_common_done
	nop						; required for spacing on the jumps
	
IRQ_set_common_done	
	
	
	
	clrf	FSR0H
	movlw	led1r
	movwf	FSR0L
	movf	led_seq, W
	addwf	FSR0L, F		; set FSR0 to 3x led_seq
	addwf	FSR0L, F
	addwf	FSR0L, F
	
	; set the RGB lines low for which you want to turn on for this led
	; bank 1 (led 1 thru 6). 
	;movlw	0x06
	movlw	0x05				; skip unused LEDS				
	subwf	led_seq, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank1_chk

	; red
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank0_red
	bcf		LATA, 4
	bcf		TRISA, 4
IRQ_bank0_red
	; green
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank0_green
	bcf		LATA, 5
	bcf		TRISA, 5
IRQ_bank0_green
	; blue
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_banks_done	
	bcf		LATA, 2
	bcf		TRISA, 2
	goto	IRQ_banks_done	
	
IRQ_bank1_chk
	; bank 2 (led 7 thru 12). 
	;movlw	0x0C				; 12
	movlw	0x09				; 9 skip unused LEDS
	subwf	led_seq, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank2_chk

	; red
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank1_red
	bcf		LATB, 5
	bcf		TRISB, 5
IRQ_bank1_red
	; green
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank1_green
	bcf		LATB, 4
	bcf		TRISB, 4
IRQ_bank1_green
	; blue
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_banks_done	
	bcf		LATB, 6
	bcf		TRISB, 6
	goto	IRQ_banks_done	
	
IRQ_bank2_chk
	; bank 3 (led 13 thru 18). 
	; red
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank2_red	
	bcf		LATC, 7
	bcf		TRISC, 7
IRQ_bank2_red
	; green
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_bank2_green
	bcf		LATC, 6
	bcf		TRISC, 6
IRQ_bank2_green
	; blue
	incf	FSR0L, F
	movf	INDF0, W			; check if led should be on for this fake PWM cycle
	subwf	fake_pwm, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	IRQ_banks_done	
	bcf		LATC, 5
	bcf		TRISC, 5
	
	
IRQ_banks_done	
	
	
	; Wiring pin list just for easy referance no affect on the code
;****************************************************************************************
; port list [SSOP20]
; Vdd(1)
; Vss(20)
; RA0(19)	[ICSPDAT]
; RA1(18)	[ICSPCLK]
; RA2(17)	D1-6B D9,D15
; RA3(4)	[#MCLR] select button in
; RA4(3)	D1-6R D7,D13
; RA5(2)	D1-6G D8,D14
; RB4(13)	D7-12G D2,D17
; RB5(12)	D7-12R D1,D16
; RB6(11)	D7-12B D3,D18
; RB7(10)	
; RC0(16)	SCL
; RC1(15)	SDA
; RC2(14)	
; RC3(7)	
; RC4(6)	
; RC5(5)	D13-18B D6,D12
; RC6(8)	D13-18G D5,D11
; RC7(9)	D13-18R D4,D10
;****************************************************************************************	
		

	
	; increment the timer sequence  
	incf	led_seq, F

	
	
	
IRQ_not_tmr1	
	
	retfie
;###########################################################################################################################
; end of IRQ code
;###########################################################################################################################	
	

; this is a lable. Compiler will automatically replace these with addresses when used in goto and branch statements. 	
START
	; init crap
	;------------------
	; the ram memory is broken up into into multiple pages. This command sets the current page to 0 where I want to start my init work. 
	clrf    BSR			    ; bank 0
	;------------------
	clrf	INTCON			; disable interupts
	
	clrf	LATA			; set all IOs low 
	clrf	LATB			; set all IOs low 
	clrf	LATC			; set all IOs low 
	
	movlw	0xFF			
	movwf	TRISA			; all LED IOs to inputs (tristate), MCLR as input (can only be a input) 		
	movlw	0x70			
	movwf	TRISB			; all LED IOs to inputs (tristate), others as outputs to keep them from floating (draws more power than just driving them low)
	movlw	0xE0			
	movwf	TRISC			; all LED IOs to inputs (tristate), others as outputs to keep them from floating (draws more power than just driving them low) I2C is pins C0 and C1
	
	; clear vars
	movlw	0x20			; start of bank 0 vars
	movwf	FSR0L
	clrf	FSR0H
	movlw	0x50			; clear all of bank other than globals
	movwf	gtemp
init_bank0_loop
	clrf	INDF0
	incf	FSR0L
	decfsz	gtemp, F
	goto	init_bank0_loop
	
	; LFSR CANOT BE 0!!!! If it is it will never return any value other than 0. 
	movwf	0x44
	movwf	LFSR_0
	movwf	LFSR_1
	movwf	LFSR_2
	movwf	LFSR_3
	
	;------------------
	movlw	d'4'
	movwf	BSR		
	;------------------
	; set up timer1. This is used to drive the interrupt that updates the LEDs
	
	movlw	TMR1H_value
	movwf	TMR1H
	movlw	TMR1L_value
	movwf	TMR1L
	clrf	T1GATE			; T1GPPS (not used)
	movlw	0x01
	movwf	T1CLK			; Fosc/4
	clrf	T1GCON			; gate disable timer always counts
	movlw	0x07
	movwf	T1CON			; do not sync, 16 bit reads, timer 1 on
		
	;------------------
	movlw	d'14'
	movwf	BSR		
	;------------------
	bsf		PIE4, 0				; enable timer 1 IRQ
	bcf		PIR4, 0				; clear timer 1 flag	
	
	;------------------
	movlw	d'62'
	movwf	BSR		
	;------------------
	; configure properties of the IO pins.
	clrf	ANSELA			; set io to be a digital pin not analog
	clrf	WPUA			; weak pull ups disabled
	clrf	ODCONA			; push pull not open drain selected. 
	clrf	SLRCONA			; max slew rate (hard edges)
	clrf	INLVLA			; pick TTL voltage levels over ST levels for interrupt on change comparitor (if used)
	clrf	ANSELB			; set io to be a digital pin not analog
	clrf	WPUB			; weak pull ups disabled
	clrf	ODCONB			; push pull not open drain selected. 
	clrf	SLRCONB			; max slew rate (hard edges)
	clrf	INLVLB			; pick TTL voltage levels over ST levels for interrupt on change comparitor (if used)
	clrf	ANSELC			; set io to be a digital pin not analog
	clrf	WPUC			; weak pull ups disabled
	clrf	ODCONC			; push pull not open drain selected. 
	clrf	SLRCONC			; max slew rate (hard edges)
	clrf	INLVLC			; pick TTL voltage levels over ST levels for interrupt on change comparitor (if used)


	;------------------
	clrf    BSR					; bank 0
	;------------------
	movlw	0xE0				; global, PE, and Timer 0 on
	movwf	INTCON			    ; enable interrupts


	
	; grab the saved mode value from flash
	movlw	HIGH(mode_save)
	movwf	FSR0H
	movlw	LOW(mode_save)
	movwf	FSR0L
	movf	INDF0, W
	movwf	mode
	
	
;--------------------------------------------------------------------------------------------------------------------------------------------------	
MAINLOOP
	;------------------
	clrf    BSR					; bank 0
	;------------------
	
	
	; deboune the button incremetn the mode when the button is pressed
	bcf		STATUS, C			; carry bit is used in the rotate command
	btfsc	PORTA, 3			; select button
	bsf		STATUS, C			; if the button was high set carry high. Else leave low
	rrf		debounce, F			; rotate bit in
	; look at last status of the button and branck to the proper code
	btfss	stat, 0
	goto	button_was_low
	; button was last high (not pressed) wait for a press
	movf	debounce, W
	btfss	STATUS, Z			; if Z = 1 the value of debounce is zero meaning the button was down for at least 8 cycles
	goto	button_no_change
	bcf		stat, 0				; set status to indicate button was low last
	incf	mode, F				; add one to the mode bit	
	movf	mode, W
	movwf	gtemp				; save temporarily to a global var for use in the flash write seq below
	; reset the delay timer if running. 
	;------------------
	movlw	d'11'
	movwf	BSR		
	;------------------
	clrf	T0CON0				; turn off timer	
	; save the new mode value to flash so it can be retrieved on power cycle
	;------------------
	movlw	d'16'
	movwf	BSR		
	;------------------
	; erase row
	movlw	LOW(mode_save)
	movwf	NVMADRL
	movlw	HIGH(mode_save)
	andlw	0x7F
	movwf	NVMADRH		
	movlw	0x14			    ; flash regs, erase, write enable
	movwf	NVMCON1
	call	_unlock_flash		; special sequence to do a write or clear to flash
	bcf		NVMCON1, WREN		; disable writes
	; mode save offset	
	movlw	LOW(mode_save)
	movwf	NVMADRL
	movlw	HIGH(mode_save)
	andlw	0x7F
	movwf	NVMADRH	
	;point at the data buffer
	movlw	0x24			    ; flash regs, load latches only, write enable
	movwf	NVMCON1
mode_data_loop	
	movf	gtemp, W				; just saving the mode value to all 32 bytes. Only realy needs to be in the first one. 
	movwf	NVMDATL			    ; load the data byte
	clrf	NVMDATH
	movf	NVMADRL, W
	andlw	0x1F			    ; mask off the bottom 5 bits
	xorlw	0x1F			    ; check if = 31
	btfsc	STATUS, Z
	goto	mode_start_flash_write
	call	_unlock_flash		; special sequence to do a write or clear to flash
	incf	NVMADRL, F	
	goto	mode_data_loop
mode_start_flash_write
	bcf		NVMCON1, LWLO		; flip the bit to do the actual write to flash vs just loading the data registers
	call	_unlock_flash		; special sequence to do a write or clear to flash
	bcf		NVMCON1, WREN		; disable writes
	;------------------
	clrf    BSR					; bank 0
	;------------------
	; clear out the animation seq counters since a new animation was picked
	clrf	ann_seq0
	clrf	ann_seq1
	clrf	ann_seq2
	goto	button_no_change
button_was_low	
	; last update the button was low (pressed) wait till it is released before restarting the press detect. 
	comf	debounce, W
	btfss	STATUS, Z			; if Z = 1 the value of debounce is zero meaning the button was down for at least 8 cycles
	goto	button_no_change
	bsf		stat, 0				; set status to indicate button was high last	
button_no_change
	
	
	
	; check if the delay timer is running 
	;------------------
	movlw	d'11'
	movwf	BSR		
	;------------------
	btfss	T0CON0, 7			; timer on bit
	goto	delay_not_running
	;------------------
	movlw	d'14'
	movwf	BSR		
	;------------------
	; if delay timer is running check if it has timed out yet
	btfss	PIR0, 5
	goto	MAINLOOP			; hop back to the start of the loop to check the mode button while in a led delay. 
	; timer has rolled over clean up and turn it off
	bcf		PIR0, 5				; clear timer 0 flag
	;------------------
	movlw	d'11'
	movwf	BSR		
	;------------------
	clrf	T0CON0				; turn off timer	
delay_not_running	
	;------------------
	clrf    BSR					; bank 0
	;------------------
	
	
	; check which mode we are in and use the propper pattern 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; Request: Pulsing [color] with it going slightly lighter and back to full [color].
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movlw	0x07				; check if mode is in range
	subwf	mode, W				; C = 0 if W > F, C = 1 W <= F	
	btfsc	STATUS, C			; if the result is 0 skip the jump 
	goto	not_mode0_6
	
	movlw	0x10				; check if over max if so reset to 0
	subwf	ann_seq0, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	mode0_ramp_down
	

	; ramp up
	movf	mode, W
	movwf	ann_seq1
	call	_pallet_cycle		; ann_seq1 is used to control this which is = to mode in this case	
	movf	ann_seq0, W
	addwf	bulk_blue, F
	addwf	bulk_red, F
	addwf	bulk_green, F
	call	_set_all
	
	movlw	0x10				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
		
	incf	ann_seq0, F
	; this value sets the max ramp rate!!!!!
	movlw	0x05				; check if over if so advance to the next stage
	subwf	ann_seq0, W			; C = 0 if W > F, C = 1 W <= F
	btfss	STATUS, C	
	goto	MAINLOOP
	
	; if at max use a longer delay (resets the delay set up before 
	movlw	0x10				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay	
	
	; set seq to ramp down on next run 
	movlw	0x10
	iorwf	ann_seq0, F
	
	goto	MAINLOOP
		
mode0_ramp_down
	; ramp down
	decf	bulk_blue, F
	decf	bulk_red, F
	decf	bulk_green, F
	call	_set_all

	movlw	0x10				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	decf	ann_seq0, F
	movf	ann_seq0, W
	xorlw	0x11				; check if over max mode if so reset to 0
	btfss	STATUS, Z	
	goto	MAINLOOP
	
	; if at min use a longer delay (resets the delay set up before 
	movlw	0x20				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	; reset counter to 0
	clrf	ann_seq0
	
	goto	MAINLOOP
	
	
not_mode0_6	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; Request: Rotating Infinity Stone Colors around the edge with "Pulsing" yellow" in the center.
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x07				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode7
	
	clrf	ann_seq1

	call	_inf5_cycle			
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	; triple LED
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	
	call	_inf5_cycle
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	call	_inf5_cycle
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	; triple LED
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	call	_inf5_cycle
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	call	_inf5_cycle
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led

	;call	_clear_RGB
	;call	_rotate_set_outer_ring
	;incf	ann_seq2,F			; used by outer ring to pick led

	;call	_rotate_set_outer_ring
	;incf	ann_seq2,F			; used by outer ring to pick led
	
	; this check is to prevent the display from getting stuck since the rotate == the number of leds. 
	movlw	0x0C				; if greater than 12 rest to 0
	subwf	ann_seq2, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq2	
not_mode7_skip	
	incf	ann_seq2,F			; used by outer ring to pick led
	
	; yellow pulse
	movlw	0xFF	
	movwf	led8r
	movwf	led8g
	movwf	led9r
	movwf	led9g
	movwf	led15r
	movwf	led15g

	
	movlw	0x10				; check if over max if so reset to 0
	subwf	ann_seq0, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C
	goto	mode7_ramp_down	
	
	; ramp up
	movf	ann_seq0, W
	movwf	led8b
	movwf	led9b
	movwf	led15b	
	incf	ann_seq0, F
	; this value sets the max ramp rate!!!!!
	movlw	0x08				; check if over max mode if so reset to 0
	subwf	ann_seq0, W			; C = 0 if W > F, C = 1 W <= F
	btfss	STATUS, C	
	goto	mode7_done
	; set seq to ramp down on next run 
	movlw	0x10
	iorwf	ann_seq0, F
	goto	mode7_done
		
mode7_ramp_down
	; ramp down
	movf	ann_seq0, W			; invert value 
	andlw	0x0F				; mask off upper bits 
	movwf	led8b
	movwf	led9b
	movwf	led15b	
	decf	ann_seq0, F
	movf	ann_seq0, W
	xorlw	0x10				; check if over max mode if so reset to 0
	btfss	STATUS, Z	
	goto	mode7_done	
	; reset counter to 0
	clrf	ann_seq0

mode7_done	
	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay

	goto	MAINLOOP
	
not_mode7	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; found this animation while working on the previous one looked oool so lef it in. Chasing stones
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x08				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode8
	
	call	_inf5_cycle
	call	_rotate_set_outer_ring
	incf	ann_seq1,F			; used by inf5 cycle to get color to return
	incf	ann_seq2,F			; used by outer ring to pick led
	
	
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	movf	ann_seq0, W
	andlw	0x01
	btfss	STATUS, Z
	goto	not_mode8_skip
	movlw	0x08
	movwf	bulk_blue	
not_mode8_skip	
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq0,F			; toss in a bight led every 4 (1 more than previous update)
	incf	ann_seq3,F			; used by inner ring to pick led
			
	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_mode8	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; set LEDS to random values 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x09				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode9

	movlw	0x12				; if greater than 12 rest to 0
	subwf	ann_seq0, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq0	
	
	clrf	FSR1H				; set up indirect register to start of led bank
	movlw	led1r				; start of LED regs
	movwf	FSR1L
	movf	ann_seq0, W
	addwf	FSR1L				; add 3x seq number 
	addwf	FSR1L				; add 3x seq number 
	addwf	FSR1L				; add 3x seq number 
		
	call	_CYCLE_LFSR	
	andlw	0x0F
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	call	_CYCLE_LFSR	
	andlw	0x0F
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	call	_CYCLE_LFSR	
	andlw	0x0F
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	
	incf	ann_seq0, F

	;movlw	0x02				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	;call	_delay	
	
	goto	MAINLOOP

	
not_mode9	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 red 2 blue outer ring rotate white center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0A				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeA
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeA_loop
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeA_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeA	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 yellow 2 red outer ring rotate blue center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0B				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeB
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeB_loop
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeB_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeB	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 green 2 purple outer ring rotate white center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0C				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeC
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeC_loop
	movlw	0xff	
	clrf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeC_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeC	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 blue 2 white outer ring rotate red center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0D				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeD
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeD_loop
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movlw	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeD_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeD
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 blue 2 purple outer ring rotate white center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0E				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeE
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeE_loop
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeE_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeE
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; request Chasing Light where one solid color rotates around the LEDs. 2 red 2 white outer ring rotate green center
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x0F				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_modeF
	

	; preset ring loop with offset
	movf	ann_seq1, W
	movwf	ann_seq2

	movlw	0x03				
	movwf	ann_seq0
modeF_loop
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	decfsz	ann_seq0, F
	goto	modeF_loop
	; shift next run by 1 led
	incf	ann_seq1,F			; used by outer ring to pick led
	movf	ann_seq1,W			; check if over 11 if so reset
	movlw	0x0C
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1	
	
	movlw	0xff	
	clrf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x08				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP

not_modeF	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x10				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode10

	
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
		
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode10	
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x11				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode11

	
	;outer
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	; chase
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	; inner	
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode11
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x12				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode12

	
	;outer
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	; chase
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	; inner	
	movlw	0xff	
	clrf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode12
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x13				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode13

	
	;outer
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	; chase
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	; inner	
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode13
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x14				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode14

	
	;outer
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	; chase
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	; inner	
	movlw	0xff	
	clrf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode14
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; screwed up above but looked cool. 
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x15				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode15

	
	;outer
	movlw	0xff	
	movwf	bulk_red
	movwf	bulk_green
	movwf	bulk_blue
	call	_rotate_set_outer_ring
	incf	ann_seq2,F			; used by outer ring to pick led
	; chase
	movlw	0xff	
	clrf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_outer_ring
	; inner	
	movlw	0xff	
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led

	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP
	
not_mode15
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; Request: solid colors
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movlw	0x1D				; check if mode is in range
	subwf	mode, W				; C = 0 if W > F, C = 1 W <= F	
	btfsc	STATUS, C			; if the result is 0 skip the jump 
	goto	not_mode16_1C
	
	movf	mode, W
	movwf	ann_seq1
	movlw	0x16
	subwf	ann_seq1, F
	call	_pallet_cycle		; ann_seq1 is used to control this which is = to mode in this case	
	call	_set_all

	movlw	0xFF				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP	
	
	
not_mode16_1C
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; Rainbow!
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	movf	mode, W				; grap the mode and shove it in W
	xorlw	0x1D				; exclusive or value with W (if W == value then the result will be 0) 
	btfss	STATUS, Z			; if the result is 0 skip the jump 
	goto	not_mode1D
	
	call	_rainbow_cycle
	call	_rotate_set_outer_ring
	call	_rotate_set_inner_ring_ccw
	incf	ann_seq3,F			; used by inner ring to pick led
	incf	ann_seq2,F			; used by outer ring to pick led
	incf	ann_seq1, F			; used by rainbow code	
	
	movlw	0x04				; delay value from 0.017s to ~4.2s in 256 steps (0.017s per step)
	call	_delay
	
	goto	MAINLOOP	
	
	

not_mode1D
	; --------------------------------------------------------------------------------------------------------------------------------------------------
	; mode greater than the max value reset to 0
	; --------------------------------------------------------------------------------------------------------------------------------------------------	
	clrf	mode	
	goto	MAINLOOP
	
ENDLOOP
	; this is a catch and stop loop used for debug and in case something above goes wild.... 
	goto	ENDLOOP

	

;################################################################################
;_pwm_values
;	andlw	0x0F
;	brw		
;	retlw	0x00
;	retlw	0x01
;	retlw	0x03
;	retlw	0x07
;	retlw	0x0B
;	retlw	0x12
;	retlw	0x1E
;	retlw	0x28
;	retlw	0x32
;	retlw	0x41
;	retlw	0x50
;	retlw	0x64
;	retlw	0x7D
;	retlw	0xA0
;	retlw	0xC8
;	retlw	0xFF
;	
;	return
	
;################################################################################
; Based on ann_seq1 return RGB values for 5 of 6 inf stone colors
;################################################################################
_pallet_cycle
	
	movlw	0x07				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1
	
	movf	ann_seq1, W
	btfss	STATUS, Z
	goto	_pallet_cycle_not_blue
	clrf	bulk_red
	clrf	bulk_green
	movlw	0x10
	movwf	bulk_blue
	return
	
_pallet_cycle_not_blue
	movf	ann_seq1, W
	xorlw	0x01
	btfss	STATUS, Z
	goto	_pallet_cycle_not_green
	clrf	bulk_red
	movlw	0x10
	movwf	bulk_green
	clrf	bulk_blue
	return
	
_pallet_cycle_not_green	
	movf	ann_seq1, W
	xorlw	0x02
	btfss	STATUS, Z
	goto	_pallet_cycle_not_red
	movlw	0x10
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	return
	
_pallet_cycle_not_red	
	movf	ann_seq1, W
	xorlw	0x03
	btfss	STATUS, Z
	goto	_pallet_cycle_not_yellow
	movlw	0x10
	movwf	bulk_red
	movwf	bulk_green
	clrf	bulk_blue
	return

_pallet_cycle_not_yellow
	movf	ann_seq1, W
	xorlw	0x04
	btfss	STATUS, Z
	goto	_pallet_cycle_not_pur
	movlw	0x10
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	return
	
_pallet_cycle_not_pur
	movf	ann_seq1, W
	xorlw	0x05
	btfss	STATUS, Z
	goto	_pallet_cycle_not_org
	movlw	0x10
	movwf	bulk_red
	movlw	0x04
	movwf	bulk_green
	clrf	bulk_blue
	return

_pallet_cycle_not_org
	movlw	0x10
	movwf	bulk_red
	movlw	0x04
	movwf	bulk_green
	movwf	bulk_blue
	return

	
;################################################################################
; Based on ann_seq1 return RGB values for current step of rainbow seq
;################################################################################
_rainbow_cycle
	
	movlw	0x66				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1

	; full red green up
	movlw	0x11				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	goto	_rainbow_cycle0

	movlw	0xFF
	movwf	bulk_red
	movf	ann_seq1, W
	movwf	bulk_green
	clrf	bulk_blue
	return
	
_rainbow_cycle0
	; red down full green
	movlw	0x22				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	goto	_rainbow_cycle1

	movlw	0x11
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	sublw	0x10				; k - W, C = 0 if W > k, C = 1 if W <= k
	movwf	bulk_red
	movlw	0xff
	movwf	bulk_green
	clrf	bulk_blue
	return

_rainbow_cycle1
	; full green blue up
	movlw	0x33				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	goto	_rainbow_cycle2

	clrf	bulk_red
	movlw	0xFF
	movwf	bulk_green
	movlw	0x22
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	movwf	bulk_blue
	return

_rainbow_cycle2
	; green down full blue
	movlw	0x44				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	goto	_rainbow_cycle3

	clrf	bulk_red
	movlw	0x33
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	sublw	0x10				; k - W, C = 0 if W > k, C = 1 if W <= k
	movwf	bulk_green
	movlw	0xff
	movwf	bulk_blue
	return

_rainbow_cycle3
	; full blue red up
	movlw	0x55				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	goto	_rainbow_cycle4

	movlw	0x44
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	movwf	bulk_red
	clrf	bulk_green
	movlw	0xFF
	movwf	bulk_blue
	return

_rainbow_cycle4
	; full red blue down
	movlw	0x66				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	return

	movlw	0xFF
	movwf	bulk_red
	clrf	bulk_green
	movlw	0x55
	subwf	ann_seq1, W			; f - W, C = 0 if W > F, C = 1 W <= F
	sublw	0x10				; k - W, C = 0 if W > k, C = 1 if W <= k
	movwf	bulk_blue
	return	
	

;################################################################################
; cycle the LFSR (sudo random) generator 8 bits and return the new result in W
;################################################################################
_CYCLE_LFSR
	movlw	0x08
	movwf	LFSR_count
cycle_lfsr_loop
	; seed register with inial value
	bcf		temp, 0
	btfsc	LFSR_0, 0
	bsf		temp, 0
	; test bit invert result if set
	btfsc	LFSR_0, 2
	comf	temp, f
	; test bit invert result if set
	btfsc	LFSR_0, 6
	comf	temp, f
	; test bit invert result if set
	btfsc	LFSR_0, 7
	comf	temp, f
	
	; set carry bit
	bcf		STATUS, C
	btfsc	temp, 0
	bsf		STATUS, C
	
	; rotat the bits 
	rrf		LFSR_3, F
	rrf		LFSR_2, F
	rrf		LFSR_1, F
	rrf		LFSR_0, F
	decfsz	LFSR_count, F
	goto	cycle_lfsr_loop
	movf	LFSR_0, W
	return

;################################################################################
; compress clearing the RGB vars
;################################################################################
_clear_RGB
	clrf	bulk_red
	clrf	bulk_blue
	clrf	bulk_green
	return
	
;################################################################################
; Based on ann_seq3 sets one of the inner ring LEDs to stored RGB values
;################################################################################
_rotate_set_inner_ring
	
	movlw	0x03				; if greater than 2 rest to 0
	subwf	ann_seq3, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq3
	
	movf	ann_seq3, W
	btfss	STATUS, Z
	goto	_rotate_set_inner_ring1
	movf	bulk_red, W
	movwf	led8r
	movf	bulk_green, W
	movwf	led8g
	movf	bulk_blue, W
	movwf	led8b
	return
	
_rotate_set_inner_ring1	
	movf	ann_seq3, W
	xorlw	0x01
	btfss	STATUS, Z
	goto	_rotate_set_inner_ring2
	movf	bulk_red, W
	movwf	led9r
	movf	bulk_green, W
	movwf	led9g
	movf	bulk_blue, W
	movwf	led9b
	return
	
_rotate_set_inner_ring2
	movf	bulk_red, W
	movwf	led15r
	movf	bulk_green, W
	movwf	led15g
	movf	bulk_blue, W
	movwf	led15b
	return
	
	return

;################################################################################
; Based on ann_seq3 sets one of the inner ring LEDs to stored RGB values
;################################################################################
_rotate_set_inner_ring_ccw
	
	movlw	0x03				; if greater than 2 rest to 0
	subwf	ann_seq3, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq3
	
	movf	ann_seq3, W
	btfss	STATUS, Z
	goto	_rotate_set_inner_ring_ccw1
	movf	bulk_red, W
	movwf	led15r
	movf	bulk_green, W
	movwf	led15g
	movf	bulk_blue, W
	movwf	led15b
	return
	
_rotate_set_inner_ring_ccw1	
	movf	ann_seq3, W
	xorlw	0x01
	btfss	STATUS, Z
	goto	_rotate_set_inner_ring_ccw2
	movf	bulk_red, W
	movwf	led9r
	movf	bulk_green, W
	movwf	led9g
	movf	bulk_blue, W
	movwf	led9b
	return
	
_rotate_set_inner_ring_ccw2
	movf	bulk_red, W
	movwf	led8r
	movf	bulk_green, W
	movwf	led8g
	movf	bulk_blue, W
	movwf	led8b
	return
	
	return
	
;################################################################################
; Based on ann_seq2 sets one of the outer ring LEDs to stored RGB values
;################################################################################
_rotate_set_outer_ring	
	
	movlw	0x0C				; if greater than 12 rest to 0
	subwf	ann_seq2, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq2
	
	movf	ann_seq2, W
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring1
	movf	bulk_red, W
	movwf	led1r
	movf	bulk_green, W
	movwf	led1g
	movf	bulk_blue, W
	movwf	led1b
	return
	
_rotate_set_outer_ring1	
	movf	ann_seq2, W
	xorlw	0x01
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring2
	movf	bulk_red, W
	movwf	led2r
	movf	bulk_green, W
	movwf	led2g
	movf	bulk_blue, W
	movwf	led2b
	return
	
_rotate_set_outer_ring2
	movf	ann_seq2, W
	xorlw	0x02
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring3
	movf	bulk_red, W
	movwf	led3r
	movf	bulk_green, W
	movwf	led3g
	movf	bulk_blue, W
	movwf	led3b
	return

_rotate_set_outer_ring3
	movf	ann_seq2, W
	xorlw	0x03
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring4
	movf	bulk_red, W
	movwf	led4r
	movf	bulk_green, W
	movwf	led4g
	movf	bulk_blue, W
	movwf	led4b
	return

_rotate_set_outer_ring4
	movf	ann_seq2, W
	xorlw	0x04
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring5
	movf	bulk_red, W
	movwf	led5r
	movf	bulk_green, W
	movwf	led5g
	movf	bulk_blue, W
	movwf	led5b
	return

_rotate_set_outer_ring5
	movf	ann_seq2, W
	xorlw	0x05
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring6
	movf	bulk_red, W
	movwf	led10r
	movf	bulk_green, W
	movwf	led10g
	movf	bulk_blue, W
	movwf	led10b
	return

_rotate_set_outer_ring6
	movf	ann_seq2, W
	xorlw	0x06
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring7
	movf	bulk_red, W
	movwf	led18r
	movf	bulk_green, W
	movwf	led18g
	movf	bulk_blue, W
	movwf	led18b
	return

_rotate_set_outer_ring7
	movf	ann_seq2, W
	xorlw	0x07
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring8
	movf	bulk_red, W
	movwf	led17r
	movf	bulk_green, W
	movwf	led17g
	movf	bulk_blue, W
	movwf	led17b
	return

_rotate_set_outer_ring8
	movf	ann_seq2, W
	xorlw	0x08
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring9
	movf	bulk_red, W
	movwf	led16r
	movf	bulk_green, W
	movwf	led16g
	movf	bulk_blue, W
	movwf	led16b
	return

_rotate_set_outer_ring9
	movf	ann_seq2, W
	xorlw	0x09
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring10
	movf	bulk_red, W
	movwf	led14r
	movf	bulk_green, W
	movwf	led14g
	movf	bulk_blue, W
	movwf	led14b
	return
	
_rotate_set_outer_ring10	
	movf	ann_seq2, W
	xorlw	0x0a
	btfss	STATUS, Z
	goto	_rotate_set_outer_ring11
	movf	bulk_red, W
	movwf	led13r
	movf	bulk_green, W
	movwf	led13g
	movf	bulk_blue, W
	movwf	led13b
	return

_rotate_set_outer_ring11
	movf	bulk_red, W
	movwf	led7r
	movf	bulk_green, W
	movwf	led7g
	movf	bulk_blue, W
	movwf	led7b
	return
	
	return
	
;################################################################################
; Based on ann_seq1 return RGB values for 5 of 6 inf stone colors
;################################################################################
_inf5_cycle
	
	movlw	0x05				; if greater than 4 rest to 0
	subwf	ann_seq1, W			; C = 0 if W > F, C = 1 W <= F
	btfsc	STATUS, C	
	clrf	ann_seq1
	
	movf	ann_seq1, W
	btfss	STATUS, Z
	goto	_inf5_cycle_not_red
	movlw	0xFF
	movwf	bulk_red
	clrf	bulk_green
	clrf	bulk_blue
	return
	
_inf5_cycle_not_red	
	movf	ann_seq1, W
	xorlw	0x01
	btfss	STATUS, Z
	goto	_inf5_cycle_not_org
	movlw	0xFF
	movwf	bulk_red
	movlw	0x04
	movwf	bulk_green
	clrf	bulk_blue
	return

_inf5_cycle_not_org
	movf	ann_seq1, W
	xorlw	0x02
	btfss	STATUS, Z
	goto	_inf5_cycle_not_blu
	clrf	bulk_red
	clrf	bulk_green
	movlw	0xFF
	movwf	bulk_blue
	return

_inf5_cycle_not_blu
	movf	ann_seq1, W
	xorlw	0x03
	btfss	STATUS, Z
	goto	_inf5_cycle_not_pur
	movlw	0xFF
	movwf	bulk_red
	clrf	bulk_green
	movwf	bulk_blue
	return
	
_inf5_cycle_not_pur
	clrf	bulk_red
	movlw	0xFF
	movwf	bulk_green
	clrf	bulk_blue
	return
	
;################################################################################
; Turn off all LEDs
;################################################################################
_clear_all
	clrf	FSR1H				; set up indirect register to start of led bank
	movlw	led1r				; start of LED regs
	movwf	FSR1L
_clear_all_loop
	movlw	0x00
	; if doing single LED updates the last led (blue 18) will not get updated with current logic (stops one short) Updating tripplets avoids this issue. 
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movlw	led18b				; address of last LED reg
	subwf	FSR1L, W			; C = 0 if W > F, C = 1 W <= F
	btfss	STATUS, C	
	goto	_clear_all_loop
	
	return
	
;################################################################################
; set all leds based on bulk_red, bulk_green, bulk_blue
;################################################################################
_set_all
	clrf	FSR1H				; set up indirect register to start of led bank
	movlw	led1r				; start of LED regs
	movwf	FSR1L
_set_all_loop
	movf	bulk_red, W
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movf	bulk_green, W
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movf	bulk_blue, W
	movwi	FSR1++				; special command on new pics. Moves W to the INDFx register then post incremetns the FSRx register by 1. Saves a instruction in this useage. 
	movlw	led18b				; address of last LED reg
	subwf	FSR1L, W			; C = 0 if W > F, C = 1 W <= F
	btfss	STATUS, C	
	goto	_set_all_loop
	
	return
		
;################################################################################
; this function sets up timer 0 which is used as a animation step delay
; it is non blocking so the micro can set in a fast idle loop looking for mode button presses during delays
; under current configuration you can have delays from 0.017s to ~4.2s in 256 steps (0.017s per step) 
;################################################################################
_delay
	movwf	gtemp				; save the W reg off for later use
	
	;------------------
	movlw	d'14'
	movwf	BSR		
	;------------------
	bcf		PIR0, 5				; clear timer 0 flag
	
	;------------------
	movlw	d'11'
	movwf	BSR		
	;------------------	
	comf	gtemp,W				; invert then load delay value to timer (timer counts up so a smaller number is a longer delay) 
	movwf	TMR0H
	clrf	TMR0L				; preset the timer value for half sec delay (I hope)
	movlw	0x91			
	movwf	T0CON1				; LFINTOSC (31kHz) clock input, no sync, 1:2 prescale
	movlw	0x90				
	movwf	T0CON0				; timer on, 16 bit, no postscale	
		
	;------------------
	clrf	BSR		
	;------------------
	
	return
	

;################################################################################
; this function contains the special unlock sequence to start a flash write or clear. 
;################################################################################
_unlock_flash
	bcf		INTCON, GIE		    ; disable ints (required as the next commands MUST be sequential
	movlw	0x55				; flash unlock key
	movwf	NVMCON2
	movlw	0xAA
	movwf	NVMCON2
	bsf		NVMCON1, WR			; start the write or clear
	bsf		INTCON, GIE		    ; restart ints
	return	
	
	
; stuff in the 	code description at the bottom of the code. 
	de	CODE_VER_STRING
	
; </spaghetti> 
	;### end of program ###
	end	

