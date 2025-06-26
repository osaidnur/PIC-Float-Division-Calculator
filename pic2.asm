PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"

; --- SLAVE PIC VARIABLES ---
    CBLOCK 0x20
        temp_char
        received_digit      ; Single digit received from master
        digit_index         ; Index for storing received digits (0-11)
        ; Array to store the received 12-digit number
        slave_digit_array_0
        slave_digit_array_1
        slave_digit_array_2
        slave_digit_array_3
        slave_digit_array_4
        slave_digit_array_5
        slave_digit_array_6
        slave_digit_array_7
        slave_digit_array_8
        slave_digit_array_9
        slave_digit_array_10
        slave_digit_array_11
    ENDC

    ORG 0x00            ; Reset vector
    GOTO slave_start    ; Jump to main program

    ORG 0x04            ; Interrupt vector
    GOTO USART_ISR      ; Jump to USART interrupt handler

;----------------------------------------SLAVE MAIN PROGRAM-------------------------------------------------------------
slave_start:
    NOP                 ; Required for ICD mode

    ; Configure LCD pins (same as master)
    BANKSEL TRISD
    MOVLW   B'00000000' ; All PORTD pins as output for LCD
    MOVWF   TRISD

    ; Configure USART pins
    BANKSEL TRISC
    BSF     TRISC, 7    ; RC7/RX pin as input (receive)
    BCF     TRISC, 6    ; RC6/TX pin as output (transmit)

    ; Initialize USART for communication
    ; USART = Universal Synchronous Asynchronous Receiver Transmitter
    ; It's a hardware module that handles serial communication automatically
    CALL    init_usart

    ; Initialize LCD display
    BANKSEL PORTD
    CLRF    PORTD       ; Clear LCD port
    CALL    inid        ; Initialize LCD (from LCDIS.INC)

    ; Initialize variables
    CALL    init_slave_variables

    ; Display initial message
    CALL    display_slave_ready

    ; Enable interrupts for USART reception
    ; When data arrives at RX pin, an interrupt will occur automatically
    BANKSEL INTCON
    BSF     INTCON, PEIE    ; Enable peripheral interrupts
    BSF     INTCON, GIE     ; Enable global interrupts

slave_main_loop:
    ; Main loop - slave waits for data from master
    ; All work is done in the interrupt service routine
    GOTO    slave_main_loop

;----------------------------------------USART INTERRUPT SERVICE ROUTINE-------------------------------------------------------------
USART_ISR:
    ; This routine runs automatically when USART receives data
    ; Save context
    MOVWF   temp_char

    ; Check if this is a USART receive interrupt
    BANKSEL PIR1
    BTFSS   PIR1, RCIF      ; Check if receive interrupt flag is set
    GOTO    isr_exit        ; Not our interrupt, exit

    ; Read the received byte from USART buffer
    ; RCREG = Receive Register, contains the byte sent by master
    BANKSEL RCREG
    MOVF    RCREG, 0        ; Read received data into W register
    MOVWF   received_digit  ; Store received digit

    ; Store the digit in our array
    CALL    store_received_digit

    ; Check if we received all 12 digits
    MOVF    digit_index, 0
    SUBLW   .12             ; Compare with 12
    BTFSC   STATUS, Z       ; If we received 12 digits
    CALL    display_complete_number

isr_exit:
    ; Restore context and return from interrupt
    MOVF    temp_char, 0
    RETFIE

;----------------------------------------SUBROUTINES-------------------------------------------------------------

init_usart:
    ; Configure USART for 9600 baud rate communication
    ; Baud rate = speed of data transmission (bits per second)
    ; 9600 baud = 9600 bits per second (common speed for PIC communication)
    
    BANKSEL SPBRG
    MOVLW   .25             ; Baud rate generator value for 9600 baud at 4MHz
    MOVWF   SPBRG           ; Set baud rate
    
    BANKSEL TXSTA
    BCF     TXSTA, SYNC     ; Asynchronous mode (no clock signal needed)
    BSF     TXSTA, TXEN     ; Enable transmitter (in case we need to send back)
    
    BANKSEL RCSTA
    BSF     RCSTA, SPEN     ; Enable serial port
    BSF     RCSTA, CREN     ; Enable continuous receive
    
    ; Enable USART receive interrupt
    BANKSEL PIE1
    BSF     PIE1, RCIE      ; Enable receive interrupt
    BANKSEL PIR1
    BCF     PIR1, RCIF      ; Clear receive interrupt flag
    
    RETURN

