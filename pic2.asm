
PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"

; --- VARIABLES ---
    CBLOCK 0x20
        temp_char
        received_digit
        digit_index
        number_count

        ; Array to store the first received 12-digit number (Dividend)
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

        ; Array to store the second received 12-digit number (Divisor)
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

        ; Status flags
        first_number_received
        second_number_received
        both_numbers_ready

        ; *** BEGIN: VARIABLES FROM DIVISION LOGIC ***
        ; Scaled Dividend: 18 digits to hold the 12-digit input shifted left by 6 places.
        div_dividend_d17
        div_dividend_d16
        div_dividend_d15
        div_dividend_d14
        div_dividend_d13
        div_dividend_d12
        div_dividend_d11
        div_dividend_d10
        div_dividend_d9
        div_dividend_d8
        div_dividend_d7
        div_dividend_d6
        div_dividend_d5
        div_dividend_d4
        div_dividend_d3
        div_dividend_d2
        div_dividend_d1
        div_dividend_d0

        ; Working dividend (remainder during division) - EXPANDED TO 13 DIGITS FOR PRECISION
        div_working_d12
        div_working_d11
        div_working_d10
        div_working_d9
        div_working_d8
        div_working_d7
        div_working_d6
        div_working_d5
        div_working_d4
        div_working_d3
        div_working_d2
        div_working_d1
        div_working_d0

        ; Quotient result: Stores the final 12-digit (6.6) fixed-point number.
        div_quotient_d11
        div_quotient_d10
        div_quotient_d9
        div_quotient_d8
        div_quotient_d7
        div_quotient_d6
        div_quotient_d5
        div_quotient_d4
        div_quotient_d3
        div_quotient_d2
        div_quotient_d1
        div_quotient_d0

        ; Temporary variables for division
        div_compare_result
        div_digit_index
        div_dividend_ptr
        div_quotient_ptr
        div_current_quotient_digit
        ; *** END: VARIABLES FROM DIVISION LOGIC ***

    ENDC

    ORG 0x00            ; Reset vector
    GOTO slave_start    ; Jump to main program

    ORG 0x04            ; Interrupt vector
    GOTO USART_ISR      ; Jump to USART interrupt handler

;----------------------------------------SLAVE MAIN PROGRAM-------------------------------------------------------------
slave_start:
    NOP                 ; Required for ICD mode

    ; Configure LCD pins
    BANKSEL TRISD
    MOVLW   B'00000000' ; All PORTD pins as output for LCD
    MOVWF   TRISD

    ; Configure USART pins
    BANKSEL TRISC
    BSF     TRISC, 7    ; RC7/RX pin as input (receive)
    BCF     TRISC, 6    ; RC6/TX pin as output (transmit)

    ; Initialize hardware and variables
    CALL    init_usart
    BANKSEL PORTD
    CLRF    PORTD
    CALL    inid
    CALL    init_slave_variables

    ; Display initial message
    CALL    display_slave_ready

    ; Enable interrupts for USART reception
    BANKSEL INTCON
    BSF     INTCON, PEIE    ; Enable peripheral interrupts
    BSF     INTCON, GIE     ; Enable global interrupts

; --- MODIFIED MAIN LOOP ---
slave_main_loop:
    ; Check if both numbers have been received and are ready for calculation
    BANKSEL both_numbers_ready
    BTFSC   both_numbers_ready, 0   ; Test the flag bit
    CALL    perform_division        ; If set, perform the division

    ; Loop back to continue checking
    GOTO    slave_main_loop

; --- HIGH-LEVEL CALCULATION ROUTINE ---
perform_division:
    ; This routine prepares the numbers and calls the core division logic.

    ; 1. Clear the 'ready' flag to prevent re-calculation
    BANKSEL both_numbers_ready
    CLRF    both_numbers_ready

    ; 2. Prepare the numbers for the 18x12 division algorithm.
    CALL    prepare_division_inputs

    ; 3. Call the core division logic that was integrated from the external file.
    CALL    perform_18x12_division

    ; 4. Display the calculated result on the LCD.
    CALL    display_result

    ; 5. Calculation is done. The routine returns to the main loop to wait.
    RETURN

