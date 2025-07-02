;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;	FIXED_POINT_DIVISION.ASM	Ver 5.3 (High-Precision Fix)
;
;	Fixed-Point Division Calculator (dddddd.dddddd)
;	PIC 16F877A with LCD Display
;
;	This code divides a 6.6 fixed-point dividend by a 6.6 fixed-point
;	divisor and produces a 6.6 fixed-point result.
;
;	Enhancements by Gemini:
;	- Updated logic to handle fixed-point inputs for both dividend and divisor.
;	- Expanded division routine to handle an 18-digit scaled dividend and
;	  a 12-digit divisor.
;	- Updated initialization to load fixed-point numbers and scale the dividend.
;	- Updated display routines to show fixed-point inputs correctly.
;   - Corrected all MPASM syntax errors.
;   - Fixed quotient storage logic in the main division loop.
;   - Implemented high-precision fix by expanding the working remainder to 13 digits.
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

#include <p16F877A.inc>

    ; Note: Directives like __CONFIG should be indented.
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _WRT_OFF & _DEBUG_OFF & _CP_OFF

; Bank selection macros
banksel_0 macro
    bcf STATUS, RP0
    bcf STATUS, RP1
    endm

banksel_1 macro
    bsf STATUS, RP0
    bcf STATUS, RP1
    endm

; Variable definitions
    CBLOCK 0x20
    delay_ms_count
    temp_char
    
    ; Dividend: 18 digits to hold the scaled 12-digit input (shifted by 6 places).
    dividend_d17
    dividend_d16
    dividend_d15
    dividend_d14
    dividend_d13
    dividend_d12
    dividend_d11
    dividend_d10
    dividend_d9
    dividend_d8
    dividend_d7
    dividend_d6 
    dividend_d5 
    dividend_d4
    dividend_d3
    dividend_d2
    dividend_d1
    dividend_d0
    
    ; Divisor: 12 digits for the 6.6 fixed-point input.
    divisor_d11
    divisor_d10
    divisor_d9
    divisor_d8
    divisor_d7
    divisor_d6  
    divisor_d5
    divisor_d4
    divisor_d3
    divisor_d2
    divisor_d1
    divisor_d0
    
    ; Working dividend (remainder during division) - EXPANDED TO 13 DIGITS FOR PRECISION
    working_d12
    working_d11
    working_d10
    working_d9
    working_d8
    working_d7
    working_d6
    working_d5
    working_d4
    working_d3
    working_d2
    working_d1
    working_d0
    
    ; Quotient result: Stores the final 12-digit (6.6) fixed-point number.
    quotient_d11
    quotient_d10
    quotient_d9
    quotient_d8
    quotient_d7
    quotient_d6
    quotient_d5
    quotient_d4
    quotient_d3
    quotient_d2
    quotient_d1
    quotient_d0
    
    ; Temporary variables
    compare_result
    temp_w
    digit_index
    dividend_ptr
    quotient_ptr
    current_quotient_digit
    
    ENDC

; LCD control definitions
LCD_RS EQU 0
LCD_E  EQU 2
LCD_CTRL_PORT EQU PORTB

; Program start
    ORG 0x0000
    goto start

    ORG 0x0004
    retfie

start:
    banksel_1
    movlw b'00000000'
    movwf TRISD
    movlw b'11111000'
    movwf TRISB
    banksel_0
    
    call lcd_init
    call initialize_test_numbers
    call display_welcome
    call delay_2s
    call display_input_numbers
    call delay_2s
    call perform_18x12_division
    call display_final_result
    
main_loop:
    goto main_loop

; ===================================================================================
; SUBROUTINE: initialize_test_numbers
; ===================================================================================
initialize_test_numbers:
    ; Example: 700123.456789 / 9002.5
    ; Step 1: Load the 12-digit dividend into the upper 12 bytes of the 18-byte dividend variable.
    clrf    dividend_d17
    clrf    dividend_d16
    movlw   7
    movwf   dividend_d15
    movlw   0
    movwf   dividend_d14
    movlw   0
    movwf   dividend_d13
    movlw   1
    movwf   dividend_d12
    movlw   2
    movwf   dividend_d11
    movlw   3
    movwf   dividend_d10
    movlw   4
    movwf   dividend_d9
    movlw   5
    movwf   dividend_d8
    movlw   6
    movwf   dividend_d7
    movlw   7
    movwf   dividend_d6
    movlw   0
    movwf   dividend_d5
    movlw   0
    movwf   dividend_d4

    ; Step 2: Shift left by 4 places to complete scaling.
    clrf    dividend_d3
    clrf    dividend_d2
    clrf    dividend_d1
    clrf    dividend_d0
    
    ; Step 3: Load the 12-digit divisor (009002.500000).
    clrf    divisor_d11
    clrf    divisor_d10
    clrf    divisor_d9
    movlw   9
    movwf   divisor_d8
    movlw   0
    movwf   divisor_d7
    movlw   0
    movwf   divisor_d6
    movlw   2
    movwf   divisor_d5
    movlw   5
    movwf   divisor_d4
    clrf    divisor_d3
    clrf    divisor_d2
    clrf    divisor_d1
    clrf    divisor_d0
    
    ; Clear quotient to ensure a clean start
    clrf    quotient_d11
    clrf    quotient_d10
    clrf    quotient_d9
    clrf    quotient_d8
    clrf    quotient_d7
    clrf    quotient_d6
    clrf    quotient_d5
    clrf    quotient_d4
    clrf    quotient_d3
    clrf    quotient_d2
    clrf    quotient_d1
    clrf    quotient_d0
    
    return

