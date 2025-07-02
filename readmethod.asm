#include <p16F877A.inc>

__CONFIG    _FOSC_HS & _WDTE_OFF & _PWRTE_ON & _BOREN_ON & _LVP_OFF & _CPD_OFF & _WRT_OFF & _DEBUG_OFF & _CP_OFF

banksel_0   macro
    bcf     STATUS, RP0
    bcf     STATUS, RP1
endm

banksel_1   macro
    bsf     STATUS, RP0
    bcf     STATUS, RP1
endm

CBLOCK 0x20
    delay_ms_count
    blink_counter
    temp_char
    num1_int_digit0
    num1_int_digit1
    num1_int_digit2
    num1_int_digit3
    num1_int_digit4
    num1_int_digit5
    num1_frac_digit0
    num1_frac_digit1
    num1_frac_digit2
    num1_frac_digit3
    num1_frac_digit4
    num1_frac_digit5
    num2_int_digit0
    num2_int_digit1
    num2_int_digit2
    num2_int_digit3
    num2_int_digit4
    num2_int_digit5
    num2_frac_digit0
    num2_frac_digit1
    num2_frac_digit2
    num2_frac_digit3
    num2_frac_digit4
    num2_frac_digit5
    current_digit_pos
    current_part
    current_number
    current_state
    timeout_counter
    button_pressed
    last_button_state
    cursor_blink_timer
    click_timer
    click_count
    double_click_detected
ENDC

LCD_RS              EQU     0
LCD_E               EQU     2
LCD_CTRL_PORT       EQU     PORTB
P_BUTTON            EQU     3
DOUBLE_CLICK_WINDOW EQU     .50

ORG 0x0000
    goto    start

ORG 0x0004
    retfie

start:
    banksel_1
    movlw   b'00000000'
    movwf   TRISD
    movlw   b'11111000'
    movwf   TRISB
    banksel_0
    
    call    initialize_all_digits
    
    clrf    current_digit_pos
    clrf    current_part
    clrf    current_number
    clrf    current_state
    clrf    button_pressed
    clrf    last_button_state
    clrf    cursor_blink_timer
    clrf    click_timer
    clrf    click_count
    clrf    double_click_detected
    
    call    lcd_init
    call    display_welcome_message
    
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
    
    call    delay_500ms
    call    delay_500ms
    call    delay_500ms
    call    delay_500ms
    
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    
    call    display_floating_number_prompt
    call    display_complete_floating_number
    call    ensure_cursor_visible

digit_entry_main_loop:
    btfsc   current_state, 0
    goto    equals_display_loop
    
    movlw   .200
    movwf   timeout_counter
digit_entry_timeout_loop:
    call    handle_double_click_timer
    call    check_button_press
    btfsc   button_pressed, 0
    call    handle_button_press
    call    maintain_cursor_visibility
    decfsz  timeout_counter, 1
    goto    continue_timeout_loop
    call    advance_to_next_digit
    goto    digit_entry_main_loop
continue_timeout_loop:
    call    delay_10ms
    goto    digit_entry_timeout_loop

equals_display_loop:
    call    check_button_press
    btfsc   button_pressed, 0
    call    handle_button_press_equals_mode
    call    maintain_cursor_visibility
    call    delay_10ms
    goto    equals_display_loop

initialize_all_digits:
    clrf    num1_int_digit0
    clrf    num1_int_digit1
    clrf    num1_int_digit2
    clrf    num1_int_digit3
    clrf    num1_int_digit4
    clrf    num1_int_digit5
    clrf    num1_frac_digit0
    clrf    num1_frac_digit1
    clrf    num1_frac_digit2
    clrf    num1_frac_digit3
    clrf    num1_frac_digit4
    clrf    num1_frac_digit5
    clrf    num2_int_digit0
    clrf    num2_int_digit1
    clrf    num2_int_digit2
    clrf    num2_int_digit3
    clrf    num2_int_digit4
    clrf    num2_int_digit5
    clrf    num2_frac_digit0
    clrf    num2_frac_digit1
    clrf    num2_frac_digit2
    clrf    num2_frac_digit3
    clrf    num2_frac_digit4
    clrf    num2_frac_digit5
    return

check_button_press:
    clrf    button_pressed
    btfss   PORTB, P_BUTTON
    return
    btfsc   last_button_state, 0
    return
    bsf     button_pressed, 0
    bsf     last_button_state, 0
    return