;----------------------------------------USART INTERRUPT SERVICE ROUTINE-------------------------------------------------------------
USART_ISR:
    MOVWF   temp_char
    BANKSEL PIR1
    BTFSS   PIR1, RCIF
    GOTO    isr_exit
    BANKSEL RCREG
    MOVF    RCREG, 0
    MOVWF   received_digit
    MOVF    number_count, 0
    SUBLW   .0
    BTFSC   STATUS, Z
    GOTO    store_first_number
    GOTO    store_second_number
store_first_number:
    MOVF    digit_index, 0
    ADDLW   slave_digit_array1_0
    MOVWF   FSR
    MOVF    received_digit, 0
    MOVWF   INDF
    INCF    digit_index, 1
    MOVF    digit_index, 0
    SUBLW   .12
    BTFSS   STATUS, Z
    GOTO    isr_exit
    MOVLW   .1
    MOVWF   first_number_received
    CLRF    digit_index
    INCF    number_count, 1
    CALL    display_first_number_received
    GOTO    isr_exit
store_second_number:
    MOVF    digit_index, 0
    ADDLW   slave_digit_array2_0
    MOVWF   FSR
    MOVF    received_digit, 0
    MOVWF   INDF
    INCF    digit_index, 1
    MOVF    digit_index, 0
    SUBLW   .12
    BTFSS   STATUS, Z
    GOTO    isr_exit
    MOVLW   .1
    MOVWF   second_number_received
    MOVLW   .1
    MOVWF   both_numbers_ready
    CALL    display_both_numbers_received
isr_exit:
    MOVF    temp_char, 0
    RETFIE

;----------------------------------------SUBROUTINES-------------------------------------------------------------

init_usart:
    BANKSEL SPBRG
    MOVLW   .25
    MOVWF   SPBRG
    BANKSEL TXSTA
    BCF     TXSTA, SYNC
    BSF     TXSTA, TXEN
    BANKSEL RCSTA
    BSF     RCSTA, SPEN
    BSF     RCSTA, CREN
    BANKSEL PIE1
    BSF     PIE1, RCIE
    BANKSEL PIR1
    BCF     PIR1, RCIF
    RETURN

init_slave_variables:
    CLRF    digit_index
    CLRF    number_count
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
    CLRF    first_number_received
    CLRF    second_number_received
    CLRF    both_numbers_ready
    RETURN

; --- Display Routines ---
display_slave_ready:
    MOVLW   0x01
    CALL    lcd_cmd
    MOVLW   0x80
    CALL    lcd_cmd
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
    MOVLW   0xC0
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

display_first_number_received:
    MOVLW   0x01
    CALL    lcd_cmd
    MOVLW   0x80
    CALL    lcd_cmd
    MOVLW   'F'
    CALL    lcd_data
    MOVLW   'I'
    CALL    lcd_data
    MOVLW   'R'
    CALL    lcd_data
    MOVLW   'S'
    CALL    lcd_data
    MOVLW   'T'
    CALL    lcd_data
    MOVLW   ' '
    CALL    lcd_data
    MOVLW   'N'
    CALL    lcd_data
    MOVLW   'U'
    CALL    lcd_data
    MOVLW   'M'
    CALL    lcd_data
    MOVLW   ' '
    CALL    lcd_data
    MOVLW   'R'
    CALL    lcd_data
    MOVLW   'C'
    CALL    lcd_data
    MOVLW   'V'
    CALL    lcd_data
    RETURN

display_both_numbers_received:
    MOVLW   0x01
    CALL    lcd_cmd
    MOVLW   0x80
    CALL    lcd_cmd
    MOVLW   'B'
    CALL    lcd_data
    MOVLW   'O'
    CALL    lcd_data
    MOVLW   'T'
    CALL    lcd_data
    MOVLW   'H'
    CALL    lcd_data
    MOVLW   ' '
    CALL    lcd_data
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
    MOVLW   'S'
    CALL    lcd_data
    MOVLW   0xC0
    CALL    lcd_cmd
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
    MOVLW   '!'
    CALL    lcd_data
    RETURN