; ===================================================================================
; SUBROUTINE: perform_18x12_division
; ===================================================================================
perform_18x12_division:
    ; Clear working remainder (13 digits)
    clrf    working_d12
    clrf    working_d11
    clrf    working_d10
    clrf    working_d9
    clrf    working_d8
    clrf    working_d7
    clrf    working_d6
    clrf    working_d5
    clrf    working_d4
    clrf    working_d3
    clrf    working_d2
    clrf    working_d1
    clrf    working_d0

    ; Initialize digit counter for 18-digit dividend
    movlw   .18
    movwf   digit_index

    ; Point to most significant digits
    movlw   dividend_d17
    movwf   dividend_ptr
    movlw   quotient_d11
    movwf   quotient_ptr

digit_loop:
    ; Shift working remainder (13 digits) left by 1 digit
    movf    working_d11, W
    movwf   working_d12
    movf    working_d10, W
    movwf   working_d11
    movf    working_d9, W
    movwf   working_d10
    movf    working_d8, W
    movwf   working_d9
    movf    working_d7, W
    movwf   working_d8
    movf    working_d6, W
    movwf   working_d7
    movf    working_d5, W
    movwf   working_d6
    movf    working_d4, W
    movwf   working_d5
    movf    working_d3, W
    movwf   working_d4
    movf    working_d2, W
    movwf   working_d3
    movf    working_d1, W
    movwf   working_d2
    movf    working_d0, W
    movwf   working_d1

    ; Bring down the next digit from the dividend
    movf    dividend_ptr, W
    movwf   FSR
    movf    INDF, W
    movwf   working_d0
    incf    dividend_ptr, F

    ; Reset current quotient digit
    clrf    current_quotient_digit

subtract_loop:
    call    compare_13x12_numbers
    btfss   compare_result, 0
    goto    end_subtract_loop

    call    subtract_13x12_numbers
    incf    current_quotient_digit, F
    goto    subtract_loop

end_subtract_loop:
    ; Check if we should store this digit. We only store the last 12 digits.
    movlw   .13
    subwf   digit_index, W
    btfsc   STATUS, C
    goto    skip_store

    ; Store the result digit
    movf    quotient_ptr, W
    movwf   FSR
    movf    current_quotient_digit, W
    movwf   INDF
    incf    quotient_ptr, F

skip_store:
    decfsz  digit_index, F
    goto    digit_loop
    return

; ===================================================================================
; SUBROUTINE: compare_13x12_numbers
; ===================================================================================
compare_13x12_numbers:
    clrf    compare_result
    ; If the 13th digit of working is > 0, working is bigger than the 12-digit divisor.
    movf    working_d12, W
    btfsc   STATUS, Z
    goto    compare_lower_12_digits
    
    bsf     compare_result, 0
    return

compare_lower_12_digits:
    ; Standard 12x12 compare of working_d11-d0 and divisor_d11-d0
    movf    divisor_d11, W
    subwf   working_d11, W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d10, W
    subwf   working_d10, W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d9,  W
    subwf   working_d9,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d8,  W
    subwf   working_d8,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d7,  W
    subwf   working_d7,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d6,  W
    subwf   working_d6,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d5,  W
    subwf   working_d5,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d4,  W
    subwf   working_d4,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d3,  W
    subwf   working_d3,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d2,  W
    subwf   working_d2,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d1,  W
    subwf   working_d1,  W
    btfss   STATUS, Z
    goto    check_compare_result
    movf    divisor_d0,  W
    subwf   working_d0,  W
check_compare_result:
    btfsc   STATUS, C
    bsf     compare_result, 0
    return