handle_button_press:
    incf    click_count, 1
    movlw   DOUBLE_CLICK_WINDOW
    movwf   click_timer
    movf    click_count, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    handle_double_click
    call    handle_single_click
    goto    wait_for_button_release

handle_button_press_equals_mode:
    bcf     button_pressed, 0
    call    wait_for_button_release
    return

handle_double_click:
    bsf     double_click_detected, 0
    call    propagate_current_digit_value
    btfsc   current_number, 0
    goto    handle_double_click_number2

handle_double_click_number1:
    btfsc   current_part, 0
    goto    switch_to_number2
    goto    switch_num1_to_fractional

handle_double_click_number2:
    btfsc   current_part, 0
    goto    switch_to_equals_display
    goto    switch_num2_to_fractional

switch_num1_to_fractional:
    bsf     current_part, 0
    clrf    current_digit_pos
    goto    complete_part_switch

switch_to_number2:
    bsf     current_number, 0
    bcf     current_part, 0
    clrf    current_digit_pos
    goto    complete_number_switch

switch_num2_to_fractional:
    bsf     current_part, 0
    clrf    current_digit_pos
    goto    complete_part_switch

switch_to_equals_display:
    bsf     current_state, 0
    clrf    click_count
    clrf    click_timer
    bcf     double_click_detected, 0
    call    show_equals_sign_display
    bcf     button_pressed, 0
    call    wait_for_button_release
    return

complete_part_switch:
    clrf    click_count
    clrf    click_timer
    bcf     double_click_detected, 0
    call    show_part_switch_message
    call    delay_500ms
    call    display_floating_number_prompt
    call    display_complete_floating_number
    call    ensure_cursor_visible
    bcf     button_pressed, 0
    call    wait_for_button_release
    return

complete_number_switch:
    clrf    click_count
    clrf    click_timer
    bcf     double_click_detected, 0
    call    show_number_switch_message
    call    delay_500ms
    call    display_floating_number_prompt
    call    display_complete_floating_number
    call    ensure_cursor_visible
    bcf     button_pressed, 0
    call    wait_for_button_release
    return

handle_single_click:
    movlw   .200
    movwf   timeout_counter
    call    increment_current_digit
    call    display_complete_floating_number
    call    ensure_cursor_visible
    bcf     button_pressed, 0
    return

wait_for_button_release:
    btfsc   PORTB, P_BUTTON
    goto    wait_for_button_release
    bcf     last_button_state, 0
    call    delay_20ms
    call    ensure_cursor_visible
    return

handle_double_click_timer:
    movf    click_timer, 0
    btfsc   STATUS, Z
    goto    reset_click_detection
    decfsz  click_timer, 1
    return
reset_click_detection:
    clrf    click_count
    clrf    click_timer
    return

increment_current_digit:
    btfsc   current_number, 0
    goto    increment_number2_digit

increment_number1_digit:
    btfsc   current_part, 0
    goto    increment_num1_fractional_digit
    goto    increment_num1_integer_digit

increment_number2_digit:
    btfsc   current_part, 0
    goto    increment_num2_fractional_digit
    goto    increment_num2_integer_digit

increment_num1_integer_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    inc_num1_int_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    inc_num1_int_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    inc_num1_int_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    inc_num1_int_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    inc_num1_int_digit4
    goto    inc_num1_int_digit5

increment_num1_fractional_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    inc_num1_frac_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    inc_num1_frac_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    inc_num1_frac_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    inc_num1_frac_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    inc_num1_frac_digit4
    goto    inc_num1_frac_digit5

increment_num2_integer_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    inc_num2_int_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    inc_num2_int_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    inc_num2_int_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    inc_num2_int_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    inc_num2_int_digit4
    goto    inc_num2_int_digit5

increment_num2_fractional_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    inc_num2_frac_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    inc_num2_frac_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    inc_num2_frac_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    inc_num2_frac_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    inc_num2_frac_digit4
    goto    inc_num2_frac_digit5

inc_num1_int_digit0:
    incf    num1_int_digit0, 1
    movf    num1_int_digit0, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit0
    return

inc_num1_int_digit1:
    incf    num1_int_digit1, 1
    movf    num1_int_digit1, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit1
    return

inc_num1_int_digit2:
    incf    num1_int_digit2, 1
    movf    num1_int_digit2, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit2
    return