; --- NEW: Display Result in dddddd.dddddd format ---
display_result:
    ; Clear LCD and set to first line
    MOVLW   0x01
    CALL    lcd_cmd
    MOVLW   0x80
    CALL    lcd_cmd

    ; Display integer part (6 digits)
    BANKSEL div_quotient_d11
    MOVF    div_quotient_d11, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d10, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d9, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d8, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d7, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d6, 0
    ADDLW   '0'
    CALL    lcd_data
    
    ; Display decimal point
    MOVLW   '.'
    CALL    lcd_data
    
    ; Display fractional part (6 digits)
    MOVF    div_quotient_d5, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d4, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d3, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d2, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d1, 0
    ADDLW   '0'
    CALL    lcd_data
    MOVF    div_quotient_d0, 0
    ADDLW   '0'
    CALL    lcd_data

    RETURN

; --- LCD Interface ---
lcd_data:
    BSF     Select, RS
    CALL    send
    RETURN

lcd_cmd:
    BCF     Select, RS
    CALL    send
    RETURN

; *** BEGIN: INTEGRATED DIVISION LOGIC ***
; The following subroutines were copied from 'Working Div.asm'.
; They perform the core 18x12 fixed-point division.

prepare_division_inputs:
    ; This routine prepares the received numbers for division.
    ; 1. Copies the 12-digit dividend from slave_digit_array1 into the high-order
    ;    bytes of the 18-digit div_dividend, effectively scaling it by 1,000,000.
    MOVF    slave_digit_array1_0, W
    MOVWF   div_dividend_d17
    MOVF    slave_digit_array1_1, W
    MOVWF   div_dividend_d16
    MOVF    slave_digit_array1_2,  W
    MOVWF   div_dividend_d15
    MOVF    slave_digit_array1_3,  W
    MOVWF   div_dividend_d14
    MOVF    slave_digit_array1_4,  W
    MOVWF   div_dividend_d13
    MOVF    slave_digit_array1_5,  W
    MOVWF   div_dividend_d12
    MOVF    slave_digit_array1_6,  W
    MOVWF   div_dividend_d11
    MOVF    slave_digit_array1_7,  W
    MOVWF   div_dividend_d10
    MOVF    slave_digit_array1_8,  W
    MOVWF   div_dividend_d9
    MOVF    slave_digit_array1_9,  W
    MOVWF   div_dividend_d8
    MOVF    slave_digit_array1_10,  W
    MOVWF   div_dividend_d7
    MOVF    slave_digit_array1_11,  W
    MOVWF   div_dividend_d6
    ; Clear the lower 6 digits for scaling
    CLRF    div_dividend_d5
    CLRF    div_dividend_d4
    CLRF    div_dividend_d3
    CLRF    div_dividend_d2
    CLRF    div_dividend_d1
    CLRF    div_dividend_d0
    ; 2. Clear quotient to ensure a clean start
    CLRF    div_quotient_d11
    CLRF    div_quotient_d10
    CLRF    div_quotient_d9
    CLRF    div_quotient_d8
    CLRF    div_quotient_d7
    CLRF    div_quotient_d6
    CLRF    div_quotient_d5
    CLRF    div_quotient_d4
    CLRF    div_quotient_d3
    CLRF    div_quotient_d2
    CLRF    div_quotient_d1
    CLRF    div_quotient_d0
    RETURN

perform_18x12_division:
    ; Clear working remainder (13 digits)
    CLRF    div_working_d12
    CLRF    div_working_d11
    CLRF    div_working_d10
    CLRF    div_working_d9
    CLRF    div_working_d8
    CLRF    div_working_d7
    CLRF    div_working_d6
    CLRF    div_working_d5
    CLRF    div_working_d4
    CLRF    div_working_d3
    CLRF    div_working_d2
    CLRF    div_working_d1
    CLRF    div_working_d0
    ; Initialize digit counter for 18-digit dividend
    MOVLW   .18
    MOVWF   div_digit_index
    ; Point to most significant digits
    MOVLW   div_dividend_d17
    MOVWF   div_dividend_ptr
    MOVLW   div_quotient_d11
    MOVWF   div_quotient_ptr