init_slave_variables:
    ; Initialize all digit storage variables to 0
    CLRF    digit_index
    CLRF    slave_digit_array_0
    CLRF    slave_digit_array_1
    CLRF    slave_digit_array_2
    CLRF    slave_digit_array_3
    CLRF    slave_digit_array_4
    CLRF    slave_digit_array_5
    CLRF    slave_digit_array_6
    CLRF    slave_digit_array_7
    CLRF    slave_digit_array_8
    CLRF    slave_digit_array_9
    CLRF    slave_digit_array_10
    CLRF    slave_digit_array_11



    MOVLW   1
    MOVWF   slave_digit_array_0
    MOVLW   2
    MOVWF   slave_digit_array_1
    MOVLW   3
    MOVWF   slave_digit_array_2
    MOVLW   4
    MOVWF   slave_digit_array_3
    MOVLW   5
    MOVWF   slave_digit_array_4
    MOVLW   6
    MOVWF   slave_digit_array_5
    MOVLW   7
    MOVWF   slave_digit_array_6
    MOVLW   8
    MOVWF   slave_digit_array_7
    MOVLW   9
    MOVWF   slave_digit_array_8
    MOVLW   5
    MOVWF   slave_digit_array_9
    MOVLW   6
    MOVWF   slave_digit_array_10
    MOVLW   7
    MOVWF   slave_digit_array_11



    RETURN

display_slave_ready:
    ; Display message indicating slave is ready to receive
    MOVLW   0x01            ; Clear display
    CALL    lcd_cmd
    
    MOVLW   0x80            ; Position cursor at first line
    CALL    lcd_cmd
    
    ; Display "SLAVE READY"
    MOVLW   'S'
    CALL    lcd_data
    MOVLW   'L'
    CALL    lcd_data
    MOVLW   'A'
    CALL    lcd_data
    MOVLW   'V'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   ' '
    CALL    lcd_data
    MOVLW   'R'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   'A'
    CALL    lcd_data
    MOVLW   'D'
    CALL    lcd_data
    MOVLW   'Y'
    CALL    lcd_data
    
    MOVLW   0xC0            ; Position cursor at second line
    CALL    lcd_cmd
    
    MOVLW   'W'
    CALL    lcd_data
    MOVLW   'a'
    CALL    lcd_data
    MOVLW   'i'
    CALL    lcd_data
    MOVLW   't'
    CALL    lcd_data
    MOVLW   'i'
    CALL    lcd_data
    MOVLW   'n'
    CALL    lcd_data
    MOVLW   'g'
    CALL    lcd_data
    MOVLW   '.'
    CALL    lcd_data
    MOVLW   '.'
    CALL    lcd_data
    MOVLW   '.'
    CALL    lcd_data
    
    RETURN

store_received_digit:
    ; Store the received digit in the appropriate array position
    ; Use FSR (File Select Register) for indirect addressing
    MOVF    digit_index, 0
    ADDLW   slave_digit_array_0    ; Calculate address of array element
    MOVWF   FSR                    ; Point FSR to the array element
    
    MOVF    received_digit, 0      ; Get the received digit
    MOVWF   INDF                   ; Store it in the array using indirect addressing
    
    INCF    digit_index, 1         ; Move to next array position
    
    RETURN

display_complete_number:
    ; Clear the display and show the received number
    MOVLW   0x01            ; Clear display
    CALL    lcd_cmd
    
    MOVLW   0x80            ; Position cursor at first line
    CALL    lcd_cmd
    
    ; Display "RECEIVED:"
    MOVLW   'R'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   'C'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   'I'
    CALL    lcd_data
    MOVLW   'V'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   'D'
    CALL    lcd_data
    MOVLW   ':'
    CALL    lcd_data
    
    MOVLW   0xC0            ; Position cursor at second line
    CALL    lcd_cmd
    
    ; Display all 12 digits with decimal point after 6th digit
    CALL    display_received_digits
    
    ; Reset digit index for next reception
    CLRF    digit_index
    
    RETURN

display_received_digits:
    ; Display the complete number with decimal point
    MOVF    slave_digit_array_0, 0
    ADDLW   '0'             ; Convert digit to ASCII
    CALL    lcd_data
    
    MOVF    slave_digit_array_1, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_2, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_3, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_4, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_5, 0
    ADDLW   '0'
    CALL    lcd_data
    
    ; Add decimal point
    MOVLW   '.'
    CALL    lcd_data
    
    MOVF    slave_digit_array_6, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_7, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_8, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_9, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_10, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array_11, 0
    ADDLW   '0'
    CALL    lcd_data
    
    RETURN

;----------------------------------------LCD SUBROUTINES (using LCDIS.INC functions)-------------------------------------------------------------
lcd_data:
    BSF     Select, RS      ; RS = 1 for data (using Select variable from LCDIS.INC)
    CALL    send            ; Use send function from LCDIS.INC
    RETURN

lcd_cmd:
    BCF     Select, RS      ; RS = 0 for command (using Select variable from LCDIS.INC)
    CALL    send            ; Use send function from LCDIS.INC
    RETURN

INCLUDE "LCDIS.INC"

END