; ===================================================================================
; SUBROUTINE: subtract_13x12_numbers
; ===================================================================================
subtract_13x12_numbers:
    movf    divisor_d0, W
    subwf   working_d0, F
    btfsc   STATUS, C
    goto    sub_digit_1
    movlw   .10
    addwf   working_d0, F
    call    borrow_from_higher_digits_0
sub_digit_1:
    movf    divisor_d1, W
    subwf   working_d1, F
    btfsc   STATUS, C
    goto    sub_digit_2
    movlw   .10
    addwf   working_d1, F
    call    borrow_from_higher_digits_1
sub_digit_2:
    movf    divisor_d2, W
    subwf   working_d2, F
    btfsc   STATUS, C
    goto    sub_digit_3
    movlw   .10
    addwf   working_d2, F
    call    borrow_from_higher_digits_2
sub_digit_3:
    movf    divisor_d3, W
    subwf   working_d3, F
    btfsc   STATUS, C
    goto    sub_digit_4
    movlw   .10
    addwf   working_d3, F
    call    borrow_from_higher_digits_3
sub_digit_4:
    movf    divisor_d4, W
    subwf   working_d4, F
    btfsc   STATUS, C
    goto    sub_digit_5
    movlw   .10
    addwf   working_d4, F
    call    borrow_from_higher_digits_4
sub_digit_5:
    movf    divisor_d5, W
    subwf   working_d5, F
    btfsc   STATUS, C
    goto    sub_digit_6
    movlw   .10
    addwf   working_d5, F
    call    borrow_from_higher_digits_5
sub_digit_6:
    movf    divisor_d6, W
    subwf   working_d6, F
    btfsc   STATUS, C
    goto    sub_digit_7
    movlw   .10
    addwf   working_d6, F
    call    borrow_from_higher_digits_6
sub_digit_7:
    movf    divisor_d7, W
    subwf   working_d7, F
    btfsc   STATUS, C
    goto    sub_digit_8
    movlw   .10
    addwf   working_d7, F
    call    borrow_from_higher_digits_7
sub_digit_8:
    movf    divisor_d8, W
    subwf   working_d8, F
    btfsc   STATUS, C
    goto    sub_digit_9
    movlw   .10
    addwf   working_d8, F
    call    borrow_from_higher_digits_8
sub_digit_9:
    movf    divisor_d9, W
    subwf   working_d9, F
    btfsc   STATUS, C
    goto    sub_digit_10
    movlw   .10
    addwf   working_d9, F
    call    borrow_from_higher_digits_9
sub_digit_10:
    movf    divisor_d10, W
    subwf   working_d10, F
    btfsc   STATUS, C
    goto    sub_digit_11
    movlw   .10
    addwf   working_d10, F
    call    borrow_from_higher_digits_10
sub_digit_11:
    movf    divisor_d11, W
    subwf   working_d11, F
    btfsc   STATUS, C
    return
    movlw   .10
    addwf   working_d11, F
    call    borrow_from_higher_digits_11
    return

; ===================================================================================
; BORROW ROUTINES (EXTENDED TO 13 DIGITS)
; ===================================================================================
borrow_from_higher_digits_0:
    decf    working_d1, F
    btfss   working_d1, 7
    return
    movlw   .9
    movwf   working_d1
borrow_from_higher_digits_1:
    decf    working_d2, F
    btfss   working_d2, 7
    return
    movlw   .9
    movwf   working_d2
borrow_from_higher_digits_2:
    decf    working_d3, F
    btfss   working_d3, 7
    return
    movlw   .9
    movwf   working_d3
borrow_from_higher_digits_3:
    decf    working_d4, F
    btfss   working_d4, 7
    return
    movlw   .9
    movwf   working_d4
borrow_from_higher_digits_4:
    decf    working_d5, F
    btfss   working_d5, 7
    return
    movlw   .9
    movwf   working_d5
borrow_from_higher_digits_5:
    decf    working_d6, F
    btfss   working_d6, 7
    return
    movlw   .9
    movwf   working_d6
borrow_from_higher_digits_6:
    decf    working_d7, F
    btfss   working_d7, 7
    return
    movlw   .9
    movwf   working_d7
borrow_from_higher_digits_7:
    decf    working_d8, F
    btfss   working_d8, 7
    return
    movlw   .9
    movwf   working_d8
borrow_from_higher_digits_8:
    decf    working_d9, F
    btfss   working_d9, 7
    return
    movlw   .9
    movwf   working_d9
borrow_from_higher_digits_9:
    decf    working_d10, F
    btfss   working_d10, 7
    return
    movlw   .9
    movwf   working_d10