digit_loop:
    ; Shift working remainder left
    MOVF    div_working_d11, W
    MOVWF   div_working_d12
    MOVF    div_working_d10, W
    MOVWF   div_working_d11
    MOVF    div_working_d9,  W
    MOVWF   div_working_d10
    MOVF    div_working_d8,  W
    MOVWF   div_working_d9
    MOVF    div_working_d7,  W
    MOVWF   div_working_d8
    MOVF    div_working_d6,  W
    MOVWF   div_working_d7
    MOVF    div_working_d5,  W
    MOVWF   div_working_d6
    MOVF    div_working_d4,  W
    MOVWF   div_working_d5
    MOVF    div_working_d3,  W
    MOVWF   div_working_d4
    MOVF    div_working_d2,  W
    MOVWF   div_working_d3
    MOVF    div_working_d1,  W
    MOVWF   div_working_d2
    MOVF    div_working_d0,  W
    MOVWF   div_working_d1
    ; Bring down next digit from dividend
    MOVF    div_dividend_ptr, W
    MOVWF   FSR
    MOVF    INDF, W
    MOVWF   div_working_d0
    INCF    div_dividend_ptr, F
    ; Reset current quotient digit
    CLRF    div_current_quotient_digit
subtract_loop:
    CALL    compare_13x12_numbers
    BTFSS   div_compare_result, 0
    GOTO    end_subtract_loop
    CALL    subtract_13x12_numbers
    INCF    div_current_quotient_digit, F
    GOTO    subtract_loop
end_subtract_loop:
    MOVLW   .13
    SUBWF   div_digit_index, W
    BTFSC   STATUS, C
    GOTO    skip_store
    ; Store the result digit
    MOVF    div_quotient_ptr, W
    MOVWF   FSR
    MOVF    div_current_quotient_digit, W
    MOVWF   INDF
    INCF    div_quotient_ptr, F
skip_store:
    DECFSZ  div_digit_index, F
    GOTO    digit_loop
    RETURN

compare_13x12_numbers:
    CLRF    div_compare_result
    MOVF    div_working_d12, W
    BTFSC   STATUS, Z
    GOTO    compare_lower_12
    BSF     div_compare_result, 0
    RETURN
compare_lower_12:
    MOVF    slave_digit_array2_0, W
    SUBWF   div_working_d11, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_1, W
    SUBWF   div_working_d10, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_2, W
    SUBWF   div_working_d9, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_3, W
    SUBWF   div_working_d8, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_4, W
    SUBWF   div_working_d7, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_5, W
    SUBWF   div_working_d6, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_6, W
    SUBWF   div_working_d5, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_7, W
    SUBWF   div_working_d4, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_8, W
    SUBWF   div_working_d3, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_9, W
    SUBWF   div_working_d2, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_10, W
    SUBWF   div_working_d1, W
    BTFSS   STATUS, Z
    GOTO    check_comp_res
    MOVF    slave_digit_array2_11, W
    SUBWF   div_working_d0, W
check_comp_res:
    BTFSC   STATUS, C
    BSF     div_compare_result, 0
    RETURN

subtract_13x12_numbers:
    MOVF    slave_digit_array2_11, W
    SUBWF   div_working_d0, F
    BTFSC   STATUS, C
    GOTO    sub_d1
    MOVLW   .10
    ADDWF   div_working_d0, F
    CALL    b_f_h_d_0
sub_d1:
    MOVF    slave_digit_array2_10, W
    SUBWF   div_working_d1, F
    BTFSC   STATUS, C
    GOTO    sub_d2
    MOVLW   .10
    ADDWF   div_working_d1, F
    CALL    b_f_h_d_1
sub_d2:
    MOVF    slave_digit_array2_9, W
    SUBWF   div_working_d2, F
    BTFSC   STATUS, C
    GOTO    sub_d3
    MOVLW   .10
    ADDWF   div_working_d2, F
    CALL    b_f_h_d_2
