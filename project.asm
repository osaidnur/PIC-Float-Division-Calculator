; ==============================================================================
; PIC16F877A Division Calculator (Step 2) - 6 Digit Entry with Cursor Movement
; LCD: PORTD = Data, RB0 = RS, RB2 = E, RB3 = Push Button
; Clock = 4MHz
; ==============================================================================

    #include <p16F877A.inc>
    __CONFIG _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _WRT_OFF & _DEBUG_OFF & _CP_OFF

; --- MACROS ---
banksel_0 macro
    bcf STATUS, RP0
    bcf STATUS, RP1
    endm

banksel_1 macro
    bsf STATUS, RP0
    bcf STATUS, RP1
    endm

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
    ENDC

; --- PIN DEFINITIONS ---
LCD_RS      EQU     0
LCD_E       EQU     2
LCD_CTRL    EQU     PORTB
P_BUTTON    EQU     3

; --- RESET VECTOR ---
    ORG 0x0000
    goto start

    ORG 0x0004
    retfie

; ==============================================================================
; MAIN PROGRAM
; ==============================================================================
start
    banksel_1
    movlw   b'00000000'
    movwf   TRISD
    movlw   b'11111000'      ; RB0-2 outputs, RB3 input
    movwf   TRISB
    banksel_0

    ; Initialize variables
    clrf digit_cursor_pos
    clrf digit_array0
    clrf digit_array1
    clrf digit_array2
    clrf digit_array3
    clrf digit_array4
    clrf digit_array5
    clrf current_digit_value

    call lcd_init
    call display_welcome_message

    ; Blink welcome message 3 times
    movlw   .3
    movwf   blink_counter
blink_loop:
    movlw   0x08
    call    lcd_cmd
    call    delay_500ms
    movlw   0x0C
    call    lcd_cmd
    call    delay_500ms
    decfsz  blink_counter, 1
    goto    blink_loop

    ; Wait 2 seconds
    call delay_500ms
    call delay_500ms
    call delay_500ms
    call delay_500ms

    ; Ready for input
    movlw   0x01
    call    lcd_cmd
    movlw   0x0F          ; Cursor ON, Blink ON
    call    lcd_cmd

    call display_number_1_prompt
    call display_all_digits
    call position_cursor

; ==============================================================================
; MAIN LOOP
; ==============================================================================
digit_entry_loop:
    btfss   PORTB, P_BUTTON
    goto    digit_entry_loop
    call    debounce
    btfss   PORTB, P_BUTTON
    goto    digit_entry_loop

    ; Read current digit value from array
    movf    digit_cursor_pos, 0
    addwf   PCL, f
    goto    get0
    goto    get1
    goto    get2
    goto    get3
    goto    get4
    goto    get5

get0: movf digit_array0, 0
      movwf current_digit_value
      goto inc_digit
get1: movf digit_array1, 0
      movwf current_digit_value
      goto inc_digit
get2: movf digit_array2, 0
      movwf current_digit_value
      goto inc_digit
get3: movf digit_array3, 0
      movwf current_digit_value
      goto inc_digit
get4: movf digit_array4, 0
      movwf current_digit_value
      goto inc_digit
get5: movf digit_array5, 0
      movwf current_digit_value
      goto inc_digit

; --- INCREMENT DIGIT ---
inc_digit:
    movf    current_digit_value, 0
    sublw   9
    btfsc   STATUS, Z
    goto    roll_to_zero

    incf    current_digit_value, 1
    goto    store_back

roll_to_zero:
    clrf    current_digit_value
    ; Move cursor to next digit if not at the last digit
    movf    digit_cursor_pos, 0
    sublw   5
    btfsc   STATUS, Z
    goto    store_back
    incf    digit_cursor_pos, 1

store_back:
    ; Store updated digit back into array
    movf    digit_cursor_pos, 0
    addwf   PCL, f
    goto    put0
    goto    put1
    goto    put2
    goto    put3
    goto    put4
    goto    put5

put0: movf current_digit_value, 0
      movwf digit_array0
      goto refresh_display
put1: movf current_digit_value, 0
      movwf digit_array1
      goto refresh_display
put2: movf current_digit_value, 0
      movwf digit_array2
      goto refresh_display
put3: movf current_digit_value, 0
      movwf digit_array3
      goto refresh_display
put4: movf current_digit_value, 0
      movwf digit_array4
      goto refresh_display
put5: movf current_digit_value, 0
      movwf digit_array5
      goto refresh_display

refresh_display:
    call display_all_digits
    call position_cursor
    goto wait_for_release

wait_for_release:
    btfsc PORTB, P_BUTTON
    goto wait_for_release
    call debounce
    goto digit_entry_loop

; ==============================================================================
; SUBROUTINES
; ==============================================================================

display_number_1_prompt:
    movlw   0x80
    call    lcd_cmd
    movlw   'N'
    call    lcd_write
    movlw   'u'
    call    lcd_write
    movlw   'm'
    call    lcd_write
    movlw   'b'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   'r'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   '1'
    call    lcd_write
    movlw   0xC0
    call    lcd_cmd
    return

display_all_digits:
    movlw   0xC0
    call    lcd_cmd
    movf    digit_array0, 0
    addlw   '0'
    call    lcd_write
    movf    digit_array1, 0
    addlw   '0'
    call    lcd_write
    movf    digit_array2, 0
    addlw   '0'
    call    lcd_write
    movf    digit_array3, 0
    addlw   '0'
    call    lcd_write
    movf    digit_array4, 0
    addlw   '0'
    call    lcd_write
    movf    digit_array5, 0
    addlw   '0'
    call    lcd_write
    return

position_cursor:
    movf    digit_cursor_pos, 0
    addlw   0xC0
    call    lcd_cmd
    return

display_welcome_message:
    movlw   0x80
    call    lcd_cmd
    movlw   'W'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   'c'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   'm'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'o'
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

lcd_init:
    call delay_20ms
    movlw 0x38
    call lcd_cmd
    call delay_5ms
    movlw 0x38
    call lcd_cmd
    call delay_1ms
    movlw 0x38
    call lcd_cmd
    movlw 0x0F    ; Cursor ON, Blink ON
    call lcd_cmd
    movlw 0x01
    call lcd_cmd
    movlw 0x06
    call lcd_cmd
    return

lcd_cmd:
    movwf PORTD
    bcf LCD_CTRL, LCD_RS
    call lcd_pulse_e
    call delay_1ms
    return

lcd_write:
    movwf PORTD
    bsf LCD_CTRL, LCD_RS
    call lcd_pulse_e
    call delay_1ms
    return

lcd_pulse_e:
    bsf LCD_CTRL, LCD_E
    nop
    nop
    bcf LCD_CTRL, LCD_E
    return

debounce:
    movlw .50
    call delay_ms
    return

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

    END
