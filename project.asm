PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"


; --- VARIABLES ---
    CBLOCK 0x20
        delay_ms_count
        blink_counter
        temp_char
        current_digit_value   ; Binary value of digit (0–9)
        digit_cursor_pos      ; Current digit index (0 to 12), 6 is the decimal point position
        digit_array1_0
        digit_array1_1
        digit_array1_2
        digit_array1_3
        digit_array1_4
        digit_array1_5
        digit_array1_6
        digit_array1_7
        digit_array1_8
        digit_array1_9
        digit_array1_10
        digit_array1_11
        digit_array2_0
        digit_array2_1
        digit_array2_2
        digit_array2_3
        digit_array2_4
        digit_array2_5
        digit_array2_6
        digit_array2_7
        digit_array2_8
        digit_array2_9        
        digit_array2_10
        digit_array2_11
        timer1_enabled        ; Flag to track if Timer1 is enabled
        button_first_press    ; Flag to track first button press
        screen1
        ; USART variables for communication with slave PIC
        transmit_index        ; Index for transmitting digits (0-11)
        number_transmitted    ; Flag to track if first number was transmitted

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
    
    ; Configure USART pins for communication with slave PIC
    ; USART = Universal Synchronous Asynchronous Receiver Transmitter
    ; RC6 = TX (Transmit) pin - sends data to slave PIC
    ; RC7 = RX (Receive) pin - receives data from slave PIC
    BANKSEL TRISC
    BCF     TRISC, 6        ; RC6/TX pin as output (transmit to slave)
    BSF     TRISC, 7        ; RC7/RX pin as input (receive from slave)
    
    BANKSEL	OPTION_REG
    BCF OPTION_REG, INTEDG  ; 0 = interrupt on falling edge
	
	; Configure Timer1 for 1 second interrupt (but don't enable yet)
	BANKSEL T1CON
	MOVLW   B'00110000'     ; Timer1 prescaler 1:8, Timer1 oscillator disabled, internal clock
	MOVWF   T1CON           ; Timer1 control register (Timer1 disabled initially)
		
	
	; Configure Timer1 interrupt (but don't enable yet)
	BANKSEL PIE1
	BCF PIE1, TMR1IE    ; Timer1 interrupt disabled initially
	BANKSEL PIR1
	BCF PIR1, TMR1IF    ; Clear Timer1 interrupt flag

    ; Initialize USART for communication with slave PIC
    ; This sets up the hardware for serial communication
    CALL    init_master_usart

	BANKSEL PORTD 	;go back to bank0 which has the value of the d ports.
	CLRF PORTD 		;clear all the pins.. set zero as output.
;----
	; Initialize variables
    clrf digit_cursor_pos
    clrf    digit_array1_0
    clrf    digit_array1_1
    clrf    digit_array1_2
    clrf    digit_array1_3
    clrf    digit_array1_4
    clrf    digit_array1_5
    clrf    digit_array1_6
    clrf    digit_array1_7
    clrf    digit_array1_8
    clrf    digit_array1_9
    clrf    digit_array1_10    
    clrf    digit_array1_11
    clrf    digit_array2_0
    clrf    digit_array2_1
    clrf    digit_array2_2
    clrf    digit_array2_3
    clrf    digit_array2_4
    clrf    digit_array2_5
    clrf    digit_array2_6
    clrf    digit_array2_7
    clrf    digit_array2_8
    clrf    digit_array2_9
    clrf    digit_array2_10    
    clrf    digit_array2_11
    clrf    current_digit_value
    clrf    timer1_enabled      ; Timer1 not enabled initially
    clrf    button_first_press  ; No button press detected yet
    clrf    screen1
    ; Initialize USART variables
    clrf    transmit_index      ; Start transmitting from first digit
    clrf    number_transmitted  ; First number not transmitted yet
;-----
	CALL    inid 			;calls inid method to initialize the lcd, this method is inside LCDIS.INC
  	;then print the welcomming page.....
	CALL    print_welcome

	movlw    .3
    movwf    blink_counter
blink_loop:
	CALL    delay_500ms
    MOVLW   0x08  				; turns the screen off
    CALL    lcd_cmd
    CALL    delay_500ms
	MOVLW   0x0c 				 ; turns the screen on.
    CALL    lcd_cmd				;this is a one blink, off then on
	decfsz  blink_counter, 1 	;decrement the counter by one, if it zero, skip the next instruction.
    goto    blink_loop
    
	;now i want to make a delay of two seconds, then move to the next step.
	CALL    delay_500ms
	CALL    delay_500ms	
	CALL    delay_500ms
	CALL    delay_500ms
	;---
	CALL    show_the_first_num
    BANKSEL INTCON
	BSF INTCON, INTE    ; Enable external interrupt (RB0/INT)
	BSF INTCON, PEIE    ; Enable peripheral interrupts
	BSF INTCON, GIE     ; Enable all unmasked interrupts
	BCF INTCON, INTF    ; Clear any pending INT interrupt

main_loop:
	; Main loop - just wait for interrupts
	; The ISR will handle button presses and digit increments
	goto main_loop
		
GOTO done
 INCLUDE "LCDIS.INC"
;------------------------SUBROTUINE------------------------------------------------------------------------------------
ISR_pushButton:
    ; The logic is this: when the button is pressed, it will increment the digit that I'm currently at, 
    ; I can access it from the position of the cursor, which is stored in the digit_cursor_pos variable.

    ; Let's first implement the logic of incrementing the digit.
    ; The cursor, in the first time, is at the first digit, which is the 0th digit.
    
    ; Save W register context
    movwf   temp_char
    
    ; Clear the interrupt flag to avoid re-entering the ISR immediately
    BCF     INTCON, INTF
    

    ; Simple debounce
    call    debounce
    ; Check if button is still pressed (active low)
    btfsc   PORTB, pushButton
    goto    isr_exit            ; Button not pressed, false trigger
    ; if the button is still pressed, i want to wait for 500ms and then check again, if still pressed, move the cursor.
    CALL delay_500ms; i know that the ISR must be short, but i don't want to use timers and make it harder.
    btfsc   PORTB, pushButton
    goto    shortPulse
    ;else long pulse.
    goto   longPulse

shortPulse:
    ; Increment the digit at current cursor position
    movlw   .1
    subwf   screen1, 0
    btfss   STATUS, Z ; Check if this is the first screen
    goto    screen1_increment
    ; else we are in screen 2
    call    increment_current_digit_2 ; Increment the digit at current cursor position
    goto    point1
screen1_increment:
    call    increment_current_digit_1
    ; Update the display to show the new digit

point1:
    movlw   .1
    subwf   screen1, 0
    btfss   STATUS, Z ; Check if this is the first screen
    goto    screen1_display
    ; else we are in screen 2
    call    update_single_digit_display_2 ; Update the display to show the new digit
    goto    isr_exit ; Exit ISR after updating display
screen1_display:
    call    update_single_digit_display_1
    goto    isr_exit ; Exit ISR after updating display

longPulse:
    ;move the cursor to the next digit
    incf    digit_cursor_pos, 1 ; Move to next digit
    ; If the cursor position exceeds the last digit, move to NUMBER 2.
    ;now i want to check, if the cursor is at the 6th digit, which is the decimal point, i want to skip it.
    movlw   0x06
    subwf   digit_cursor_pos, 0 ; Check if cursor is at decimal point
    btfsc   STATUS, Z           ; If cursor is at decimal point (Z==1), increment again, if z=0 (sub res is not 0) skip.
    incf    digit_cursor_pos, 1 ; Skip decimal point
    ; If the cursor position exceeds the last digit, do job that i will do later.
    movlw   0x0D                ; Last digit position (12)
    subwf   digit_cursor_pos, 0 ; Check if cursor exceeds last digit
    btfsc   STATUS, Z           ; If cursor is at last digit, do nothing for now.
    CALL show_the_second_num_and_transmit ;i want to fix it after, i want to make it go to the second number.; need to check also
    ;if i'm in the second screen don't print the second num, no, calculate the result and print it.
    ;else update the display, then exit

    movlw   .1
    subwf   screen1, 0
    btfss   STATUS, Z ; Check if this is the first screen
    goto    screen1_cursor
    ; else we are in screen 2
    call    update_single_digit_display_2 ; Update display with new digit
    goto    isr_exit ; Exit ISR after updating display
screen1_cursor:
    call    update_single_digit_display_1 ; Update display with new digit
    ; Reposition cursor for blinking
isr_exit:
    ; Restore W register context
    movf    temp_char, 0
    RETFIE



;-------------------------Subroutines------------------------------------

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
	
	CALL display_all_digits_1
	CALL position_cursor        ; Position cursor at first digit
	RETURN

show_the_second_num:

	movlw   0x01
    movwf screen1 ; make this var = 1, so i know that i am in the second screen.
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
    MOVLW '2'   	 ; Load character to display	 
    CALL lcd_data       ; Call subroutine to send data to LCD
	MOVLW 0xc0
	CALL lcd_cmd
	
    ;clear digit_cursor_pos variable
    clrf    digit_cursor_pos
	CALL display_all_digits_2
	CALL position_cursor        ; Position cursor at first digit
	RETURN


display_all_digits_1:
  	movf    digit_array1_0, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_1, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_2, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_3, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_4, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_5, 0
    addlw   '0'
    call    lcd_data
	MOVLW '.'
	CALL lcd_data
    movf    digit_array1_6, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_7, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_8, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_9, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_10, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array1_11, 0
    addlw   '0'
    call    lcd_data
	MOVLW 0xc0
	CALL lcd_cmd
    RETURN



display_all_digits_2:
  	movf    digit_array2_0, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_1, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_2, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_3, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_4, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_5, 0
    addlw   '0'
    call    lcd_data
	MOVLW '.'
	CALL lcd_data
    movf    digit_array2_6, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_7, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_8, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_9, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_10, 0
    addlw   '0'
    call    lcd_data
    movf    digit_array2_11, 0
    addlw   '0'
    call    lcd_data
	MOVLW 0xc0
	CALL lcd_cmd
    RETURN


position_cursor:
    movf    digit_cursor_pos, 0
    addlw   0xC0
    call    lcd_cmd
    return


;------------------------DIGIT MANIPULATION FUNCTIONS------------------------------------------------------------------------------------

increment_current_digit_1:
    ; Get pointer to current digit using FSR (File Select Register)
    movf    digit_cursor_pos, 0
    ; If cursor position is 7 or higher, subtract 1 to account for skipped decimal point
    sublw   .6                  ; Compare cursor position with 6
    btfss   STATUS, C           ; If cursor_pos > 6 (carry clear), adjust index
    goto    adjust_index_1
    ; Cursor position is 0-5, use directly
    movf    digit_cursor_pos, 0
    addlw   digit_array1_0
    movwf   FSR
    goto    increment_digit_1
adjust_index_1:
    ; Cursor position is 7-12, map to array indices 6-11
    movf    digit_cursor_pos, 0
    addlw   .255                ; Subtract 1 (add -1 = add 255)
    addlw   digit_array1_0
    movwf   FSR
increment_digit_1:
    ; Increment the digit (0-9 cycle)
    incf    INDF, 1             ; Increment digit at FSR address
    movf    INDF, 0             ; Load current value
    sublw   .10                 ; Compare with 10
    btfsc   STATUS, Z           ; If equal to 10
    clrf    INDF                ; Reset to 0
    
    return


increment_current_digit_2:
    ; Get pointer to current digit using FSR (File Select Register)
    movf    digit_cursor_pos, 0
    ; If cursor position is 7 or higher, subtract 1 to account for skipped decimal point
    sublw   .6                  ; Compare cursor position with 6
    btfss   STATUS, C           ; If cursor_pos > 6 (carry clear), adjust index
    goto    adjust_index_2
    ; Cursor position is 0-5, use directly
    movf    digit_cursor_pos, 0
    addlw   digit_array2_0
    movwf   FSR
    goto    increment_digit_2
adjust_index_2:
    ; Cursor position is 7-12, map to array indices 6-11
    movf    digit_cursor_pos, 0
    addlw   .255                ; Subtract 1 (add -1 = add 255)
    addlw   digit_array2_0
    movwf   FSR
increment_digit_2:
    ; Increment the digit (0-9 cycle)
    incf    INDF, 1             ; Increment digit at FSR address
    movf    INDF, 0             ; Load current value
    sublw   .10                 ; Compare with 10
    btfsc   STATUS, Z           ; If equal to 10
    clrf    INDF                ; Reset to 0
    
    return

update_single_digit_display_1:
    ; Calculate LCD position for current digit
    movf    digit_cursor_pos, 0
    addlw   0xC0                ; Second line base address
    call    lcd_cmd             ; Position cursor
    
    ; Get current digit value and display it
    movf    digit_cursor_pos, 0
    ; If cursor position is 7 or higher, subtract 1 to account for skipped decimal point
    sublw   .6                  ; Compare cursor position with 6
    btfss   STATUS, C           ; If cursor_pos > 6 (carry clear), adjust index
    goto    adjust_display_index_1
    ; Cursor position is 0-5, use directly
    movf    digit_cursor_pos, 0
    addlw   digit_array1_0
    movwf   FSR
    goto    display_digit_1
adjust_display_index_1:
    ; Cursor position is 7-12, map to array indices 6-11
    movf    digit_cursor_pos, 0
    addlw   .255                ; Subtract 1 (add -1 = add 255)
    addlw   digit_array1_0
    movwf   FSR
display_digit_1:
    movf    INDF, 0             ; Get digit value
    addlw   '0'                 ; Convert to ASCII
    call    lcd_data            ; Display the digit
    
    ; Reposition cursor for blinking
    movf    digit_cursor_pos, 0
    addlw   0xC0
    call    lcd_cmd
    
    return


update_single_digit_display_2:
    ; Calculate LCD position for current digit
    movf    digit_cursor_pos, 0
    addlw   0xC0                ; Second line base address
    call    lcd_cmd             ; Position cursor
    
    ; Get current digit value and display it
    movf    digit_cursor_pos, 0
    ; If cursor position is 7 or higher, subtract 1 to account for skipped decimal point
    sublw   .6                  ; Compare cursor position with 6
    btfss   STATUS, C           ; If cursor_pos > 6 (carry clear), adjust index
    goto    adjust_display_index_2
    ; Cursor position is 0-5, use directly
    movf    digit_cursor_pos, 0
    addlw   digit_array2_0
    movwf   FSR
    goto    display_digit_2
adjust_display_index_2:
    ; Cursor position is 7-12, map to array indices 6-11
    movf    digit_cursor_pos, 0
    addlw   .255                ; Subtract 1 (add -1 = add 255)
    addlw   digit_array2_0
    movwf   FSR
display_digit_2:
    movf    INDF, 0             ; Get digit value
    addlw   '0'                 ; Convert to ASCII
    call    lcd_data            ; Display the digit
    
    ; Reposition cursor for blinking
    movf    digit_cursor_pos, 0
    addlw   0xC0
    call    lcd_cmd
    
    return

debounce:
    ; Simple debounce delay
    movlw   .10
    call    delay_ms
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

delay_700ms:
    ; 700ms delay using existing delay functions
    ; 700ms = 500ms + 200ms
    call    delay_500ms
    movlw   .200
    call    delay_ms
    return

delay_300ms:
    ; 300ms delay using existing delay functions
    ; 300ms = 250ms + 50ms
    movlw   .250
    call    delay_ms
    movlw   .50
    call    delay_ms
    return




done:
    SLEEP
    GOTO done

;----------------------------------------USART COMMUNICATION SUBROUTINES-------------------------------------------------------------

init_master_usart:
    ; Initialize USART for 9600 baud rate communication
    ; USART allows two PICs to communicate by sending data one byte at a time
    ; 9600 baud = 9600 bits per second (standard speed for PIC communication)
    
    BANKSEL SPBRG
    MOVLW   .25             ; Baud rate generator value for 9600 baud at 4MHz crystal
    MOVWF   SPBRG           ; Set the communication speed
    
    BANKSEL TXSTA
    BCF     TXSTA, SYNC     ; Use asynchronous mode (no clock signal needed)
    BSF     TXSTA, TXEN     ; Enable the transmitter hardware
    
    BANKSEL RCSTA  
    BSF     RCSTA, SPEN     ; Enable the serial port hardware
    
    RETURN

show_the_second_num_and_transmit:
    ; This function does two things:
    ; 1. Shows the second number input screen
    ; 2. Transmits the first number to slave PIC via USART
    
    ; First, check if we haven't transmitted the first number yet
    MOVF    number_transmitted, 0
    SUBLW   .0                      ; Check if number_transmitted == 0
    BTFSS   STATUS, Z               ; If not zero, skip transmission
    GOTO    just_show_second_num    ; Already transmitted, just show second number
    
    ; Transmit the first number to slave PIC
    CALL    transmit_first_number_to_slave
    
    ; Mark that we've transmitted the first number
    MOVLW   .1
    MOVWF   number_transmitted
    
just_show_second_num:
    CALL    show_the_second_num     ; Show the second number input screen
    RETURN

transmit_first_number_to_slave:
    ; This function sends all 12 digits of the first number to the slave PIC
    ; Each digit is sent as a separate byte through USART
    
    CLRF    transmit_index          ; Start from first digit (index 0)
    
transmit_loop:
    ; Get the current digit to transmit using indirect addressing
    MOVF    transmit_index, 0
    ADDLW   digit_array1_0          ; Calculate address of digit
    MOVWF   FSR                     ; Point FSR to the digit
    MOVF    INDF, 0                 ; Get the digit value (0-9)
    
    ; Send this digit to slave PIC
    CALL    usart_send_byte
    
    ; Small delay between transmissions to ensure slave can process
    CALL    delay_5ms
    
    ; Move to next digit
    INCF    transmit_index, 1
    
    ; Check if we sent all 12 digits
    MOVF    transmit_index, 0
    SUBLW   .12                     ; Compare with 12
    BTFSS   STATUS, Z               ; If not equal to 12, continue
    GOTO    transmit_loop           ; Send next digit
    
    RETURN

usart_send_byte:
    ; This function sends one byte (the digit in W register) to slave PIC
    ; W register contains the digit value (0-9) to send
    
    BANKSEL TXSTA
    BTFSS   TXSTA, TRMT            ; Check if transmit register is empty
    GOTO    $-1                    ; Wait until transmit register is empty
    
    BANKSEL TXREG
    MOVWF   TXREG                  ; Put the digit into transmit register
                                   ; Hardware automatically sends it to slave PIC
    
    RETURN

;------------------------------------------------------------------------
END