inc_num1_int_digit3:
    incf    num1_int_digit3, 1
    movf    num1_int_digit3, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit3
    return

inc_num1_int_digit4:
    incf    num1_int_digit4, 1
    movf    num1_int_digit4, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit4
    return

inc_num1_int_digit5:
    incf    num1_int_digit5, 1
    movf    num1_int_digit5, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_int_digit5
    return

inc_num1_frac_digit0:
    incf    num1_frac_digit0, 1
    movf    num1_frac_digit0, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit0
    return

inc_num1_frac_digit1:
    incf    num1_frac_digit1, 1
    movf    num1_frac_digit1, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit1
    return

inc_num1_frac_digit2:
    incf    num1_frac_digit2, 1
    movf    num1_frac_digit2, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit2
    return

inc_num1_frac_digit3:
    incf    num1_frac_digit3, 1
    movf    num1_frac_digit3, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit3
    return

inc_num1_frac_digit4:
    incf    num1_frac_digit4, 1
    movf    num1_frac_digit4, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit4
    return

inc_num1_frac_digit5:
    incf    num1_frac_digit5, 1
    movf    num1_frac_digit5, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num1_frac_digit5
    return

inc_num2_int_digit0:
    incf    num2_int_digit0, 1
    movf    num2_int_digit0, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit0
    return

inc_num2_int_digit1:
    incf    num2_int_digit1, 1
    movf    num2_int_digit1, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit1
    return

inc_num2_int_digit2:
    incf    num2_int_digit2, 1
    movf    num2_int_digit2, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit2
    return

inc_num2_int_digit3:
    incf    num2_int_digit3, 1
    movf    num2_int_digit3, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit3
    return

inc_num2_int_digit4:
    incf    num2_int_digit4, 1
    movf    num2_int_digit4, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit4
    return

inc_num2_int_digit5:
    incf    num2_int_digit5, 1
    movf    num2_int_digit5, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_int_digit5
    return

inc_num2_frac_digit0:
    incf    num2_frac_digit0, 1
    movf    num2_frac_digit0, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit0
    return

inc_num2_frac_digit1:
    incf    num2_frac_digit1, 1
    movf    num2_frac_digit1, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit1
    return

inc_num2_frac_digit2:
    incf    num2_frac_digit2, 1
    movf    num2_frac_digit2, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit2
    return

inc_num2_frac_digit3:
    incf    num2_frac_digit3, 1
    movf    num2_frac_digit3, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit3
    return

inc_num2_frac_digit4:
    incf    num2_frac_digit4, 1
    movf    num2_frac_digit4, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit4
    return

inc_num2_frac_digit5:
    incf    num2_frac_digit5, 1
    movf    num2_frac_digit5, 0
    sublw   .10
    btfss   STATUS, Z
    return
    clrf    num2_frac_digit5
    return

advance_to_next_digit:
    call    propagate_current_digit_value
    incf    current_digit_pos, 1
    movf    current_digit_pos, 0
    sublw   .6
    btfsc   STATUS, Z
    goto    stay_at_last_digit
    call    display_complete_floating_number
    call    ensure_cursor_visible
    call    show_position_indicator
    return
stay_at_last_digit:
    movlw   .5
    movwf   current_digit_pos
    call    show_last_digit_message
    call    delay_500ms
    call    display_floating_number_prompt
    call    display_complete_floating_number
    call    ensure_cursor_visible
    call    show_position_indicator
    return

propagate_current_digit_value:
    btfsc   current_number, 0
    goto    propagate_number2_digit

propagate_number1_digit:
    btfsc   current_part, 0
    goto    propagate_num1_fractional_digit
    goto    propagate_num1_integer_digit

propagate_number2_digit:
    btfsc   current_part, 0
    goto    propagate_num2_fractional_digit
    goto    propagate_num2_integer_digit

propagate_num1_integer_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    propagate_from_num1_int_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    propagate_from_num1_int_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    propagate_from_num1_int_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    propagate_from_num1_int_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    propagate_from_num1_int_digit4
    goto    propagate_from_num1_int_digit5

propagate_num1_fractional_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    propagate_from_num1_frac_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    propagate_from_num1_frac_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    propagate_from_num1_frac_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    propagate_from_num1_frac_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    propagate_from_num1_frac_digit4
    goto    propagate_from_num1_frac_digit5