sub_d3:
    MOVF    slave_digit_array2_8, W
    SUBWF   div_working_d3, F
    BTFSC   STATUS, C
    GOTO    sub_d4
    MOVLW   .10
    ADDWF   div_working_d3, F
    CALL    b_f_h_d_3
sub_d4:
    MOVF    slave_digit_array2_7, W
    SUBWF   div_working_d4, F
    BTFSC   STATUS, C
    GOTO    sub_d5
    MOVLW   .10
    ADDWF   div_working_d4, F
    CALL    b_f_h_d_4
sub_d5:
    MOVF    slave_digit_array2_6, W
    SUBWF   div_working_d5, F
    BTFSC   STATUS, C
    GOTO    sub_d6
    MOVLW   .10
    ADDWF   div_working_d5, F
    CALL    b_f_h_d_5
sub_d6:
    MOVF    slave_digit_array2_5, W
    SUBWF   div_working_d6, F
    BTFSC   STATUS, C
    GOTO    sub_d7
    MOVLW   .10
    ADDWF   div_working_d6, F
    CALL    b_f_h_d_6
sub_d7:
    MOVF    slave_digit_array2_4, W
    SUBWF   div_working_d7, F
    BTFSC   STATUS, C
    GOTO    sub_d8
    MOVLW   .10
    ADDWF   div_working_d7, F
    CALL    b_f_h_d_7
sub_d8:
    MOVF    slave_digit_array2_3, W
    SUBWF   div_working_d8, F
    BTFSC   STATUS, C
    GOTO    sub_d9
    MOVLW   .10
    ADDWF   div_working_d8, F
    CALL    b_f_h_d_8
sub_d9:
    MOVF    slave_digit_array2_2, W
    SUBWF   div_working_d9, F
    BTFSC   STATUS, C
    GOTO    sub_d10
    MOVLW   .10
    ADDWF   div_working_d9, F
    CALL    b_f_h_d_9
sub_d10:
    MOVF    slave_digit_array2_1, W
    SUBWF   div_working_d10, F
    BTFSC   STATUS, C
    GOTO    sub_d11
    MOVLW   .10
    ADDWF   div_working_d10, F
    CALL    b_f_h_d_10
sub_d11:
    MOVF    slave_digit_array2_0, W
    SUBWF   div_working_d11, F
    BTFSC   STATUS, C
    RETURN
    MOVLW   .10
    ADDWF   div_working_d11, F
    CALL    b_f_h_d_11
    RETURN

; *** CRITICAL FIX: Corrected Ripple-Borrow Routines (Fall-through logic) ***
b_f_h_d_0:
    DECF    div_working_d1, F
    BTFSS   div_working_d1, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d1
b_f_h_d_1:
    DECF    div_working_d2, F
    BTFSS   div_working_d2, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d2
b_f_h_d_2:
    DECF    div_working_d3, F
    BTFSS   div_working_d3, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d3
b_f_h_d_3:
    DECF    div_working_d4, F
    BTFSS   div_working_d4, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d4
b_f_h_d_4:
    DECF    div_working_d5, F
    BTFSS   div_working_d5, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d5
b_f_h_d_5:
    DECF    div_working_d6, F
    BTFSS   div_working_d6, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d6
b_f_h_d_6:
    DECF    div_working_d7, F
    BTFSS   div_working_d7, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d7
b_f_h_d_7:
    DECF    div_working_d8, F
    BTFSS   div_working_d8, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d8
b_f_h_d_8:
    DECF    div_working_d9, F
    BTFSS   div_working_d9, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d9
b_f_h_d_9:
    DECF    div_working_d10, F
    BTFSS   div_working_d10, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d10
b_f_h_d_10:
    DECF    div_working_d11, F
    BTFSS   div_working_d11, 7
    RETURN
    MOVLW   .9
    MOVWF   div_working_d11
b_f_h_d_11:
    DECF    div_working_d12, F
    RETURN

; *** END: INTEGRATED DIVISION LOGIC ***

INCLUDE "LCDIS.INC"

END
