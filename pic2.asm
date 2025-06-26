PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"

; --- SLAVE PIC VARIABLES ---
    CBLOCK 0x20
        temp_char
        received_digit      ; Single digit received from master
        digit_index         ; Index for storing received digits (0-11)
        current_number      ; Track which number we're receiving (1 or 2)
        ; Array to store the received first 12-digit number
        slave_digit_array1_0
        slave_digit_array1_1
        slave_digit_array1_2
        slave_digit_array1_3
        slave_digit_array1_4
        slave_digit_array1_5
        slave_digit_array1_6
        slave_digit_array1_7
        slave_digit_array1_8
        slave_digit_array1_9
        slave_digit_array1_10
        slave_digit_array1_11
        ; Array to store the received second 12-digit number
        slave_digit_array2_0
        slave_digit_array2_1
        slave_digit_array2_2
        slave_digit_array2_3
        slave_digit_array2_4
        slave_digit_array2_5
        slave_digit_array2_6
        slave_digit_array2_7
        slave_digit_array2_8
        slave_digit_array2_9
        slave_digit_array2_10
        slave_digit_array2_11
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
    CALL    handle_complete_number_received

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
    MOVLW   .1              ; Start with receiving first number
    MOVWF   current_number
    ; Initialize first number array
    CLRF    slave_digit_array1_0
    CLRF    slave_digit_array1_1
    CLRF    slave_digit_array1_2
    CLRF    slave_digit_array1_3
    CLRF    slave_digit_array1_4
    CLRF    slave_digit_array1_5
    CLRF    slave_digit_array1_6
    CLRF    slave_digit_array1_7
    CLRF    slave_digit_array1_8
    CLRF    slave_digit_array1_9
    CLRF    slave_digit_array1_10
    CLRF    slave_digit_array1_11
    ; Initialize second number array
    CLRF    slave_digit_array2_0
    CLRF    slave_digit_array2_1
    CLRF    slave_digit_array2_2
    CLRF    slave_digit_array2_3
    CLRF    slave_digit_array2_4
    CLRF    slave_digit_array2_5
    CLRF    slave_digit_array2_6
    CLRF    slave_digit_array2_7
    CLRF    slave_digit_array2_8
    CLRF    slave_digit_array2_9
    CLRF    slave_digit_array2_10
    CLRF    slave_digit_array2_11
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
    
    ; Check which number we're receiving
    MOVF    current_number, 0
    SUBLW   .1                      ; Check if current_number == 1
    BTFSC   STATUS, Z               ; If Z=1, we're receiving first number
    GOTO    store_in_first_array
    
    ; Store in second number array
    MOVF    digit_index, 0
    ADDLW   slave_digit_array2_0    ; Calculate address of second array element
    GOTO    store_digit_continue
    
store_in_first_array:
    ; Store in first number array
    MOVF    digit_index, 0
    ADDLW   slave_digit_array1_0    ; Calculate address of first array element
    
store_digit_continue:
    MOVWF   FSR                     ; Point FSR to the array element
    MOVF    received_digit, 0       ; Get the received digit
    MOVWF   INDF                    ; Store it in the array using indirect addressing
    
    INCF    digit_index, 1          ; Move to next array position
    
    RETURN

display_complete_number:
    ; This function is kept for compatibility but redirects to new handler
    CALL    handle_complete_number_received
    RETURN

handle_complete_number_received:
    ; Handle when a complete 12-digit number is received
    ; Check which number we just received
    MOVF    current_number, 0
    SUBLW   .1                      ; Check if current_number == 1
    BTFSC   STATUS, Z               ; If Z=1, we just received first number
    GOTO    first_number_complete
    
    ; We just received second number
    CALL    display_both_numbers
    GOTO    complete_reception_done
    
first_number_complete:
    ; Display first number and prepare for second
    CALL    display_first_number_received
    
    ; Set up for receiving second number
    MOVLW   .2
    MOVWF   current_number          ; Now receiving second number
    CLRF    digit_index             ; Reset digit index for second number
    
complete_reception_done:
    RETURN

display_first_number_received:
    ; Clear the display and show the first received number
    MOVLW   0x01            ; Clear display
    CALL    lcd_cmd
    
    MOVLW   0x80            ; Position cursor at first line
    CALL    lcd_cmd
    
    ; Display "NUMBER 1:"
    MOVLW   'N'
    CALL    lcd_data
    MOVLW   'U'
    CALL    lcd_data
    MOVLW   'M'
    CALL    lcd_data
    MOVLW   'B'
    CALL    lcd_data
    MOVLW   'E'
    CALL    lcd_data
    MOVLW   'R'
    CALL    lcd_data
    MOVLW   ' '
    CALL    lcd_data
    MOVLW   '1'
    CALL    lcd_data
    MOVLW   ':'
    CALL    lcd_data
    
    MOVLW   0xC0            ; Position cursor at second line
    CALL    lcd_cmd
    
    ; Display the first number with decimal point
    CALL    display_received_digits_1
    
    RETURN

display_both_numbers:
    ; Clear the display and show both received numbers
    MOVLW   0x01            ; Clear display
    CALL    lcd_cmd
    
    MOVLW   0x80            ; Position cursor at first line
    CALL    lcd_cmd
    
    ; Display "NUM1:" followed by first 8 digits of first number
    MOVLW   'N'
    CALL    lcd_data
    MOVLW   '1'
    CALL    lcd_data
    MOVLW   ':'
    CALL    lcd_data
    
    ; Display first part of first number
    MOVF    slave_digit_array1_0, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_1, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_2, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_3, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_4, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_5, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVLW   '.'
    CALL    lcd_data
    MOVF    slave_digit_array1_6, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array1_7, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVLW   0xC0            ; Position cursor at second line
    CALL    lcd_cmd
    
    ; Display "NUM2:" followed by first part of second number
    MOVLW   'N'
    CALL    lcd_data
    MOVLW   '2'
    CALL    lcd_data
    MOVLW   ':'
    CALL    lcd_data
    
    ; Display first part of second number
    MOVF    slave_digit_array2_0, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_1, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_2, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_3, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_4, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_5, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVLW   '.'
    CALL    lcd_data
    MOVF    slave_digit_array2_6, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    slave_digit_array2_7, 0
    ADDLW   '0'
    CALL    lcd_data
    
    RETURN

display_received_digits_1:
    ; Display the complete first number with decimal point
    MOVF    slave_digit_array1_0, 0
    ADDLW   '0'             ; Convert digit to ASCII
    CALL    lcd_data
    
    MOVF    slave_digit_array1_1, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_2, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_3, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_4, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_5, 0
    ADDLW   '0'
    CALL    lcd_data
    
    ; Add decimal point
    MOVLW   '.'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_6, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_7, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_8, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_9, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_10, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array1_11, 0
    ADDLW   '0'
    CALL    lcd_data
    
    RETURN

display_received_digits_2:
    ; Display the complete second number with decimal point
    MOVF    slave_digit_array2_0, 0
    ADDLW   '0'             ; Convert digit to ASCII
    CALL    lcd_data
    
    MOVF    slave_digit_array2_1, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_2, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_3, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_4, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_5, 0
    ADDLW   '0'
    CALL    lcd_data
    
    ; Add decimal point
    MOVLW   '.'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_6, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_7, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_8, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_9, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_10, 0
    ADDLW   '0'
    CALL    lcd_data
    
    MOVF    slave_digit_array2_11, 0
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