propagate_num2_integer_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    propagate_from_num2_int_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    propagate_from_num2_int_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    propagate_from_num2_int_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    propagate_from_num2_int_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    propagate_from_num2_int_digit4
    goto    propagate_from_num2_int_digit5

propagate_num2_fractional_digit:
    movf    current_digit_pos, 0
    btfsc   STATUS, Z
    goto    propagate_from_num2_frac_digit0
    sublw   .1
    btfsc   STATUS, Z
    goto    propagate_from_num2_frac_digit1
    movf    current_digit_pos, 0
    sublw   .2
    btfsc   STATUS, Z
    goto    propagate_from_num2_frac_digit2
    movf    current_digit_pos, 0
    sublw   .3
    btfsc   STATUS, Z
    goto    propagate_from_num2_frac_digit3
    movf    current_digit_pos, 0
    sublw   .4
    btfsc   STATUS, Z
    goto    propagate_from_num2_frac_digit4
    goto    propagate_from_num2_frac_digit5

propagate_from_num1_int_digit0:
    movf    num1_int_digit0, 0
    movwf   num1_int_digit1
    movwf   num1_int_digit2
    movwf   num1_int_digit3
    movwf   num1_int_digit4
    movwf   num1_int_digit5
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_int_digit1:
    movf    num1_int_digit1, 0
    movwf   num1_int_digit2
    movwf   num1_int_digit3
    movwf   num1_int_digit4
    movwf   num1_int_digit5
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_int_digit2:
    movf    num1_int_digit2, 0
    movwf   num1_int_digit3
    movwf   num1_int_digit4
    movwf   num1_int_digit5
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_int_digit3:
    movf    num1_int_digit3, 0
    movwf   num1_int_digit4
    movwf   num1_int_digit5
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_int_digit4:
    movf    num1_int_digit4, 0
    movwf   num1_int_digit5
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_int_digit5:
    movf    num1_int_digit5, 0
    movwf   num1_frac_digit0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit0:
    movf    num1_frac_digit0, 0
    movwf   num1_frac_digit1
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit1:
    movf    num1_frac_digit1, 0
    movwf   num1_frac_digit2
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit2:
    movf    num1_frac_digit2, 0
    movwf   num1_frac_digit3
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit3:
    movf    num1_frac_digit3, 0
    movwf   num1_frac_digit4
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit4:
    movf    num1_frac_digit4, 0
    movwf   num1_frac_digit5
    return

propagate_from_num1_frac_digit5:
    return

propagate_from_num2_int_digit0:
    movf    num2_int_digit0, 0
    movwf   num2_int_digit1
    movwf   num2_int_digit2
    movwf   num2_int_digit3
    movwf   num2_int_digit4
    movwf   num2_int_digit5
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_int_digit1:
    movf    num2_int_digit1, 0
    movwf   num2_int_digit2
    movwf   num2_int_digit3
    movwf   num2_int_digit4
    movwf   num2_int_digit5
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_int_digit2:
    movf    num2_int_digit2, 0
    movwf   num2_int_digit3
    movwf   num2_int_digit4
    movwf   num2_int_digit5
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_int_digit3:
    movf    num2_int_digit3, 0
    movwf   num2_int_digit4
    movwf   num2_int_digit5
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_int_digit4:
    movf    num2_int_digit4, 0
    movwf   num2_int_digit5
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_int_digit5:
    movf    num2_int_digit5, 0
    movwf   num2_frac_digit0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit0:
    movf    num2_frac_digit0, 0
    movwf   num2_frac_digit1
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit1:
    movf    num2_frac_digit1, 0
    movwf   num2_frac_digit2
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit2:
    movf    num2_frac_digit2, 0
    movwf   num2_frac_digit3
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit3:
    movf    num2_frac_digit3, 0
    movwf   num2_frac_digit4
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit4:
    movf    num2_frac_digit4, 0
    movwf   num2_frac_digit5
    return

propagate_from_num2_frac_digit5:
    return

maintain_cursor_visibility:
    btfsc   current_state, 0
    goto    maintain_equals_cursor
    incf    cursor_blink_timer, 1
    movf    cursor_blink_timer, 0
    sublw   .20
    btfss   STATUS, Z
    return
    clrf    cursor_blink_timer
    call    ensure_cursor_visible
    return