borrow_from_higher_digits_10:
    decf    working_d11, F
    btfss   working_d11, 7
    return
    movlw   .9
    movwf   working_d11
borrow_from_higher_digits_11:
    decf    working_d12, F
    return

; ===================================================================================
; DISPLAY ROUTINES
; ===================================================================================
display_welcome:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'F'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   'x'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   'd'
    call    lcd_write
    movlw   '-'
    call    lcd_write
    movlw   'P'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   'n'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   0xC0
    call    lcd_cmd
    movlw   'D'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   'v'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   's'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   'n'
    call    lcd_write
    return

; Display input numbers in their fixed-point format
display_input_numbers:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'D'
    call    lcd_write
    movlw   'V'
    call    lcd_write
    movlw   'D'
    call    lcd_write
    movlw   ':'
    call    lcd_write
    ; Display dividend from its original 12-digit representation before scaling
    movf    dividend_d15, W
    addlw   '0'
    call    lcd_write
    movf    dividend_d14, W
    addlw   '0'
    call    lcd_write
    movf    dividend_d13, W
    addlw   '0'
    call    lcd_write
    movf    dividend_d12, W
    addlw   '0'
    call    lcd_write
    movf    dividend_d11, W
    addlw   '0'
    call    lcd_write
    movf    dividend_d10, W
    addlw   '0'
    call    lcd_write
    movlw   '.'
    call    lcd_write
    movf    dividend_d9, W
    addlw   '0'
    call    lcd_write
    
    movlw   0xC0
    call    lcd_cmd
    movlw   'D'
    call    lcd_write
    movlw   'V'
    call    lcd_write
    movlw   'R'
    call    lcd_write
    movlw   ':'
    call    lcd_write
    ; Display divisor in fixed-point format
    movf    divisor_d8, W
    addlw   '0'
    call    lcd_write
    movf    divisor_d7, W
    addlw   '0'
    call    lcd_write
    movf    divisor_d6, W
    addlw   '0'
    call    lcd_write
    movf    divisor_d5, W
    addlw   '0'
    call    lcd_write
    movlw   '.'
    call    lcd_write
    movf    divisor_d4, W
    addlw   '0'
    call    lcd_write
    return

; Display the final fixed-point result
display_final_result:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'R'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   's'
    call    lcd_write
    movlw   'u'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   ':'
    call    lcd_write
    movlw   0xC0
    call    lcd_cmd
    call    display_fixed_point_quotient
    return

; Display quotient in dddddd.dddddd format
display_fixed_point_quotient:
    ; Integer part (d11-d6)
    movf    quotient_d11, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d10, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d9, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d8, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d7, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d6, W
    addlw   '0'
    call    lcd_write
    movlw   '.'
    call    lcd_write
    ; Fractional part (d5-d0)
    movf    quotient_d5, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d4, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d3, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d2, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d1, W
    addlw   '0'
    call    lcd_write
    movf    quotient_d0, W
    addlw   '0'
    call    lcd_write
    return

; LCD and Delay Routines
lcd_init:
    call    delay_20ms
    movlw   0x30
    call    lcd_cmd
    call    delay_5ms
    movlw   0x30
    call    lcd_cmd
    call    delay_1ms
    movlw   0x30
    call    lcd_cmd
    movlw   0x38
    call    lcd_cmd
    movlw   0x0C
    call    lcd_cmd
    movlw   0x01
    call    lcd_cmd
    movlw   0x06
    call    lcd_cmd
    return
lcd_cmd:
    movwf   PORTD
    bcf     LCD_CTRL_PORT, LCD_RS
    call    lcd_pulse_e
    call    delay_1ms
    return
lcd_write:
    movwf   PORTD
    bsf     LCD_CTRL_PORT, LCD_RS
    call    lcd_pulse_e
    call    delay_1ms
    return
lcd_pulse_e:
    bsf     LCD_CTRL_PORT, LCD_E
    nop
    nop
    bcf     LCD_CTRL_PORT, LCD_E
    return
delay_2s:
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    movlw   .250
    call    delay_ms
    return
delay_20ms:
    movlw   .20
    call    delay_ms
    return
delay_5ms:
    movlw   .5
    call    delay_ms
    return
delay_1ms:
    movlw   .1
    call    delay_ms
    return
delay_ms:
    movwf   delay_ms_count
ms_loop:
    movlw   0xC7
    movwf   temp_char
us_loop:
    decfsz  temp_char, 1
    goto    us_loop
    decfsz  delay_ms_count, 1
    goto    ms_loop
    return

    END
