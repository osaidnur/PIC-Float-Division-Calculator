PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"


; --- VARIABLES ---
    CBLOCK 0x20
        delay_ms_count
        blink_counter
        temp_char
        current_digit_value   ; Binary value of digit (0–9)
        digit_cursor_pos      ; Current digit index (0 to 5)
        digit_array0
        digit_array1
        digit_array2
        digit_array3
        digit_array4
        digit_array5
        digit_array6
        digit_array7
        digit_array8
        digit_array9
        digit_array10
        digit_array11

    ENDC

pushButton EQU 0 ;the pin zero of portB


	ORG	0x00		; Default start address 
	GOTO start		;go to that label....


	ORG 0x04
    GOTO ISR_pushButton       ; Interrupt Service Routine jump


;----------------------------------------MAIN-------------------------------------------------------------
start
	NOP			; required for ICD mode

	BANKSEL	TRISD
	MOVLW	B'00000000' 	;1 for input, 0 for output.
	MOVWF 	TRISD 
	MOVLW 	B'00000001'		;make the push button as input...
	MOVWF 	TRISB
	;this sets all bins in the d port to be output.
	;the registor of the interupt is in the same bank
	BANKSEL	OPTION_REG
    BCF OPTION_REG, INTEDG  ; 0 = interrupt on falling edge
	BANKSEL INTCON
	BSF INTCON, INTE    ; Enable external interrupt (RB0/INT) ; it is in the same bank.
	BSF INTCON, GIE     ; Enable all unmasked interrupts ;If it zero, interupts will be globally disabled.
	BCF     INTCON, INTF     ; Clear any pending INT interrupt


	BANKSEL PORTD 	;go back to bank0 which has the value of the d ports.
	CLRF PORTD 		;clear all the pins.. set zero as output.
;----
	; Initialize variables
    clrf digit_cursor_pos
    clrf    digit_array0
    clrf    digit_array1
    clrf    digit_array2
    clrf    digit_array3
    clrf    digit_array4
    clrf    digit_array5
    clrf    digit_array6
    clrf    digit_array7
    clrf    digit_array8
    clrf    digit_array9
    clrf    digit_array10
    clrf    digit_array11
    clrf current_digit_value
;-----
	CALL inid 			;calls inid method to initialize the lcd, this method is inside LCDIS.INC
  	;then print the welcomming page.....
	CALL print_welcome

	movlw   .3
    movwf   blink_counter
blink_loop:
	CALL   delay_500ms
    MOVLW  0x08  				; turns the screen off
    CALL lcd_cmd
    CALL   delay_500ms
	MOVLW  0x0c 				 ; turns the screen on.
    CALL lcd_cmd				;this is a one blink, off then on
	decfsz  blink_counter, 1 	;decrement the counter by one, if it zero, skip the next instruction.
    goto    blink_loop
    
	;now i want to make a delay of two seconds, then move to the next step.
	CALL delay_500ms
	CALL delay_500ms	
	CALL delay_500ms
	CALL delay_500ms
	;---
	CALL show_the_first_num
		
GOTO done
 INCLUDE "LCDIS.INC"
;------------------------SUBROTUINE------------------------------------------------------------------------------------
ISR_pushButton:

	RETFIE


lcd_data:
	BSF Select,RS
	CALL send
	RETURN

lcd_cmd:
	BCF Select,RS
	CALL send
	RETURN


print_welcome:
	MOVLW 0x80			;LCD command to make the cursor at the 1st line.
    CALL lcd_cmd        ; Send command to LCD, this subroutine is in LCDIS.INC

	MOVLW 'W'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD

    MOVLW 'e'    	 ; Load character to display
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'l'    	 ; Load character to display 		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'c'    	 ; Load character to display		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'o'    	 ; Load character to display	 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'm'    	 ; Load character to display	 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'e'    	 ; Load character to display	 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW ' '    	 ; Load character to display		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 't'    	 ; Load character to display	 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'o'    	 ; Load character to display
    CALL lcd_data        ; Call subroutine to send data to LCD


	MOVLW 0xc0			;LCD command to make the cursor at the 2st line.
    CALL lcd_cmd       ; Send command to LCD, this subroutine is in LCDIS.INC

	MOVLW 'D'   	 ; Load character to display
    CALL lcd_data        ; Call subroutine to send data to LCD

    MOVLW 'i'    	 ; Load character to display 		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'v'    	 ; Load character to display	 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'i'    	 ; Load character to display		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'o'    	 ; Load character to display		 
    CALL lcd_data        ; Call subroutine to send data to LCD

	MOVLW 'n'    	 ; Load character to display		 
    CALL lcd_data        ; Call subroutine to send data to LCD
RETURN

show_the_first_num:
	movlw   0x01
    call    lcd_cmd
    movlw   0x0F          ; Cursor ON, Blink ON
    call    lcd_cmd
	
	MOVLW 'N'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	
	MOVLW 'u'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 'm'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 'b'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 'e'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 'r'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW ' '   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW '1'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 0xc0
	CALL lcd_cmd
	
	CALL display_all_digits
	RETURN


display_all_digits:
  	movf    digit_array0, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array3, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array4, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array5, 0
    addlw   '0'
    call    lcd_data
	MOVLW '.'
	CALL lcd_data
    movf    digit_array6, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array7, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array8, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array9, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array10, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array11, 0
    addlw   '0'
    call    lcd_data
    RETURN


position_cursor:
    movf    digit_cursor_pos, 0
    addlw   0xC0
    call    lcd_cmd
    return


;------------------------------------------------------------------------

delay_500ms:
    movlw .250
    call delay_ms
    movlw .250
    call delay_ms
    return

delay_20ms:
    movlw .20
    call delay_ms
    return

delay_5ms:
    movlw .5
    call delay_ms
    return

delay_1ms:
    movlw .1
    call delay_ms
    return

delay_ms:
    movwf delay_ms_count
ms_loop:
    movlw 0xC7
    movwf temp_char
us_loop:
    decfsz temp_char, 1
    goto us_loop
    decfsz delay_ms_count, 1
    goto ms_loop
    return






done:
    SLEEP
    GOTO done
END