maintain_equals_cursor:
    incf    cursor_blink_timer, 1
    movf    cursor_blink_timer, 0
    sublw   .20
    btfss   STATUS, Z
    return
    clrf    cursor_blink_timer
    call    ensure_equals_cursor_visible
    return

ensure_cursor_visible:
    movlw   0xC0
    btfsc   current_part, 0
    goto    fractional_cursor_position
integer_cursor_position:
    addwf   current_digit_pos, 0
    goto    set_cursor_position
fractional_cursor_position:
    addlw   .7
    addwf   current_digit_pos, 0
set_cursor_position:
    call    lcd_cmd
    movlw   0x0F
    call    lcd_cmd
    call    delay_1ms
    return

ensure_equals_cursor_visible:
    movlw   0x88
    call    lcd_cmd
    movlw   0x0F
    call    lcd_cmd
    call    delay_1ms
    return

display_floating_number_prompt:
    btfsc   current_state, 0
    return
    movlw   0x80
    call    lcd_cmd
    btfsc   current_number, 0
    goto    show_number2_prompt
show_number1_prompt:
    movlw   'N'
    call    lcd_write
    movlw   '1'
    call    lcd_write
    goto    show_part_prompt
show_number2_prompt:
    movlw   'N'
    call    lcd_write
    movlw   '2'
    call    lcd_write
show_part_prompt:
    movlw   ' '
    call    lcd_write
    btfsc   current_part, 0
    goto    show_fractional_prompt
show_integer_prompt:
    movlw   'I'
    call    lcd_write
    movlw   'N'
    call    lcd_write
    movlw   'T'
    call    lcd_write
    movlw   ':'
    call    lcd_write
    goto    common_prompt
show_fractional_prompt:
    movlw   'F'
    call    lcd_write
    movlw   'R'
    call    lcd_write
    movlw   'A'
    call    lcd_write
    movlw   'C'
    call    lcd_write
    movlw   ':'
    call    lcd_write
common_prompt:
    movlw   ' '
    call    lcd_write
    movlw   'D'
    call    lcd_write
    movlw   'b'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   'C'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   'k'
    call    lcd_write
    movlw   '='
    call    lcd_write
    movlw   'S'
    call    lcd_write
    movlw   'w'
    call    lcd_write
    return

display_complete_floating_number:
    btfsc   current_state, 0
    return
    movlw   0xC0
    call    lcd_cmd
    btfsc   current_number, 0
    goto    display_number2
display_number1:
    movf    num1_int_digit0, 0
    addlw   '0'
    call    lcd_write
    movf    num1_int_digit1, 0
    addlw   '0'
    call    lcd_write
    movf    num1_int_digit2, 0
    addlw   '0'
    call    lcd_write
    movf    num1_int_digit3, 0
    addlw   '0'
    call    lcd_write
    movf    num1_int_digit4, 0
    addlw   '0'
    call    lcd_write
    movf    num1_int_digit5, 0
    addlw   '0'
    call    lcd_write
    movlw   '.'
    call    lcd_write
    movf    num1_frac_digit0, 0
    addlw   '0'
    call    lcd_write
    movf    num1_frac_digit1, 0
    addlw   '0'
    call    lcd_write
    movf    num1_frac_digit2, 0
    addlw   '0'
    call    lcd_write
    movf    num1_frac_digit3, 0
    addlw   '0'
    call    lcd_write
    movf    num1_frac_digit4, 0
    addlw   '0'
    call    lcd_write
    movf    num1_frac_digit5, 0
    addlw   '0'
    call    lcd_write
    return
display_number2:
    movf    num2_int_digit0, 0
    addlw   '0'
    call    lcd_write
    movf    num2_int_digit1, 0
    addlw   '0'
    call    lcd_write
    movf    num2_int_digit2, 0
    addlw   '0'
    call    lcd_write
    movf    num2_int_digit3, 0
    addlw   '0'
    call    lcd_write
    movf    num2_int_digit4, 0
    addlw   '0'
    call    lcd_write
    movf    num2_int_digit5, 0
    addlw   '0'
    call    lcd_write
    movlw   '.'
    call    lcd_write
    movf    num2_frac_digit0, 0
    addlw   '0'
    call    lcd_write
    movf    num2_frac_digit1, 0
    addlw   '0'
    call    lcd_write
    movf    num2_frac_digit2, 0
    addlw   '0'
    call    lcd_write
    movf    num2_frac_digit3, 0
    addlw   '0'
    call    lcd_write
    movf    num2_frac_digit4, 0
    addlw   '0'
    call    lcd_write
    movf    num2_frac_digit5, 0
    addlw   '0'
    call    lcd_write
    return

show_position_indicator:
    btfsc   current_state, 0
    return
    movlw   0x8E
    call    lcd_cmd
    btfsc   current_number, 0
    goto    show_n2_indicator
    movlw   '1'
    goto    write_number_indicator
show_n2_indicator:
    movlw   '2'
write_number_indicator:
    call    lcd_write
    btfsc   current_part, 0
    goto    show_f_indicator
    movlw   'I'
    goto    write_part_indicator
show_f_indicator:
    movlw   'F'
write_part_indicator:
    call    lcd_write
    movf    current_digit_pos, 0
    addlw   .1
    addlw   '0'
    call    lcd_write
    return

show_equals_sign_display:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   '='
    call    lcd_write
    return

show_part_switch_message:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'N'
    call    lcd_write
    btfsc   current_number, 0
    goto    show_n2_switch
    movlw   '1'
    goto    write_switch_number
show_n2_switch:
    movlw   '2'
write_switch_number:
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   'S'
    call    lcd_write
    movlw   'w'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'c'
    call    lcd_write
    movlw   'h'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   'd'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    btfsc   current_part, 0
    goto    show_switched_to_frac
    movlw   'I'
    call    lcd_write
    movlw   'N'
    call    lcd_write
    movlw   'T'
    call    lcd_write
    goto    show_current_number
show_switched_to_frac:
    movlw   'F'
    call    lcd_write
    movlw   'R'
    call    lcd_write
    movlw   'A'
    call    lcd_write
    movlw   'C'
    call    lcd_write
show_current_number:
    movlw   0xC0
    call    lcd_cmd
    call    display_complete_floating_number
    return

show_number_switch_message:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'S'
    call    lcd_write
    movlw   'w'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'c'
    call    lcd_write
    movlw   'h'
    call    lcd_write
    movlw   'e'
    call    lcd_write
    movlw   'd'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   ' '
    call    lcd_write
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
    movlw   '2'
    call    lcd_write
    movlw   0xC0
    call    lcd_cmd
    call    display_complete_floating_number
    return

show_last_digit_message:
    movlw   0x01
    call    lcd_cmd
    call    delay_20ms
    movlw   0x80
    call    lcd_cmd
    movlw   'N'
    call    lcd_write
    btfsc   current_number, 0
    goto    show_last_n2
    movlw   '1'
    goto    write_last_number
show_last_n2:
    movlw   '2'
write_last_number:
    call    lcd_write
    movlw   ' '
    call    lcd_write
    movlw   'L'
    call    lcd_write
    movlw   'a'
    call    lcd_write
    movlw   's'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   ' '
    call    lcd_write
    btfsc   current_part, 0
    goto    show_last_frac
    movlw   'I'
    call    lcd_write
    movlw   'N'
    call    lcd_write
    movlw   'T'
    call    lcd_write
    goto    show_last_digit_info
show_last_frac:
    movlw   'F'
    call    lcd_write
    movlw   'R'
    call    lcd_write
    movlw   'A'
    call    lcd_write
    movlw   'C'
    call    lcd_write
show_last_digit_info:
    movlw   ' '
    call    lcd_write
    movlw   'D'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   'g'
    call    lcd_write
    movlw   'i'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   0xC0
    call    lcd_cmd
    call    display_complete_floating_number
    return

display_welcome_message:
    movlw   0x80
    call    lcd_cmd
    movlw   'D'
    call    lcd_write
    movlw   'u'
    call    lcd_write
    movlw   'a'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   ' '
    call    lcd_write
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
    movlw   0xC0
    call    lcd_cmd
    movlw   'C'
    call    lcd_write
    movlw   'a'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   'c'
    call    lcd_write
    movlw   'u'
    call    lcd_write
    movlw   'l'
    call    lcd_write
    movlw   'a'
    call    lcd_write
    movlw   't'
    call    lcd_write
    movlw   'o'
    call    lcd_write
    movlw   'r'
    call    lcd_write
    return

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

delay_10ms:
    movlw   .10
    call    delay_ms
    return

delay_500ms:
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