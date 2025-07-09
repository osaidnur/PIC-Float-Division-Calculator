PROCESSOR 16F877A
__CONFIG 0x3731
INCLUDE "P16F877A.INC"

; --- VARIABLES ---
CBLOCK 0x20
delay_ms_count
blink_counter
temp_char
current_digit_value
digit_cursor_pos
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
result_array_0
result_array_1
result_array_2
result_array_3
result_array_4
result_array_5
result_array_6
result_array_7
result_array_8
result_array_9
result_array_10
result_array_11
resultDone
timer1_enabled
button_first_press
screen1
transmit_index
number_transmitted
number2_transmitted
result_received
calculation_done
digit_index
received_digit
; TIMEOUT VARIABLES
timeout_counter
timeout_active
; SIMPLIFIED DOUBLE CLICK DETECTION
click_timer
click_count
; PART TRACKING
current_part ; 0 = integer part, 1 = fractional part
; NEW FEATURE: EQUALS SCREEN STATE
showing_equals_screen
; NEW FEATURE: PROPAGATION VARIABLES
propagation_value
propagation_index
; RESULT DISPLAY CYCLING
result_display_state ; 0 = result, 1 = first number, 2 = second number
result_displayed_once ; Flag to prevent repeated display calls in main loop
ENDC

pushButton EQU 0    ; Button on RB0

; 2 seconds timeout = 2000ms = 200 * 10ms loops
; But since original was moving after 5 seconds when set to 100,
; For 2 seconds we need: 100 * (2/5) = 40
TIMEOUT_2_SECONDS EQU .40

; FIXED: Reduced double-click window from 300ms to 150ms to avoid conflict with fast single clicks
; 150ms = 15 * 10ms loops
DOUBLE_CLICK_TIMEOUT EQU .15

ORG 0x00
GOTO start

ORG 0x04
GOTO ISR_handler

;----------------------------------------MAIN PROGRAM-------------------------------------------------------------
start:
NOP

; Configure I/O ports
BANKSEL TRISD
MOVLW B'00000000'
MOVWF TRISD 
MOVLW B'00000001'
MOVWF TRISB

; Configure USART pins
BANKSEL TRISC
BCF TRISC, 6
BSF TRISC, 7

; Configure interrupt
BANKSEL OPTION_REG
BCF OPTION_REG, INTEDG

; Configure Timer1 for 10ms interrupts
BANKSEL T1CON
MOVLW B'00110001'
MOVWF T1CON

; Set Timer1 initial value for 10ms overflow
BANKSEL TMR1H
MOVLW 0xEC
MOVWF TMR1H
MOVLW 0x78
MOVWF TMR1L

; Configure Timer1 interrupt
BANKSEL PIE1
BSF PIE1, TMR1IE
BANKSEL PIR1
BCF PIR1, TMR1IF

; Initialize USART
CALL init_master_usart

; Return to bank 0
BANKSEL PORTD
CLRF PORTD

; Initialize all variables
clrf digit_cursor_pos
clrf current_part
clrf digit_array1_0
clrf digit_array1_1
clrf digit_array1_2
clrf digit_array1_3
clrf digit_array1_4
clrf digit_array1_5
clrf digit_array1_6
clrf digit_array1_7
clrf digit_array1_8
clrf digit_array1_9
clrf digit_array1_10
clrf digit_array1_11
clrf digit_array2_0
clrf digit_array2_1
clrf digit_array2_2
clrf digit_array2_3
clrf digit_array2_4
clrf digit_array2_5
clrf digit_array2_6
clrf digit_array2_7
clrf digit_array2_8
clrf digit_array2_9
clrf digit_array2_10
clrf digit_array2_11
clrf result_array_0
clrf result_array_1
clrf result_array_2
clrf result_array_3
clrf result_array_4
clrf result_array_5
clrf result_array_6
clrf result_array_7
clrf result_array_8
clrf result_array_9
clrf result_array_10
clrf result_array_11
clrf resultDone
clrf current_digit_value
clrf timer1_enabled
clrf button_first_press
clrf screen1
clrf transmit_index
clrf number_transmitted
clrf number2_transmitted
clrf result_received
clrf calculation_done
clrf digit_index
movlw TIMEOUT_2_SECONDS
movwf timeout_counter
clrf timeout_active
clrf click_timer
clrf click_count
; Initialize new equals screen state
clrf showing_equals_screen
; Initialize propagation variables
clrf propagation_value
clrf propagation_index
; Initialize result display cycling
clrf result_display_state
clrf result_displayed_once

; Initialize LCD
CALL inid

; Show welcome message
CALL print_welcome

; Blink display 3 times
movlw .3
movwf blink_counter
blink_loop:
CALL delay_500ms
MOVLW 0x08
CALL lcd_cmd
CALL delay_500ms
MOVLW 0x0c
CALL lcd_cmd
decfsz blink_counter, 1
goto blink_loop

; Delay before starting input
CALL delay_500ms
CALL delay_500ms
CALL delay_500ms
CALL delay_500ms

; Show first number input screen
CALL show_the_first_num

; Start timeout
CALL start_timeout

; Enable interrupts
BANKSEL INTCON
BSF INTCON, INTE
BSF INTCON, PEIE
BSF INTCON, GIE
BCF INTCON, INTF

main_loop:
; Check if showing equals screen
btfsc showing_equals_screen, 0
goto main_loop_continue
; Check if calculation is done and display result (only once)
btfsc calculation_done, 0
goto handle_result_mode
main_loop_continue:
goto main_loop

handle_result_mode:
; Check if we've already displayed the result
btfsc result_displayed_once, 0
goto main_loop_continue
; Display result for the first time
call display_result_screen
; Mark that we've displayed the result
bsf result_displayed_once, 0
goto main_loop_continue

;----------------------------------------INTERRUPT SERVICE ROUTINE-------------------------------------------------------------
ISR_handler:
movwf temp_char

; Check what caused the interrupt
BANKSEL PIR1
btfsc PIR1, TMR1IF
goto timer1_interrupt

; External interrupt (button press)
BANKSEL INTCON
btfsc INTCON, INTF
goto button_interrupt


BTFSS   PIR1, RCIF         ; Check if the USART received a byte
GOTO    isr_exit           ; If not, exit interrupt, if yes, read the value
BANKSEL RCREG
MOVF    RCREG, 0           ; Read received byte from UART
MOVWF   received_digit     ; Store it in 'received_digit'
goto readResult

goto isr_exit

readResult:
MOVF    digit_index, 0
ADDLW   result_array_0
MOVWF   FSR
MOVF    received_digit, 0
MOVWF   INDF
INCF    digit_index, 1
MOVF    digit_index, 0
SUBLW   .12
BTFSS   STATUS, Z
GOTO    isr_exit
MOVLW   .1
MOVWF   calculation_done
; Clear equals screen flag since we're now showing result
bcf     showing_equals_screen, 0
CLRF    digit_index
; Let main loop handle display - don't call display functions from ISR
GOTO    isr_exit

timer1_interrupt:
; Clear Timer1 interrupt flag
BANKSEL PIR1
BCF PIR1, TMR1IF

; Reload Timer1 for next 10ms
BANKSEL TMR1H
MOVLW 0xEC
MOVWF TMR1H
MOVLW 0x78
MOVWF TMR1L

; Handle click timer for double-click detection
movf click_timer, 0
btfsc STATUS, Z
goto check_main_timeout
decfsz click_timer, 1
goto check_main_timeout
; Click timer expired - reset click count
clrf click_count

check_main_timeout:
; Skip timeout if showing equals screen
btfsc showing_equals_screen, 0
goto isr_exit

; Check if main timeout is active
btfss timeout_active, 0
goto isr_exit

; Decrement main timeout counter
decfsz timeout_counter, 1
goto isr_exit

; FIXED: Simple timeout occurred - do propagation and advance in one atomic operation
; First, disable timeout to prevent re-entry
bcf timeout_active, 0

; Do propagation
call do_propagation_only

; Advance cursor
call do_cursor_advance_only

; Re-enable timeout with fresh 2-second counter
movlw TIMEOUT_2_SECONDS
movwf timeout_counter
bsf timeout_active, 0

goto isr_exit

button_interrupt:
; Clear the interrupt flag
BANKSEL INTCON
BCF INTCON, INTF

; Simple debounce
call debounce

; Check if button is still pressed (active low)
btfsc PORTB, pushButton
goto isr_exit

; Handle button click
call handle_button_click

isr_exit:
movf temp_char, 0
RETFIE

;----------------------------------------FIXED: SIMPLIFIED PROPAGATION FUNCTIONS-------------------------------------------------------------
do_propagation_only:
; Simple propagation without any timeout manipulation
movlw .1
subwf screen1, 0
btfss STATUS, Z
goto do_prop_num1
; Screen 2 - Number 2
call get_digit_value_num2
call propagate_remaining_num2
; Update display
MOVLW 0xc0
CALL lcd_cmd
CALL display_all_digits_2
return

do_prop_num1:
; Screen 1 - Number 1
call get_digit_value_num1
call propagate_remaining_num1
; Update display
MOVLW 0xc0
CALL lcd_cmd
CALL display_all_digits_1
return

; NEW FEATURE: Propagation for double-click transitions
do_propagation_for_double_click:
; Propagate current digit before transitioning
movlw .1
subwf screen1, 0
btfss STATUS, Z
goto prop_double_click_num1
; Screen 2 - Number 2
call get_digit_value_num2
call propagate_remaining_num2
return

prop_double_click_num1:
; Screen 1 - Number 1
call get_digit_value_num1
call propagate_remaining_num1
return

do_cursor_advance_only:
; Simple cursor advancement without timeout manipulation
btfsc current_part, 0
goto advance_frac_simple
goto advance_int_simple

advance_int_simple:
; Advance in integer part (0-5)
incf digit_cursor_pos, 1
movf digit_cursor_pos, 0
sublw .6
btfsc STATUS, Z
goto stay_at_int_end_simple
; Position cursor and enable blinking
movlw 0x0F
call lcd_cmd
call position_cursor
return

stay_at_int_end_simple:
movlw .5
movwf digit_cursor_pos
movlw 0x0F
call lcd_cmd
call position_cursor
return

advance_frac_simple:
; Advance in fractional part (7-12)
incf digit_cursor_pos, 1
movf digit_cursor_pos, 0
sublw .13
btfsc STATUS, Z
goto stay_at_frac_end_simple
; Position cursor and enable blinking
movlw 0x0F
call lcd_cmd
call position_cursor
return

stay_at_frac_end_simple:
movlw .12
movwf digit_cursor_pos
movlw 0x0F
call lcd_cmd
call position_cursor
return

get_digit_value_num1:
; Get value of current digit in number 1
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto get_frac_digit_1
; Integer digit (positions 0-5)
movf digit_cursor_pos, 0
addlw digit_array1_0
movwf FSR
movf INDF, 0
movwf propagation_value
return
get_frac_digit_1:
; Fractional digit (positions 7-12, map to array indices 6-11)
movf digit_cursor_pos, 0
addlw .255              ; Subtract 1 (adjust for decimal point)
addlw digit_array1_0
movwf FSR
movf INDF, 0
movwf propagation_value
return

get_digit_value_num2:
; Get value of current digit in number 2
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto get_frac_digit_2
; Integer digit (positions 0-5)
movf digit_cursor_pos, 0
addlw digit_array2_0
movwf FSR
movf INDF, 0
movwf propagation_value
return
get_frac_digit_2:
; Fractional digit (positions 7-12, map to array indices 6-11)
movf digit_cursor_pos, 0
addlw .255              ; Subtract 1 (adjust for decimal point)
addlw digit_array2_0
movwf FSR
movf INDF, 0
movwf propagation_value
return

propagate_remaining_num1:
; Propagate to all remaining digits in number 1 (both integer and fractional)
movf digit_cursor_pos, 0
addlw .1                ; Start from next position
movwf propagation_index

prop_loop_1:
; Check if we've reached the end of all digits (position 13)
movf propagation_index, 0
sublw .13
btfsc STATUS, Z
return                  ; End of propagation

; Skip position 6 (decimal point)
movf propagation_index, 0
sublw .6
btfsc STATUS, Z
goto skip_decimal_1

; Map position to array index
movf propagation_index, 0
sublw .6
btfss STATUS, C
goto prop_frac_1

; Integer position (0-5)
movf propagation_index, 0
addlw digit_array1_0
movwf FSR
movf propagation_value, 0
movwf INDF
goto next_pos_1

prop_frac_1:
; Fractional position (7-12, map to array indices 6-11)
movf propagation_index, 0
addlw .255              ; Subtract 1
addlw digit_array1_0
movwf FSR
movf propagation_value, 0
movwf INDF
goto next_pos_1

skip_decimal_1:
; Skip decimal point position
goto next_pos_1

next_pos_1:
incf propagation_index, 1
goto prop_loop_1

propagate_remaining_num2:
; Propagate to all remaining digits in number 2 (both integer and fractional)
movf digit_cursor_pos, 0
addlw .1                ; Start from next position
movwf propagation_index

prop_loop_2:
; Check if we've reached the end of all digits (position 13)
movf propagation_index, 0
sublw .13
btfsc STATUS, Z
return                  ; End of propagation

; Skip position 6 (decimal point)
movf propagation_index, 0
sublw .6
btfsc STATUS, Z
goto skip_decimal_2

; Map position to array index
movf propagation_index, 0
sublw .6
btfss STATUS, C
goto prop_frac_2

; Integer position (0-5)
movf propagation_index, 0
addlw digit_array2_0
movwf FSR
movf propagation_value, 0
movwf INDF
goto next_pos_2

prop_frac_2:
; Fractional position (7-12, map to array indices 6-11)
movf propagation_index, 0
addlw .255              ; Subtract 1
addlw digit_array2_0
movwf FSR
movf propagation_value, 0
movwf INDF
goto next_pos_2

skip_decimal_2:
; Skip decimal point position
goto next_pos_2

next_pos_2:
incf propagation_index, 1
goto prop_loop_2

;----------------------------------------BUTTON HANDLING-------------------------------------------------------------
handle_button_click:
; Check if calculation is done - handle result display cycling
btfsc calculation_done, 0
goto handle_result_display_cycling

; Check if we're showing equals screen (before calculation)
btfsc showing_equals_screen, 0
goto handle_equals_screen_click

; Normal button handling for input screens
; Reset main timeout when any button press occurs
call restart_main_timeout

; Increment click count
incf click_count, 1

; Start/restart click timer for double-click window
movlw DOUBLE_CLICK_TIMEOUT
movwf click_timer

; Check click count
movf click_count, 0
sublw .1
btfsc STATUS, Z
goto handle_single_click

movf click_count, 0
sublw .2
btfsc STATUS, Z
goto handle_double_click

; More than 2 clicks - reset and treat as single click
; ENHANCED: If more than 2 clicks, treat them as rapid single clicks
clrf click_count
clrf click_timer
; Process as single click
goto handle_single_click

handle_result_display_cycling:
; Reset main timeout when any button press occurs
call restart_main_timeout

; Increment click count
incf click_count, 1

; Start/restart click timer for double-click window
movlw DOUBLE_CLICK_TIMEOUT
movwf click_timer

; Check for double-click to restart the process
movf click_count, 0
sublw .2
btfsc STATUS, Z
goto restart_calculator_process

; Single click - cycle through display states: 0=result, 1=first number, 2=second number
movf click_count, 0
sublw .1
btfsc STATUS, Z
goto handle_single_result_click

; More than 2 clicks - reset and treat as single click
clrf click_count
clrf click_timer
goto handle_single_result_click

handle_single_result_click:
incf result_display_state, 1
movf result_display_state, 0
sublw .3
btfsc STATUS, Z
clrf result_display_state

; Display based on current state
movf result_display_state, 0
sublw .0
btfsc STATUS, Z
goto display_result_again

movf result_display_state, 0
sublw .1
btfsc STATUS, Z
goto display_first_number_on_result

movf result_display_state, 0
sublw .2
btfsc STATUS, Z
goto display_second_number_on_result

return

restart_calculator_process:
; Reset all system variables to initial state
NOP

; Configure I/O ports
BANKSEL TRISD
MOVLW B'00000000'
MOVWF TRISD 
MOVLW B'00000001'
MOVWF TRISB

; Configure USART pins
BANKSEL TRISC
BCF TRISC, 6
BSF TRISC, 7

; Configure interrupt
BANKSEL OPTION_REG
BCF OPTION_REG, INTEDG

; Configure Timer1 for 10ms interrupts
BANKSEL T1CON
MOVLW B'00110001'
MOVWF T1CON

; Set Timer1 initial value for 10ms overflow
BANKSEL TMR1H
MOVLW 0xEC
MOVWF TMR1H
MOVLW 0x78
MOVWF TMR1L

; Configure Timer1 interrupt
BANKSEL PIE1
BSF PIE1, TMR1IE
BANKSEL PIR1
BCF PIR1, TMR1IF

; Initialize USART
CALL init_master_usart

; Return to bank 0
BANKSEL PORTD
CLRF PORTD

; Initialize all variables
clrf digit_cursor_pos
clrf current_part
clrf digit_array1_0
clrf digit_array1_1
clrf digit_array1_2
clrf digit_array1_3
clrf digit_array1_4
clrf digit_array1_5
clrf digit_array1_6
clrf digit_array1_7
clrf digit_array1_8
clrf digit_array1_9
clrf digit_array1_10
clrf digit_array1_11
clrf digit_array2_0
clrf digit_array2_1
clrf digit_array2_2
clrf digit_array2_3
clrf digit_array2_4
clrf digit_array2_5
clrf digit_array2_6
clrf digit_array2_7
clrf digit_array2_8
clrf digit_array2_9
clrf digit_array2_10
clrf digit_array2_11
clrf result_array_0
clrf result_array_1
clrf result_array_2
clrf result_array_3
clrf result_array_4
clrf result_array_5
clrf result_array_6
clrf result_array_7
clrf result_array_8
clrf result_array_9
clrf result_array_10
clrf result_array_11
clrf resultDone
clrf current_digit_value
clrf timer1_enabled
clrf button_first_press
clrf screen1
clrf transmit_index
clrf number_transmitted
clrf number2_transmitted
clrf result_received
clrf calculation_done
clrf digit_index
movlw TIMEOUT_2_SECONDS
movwf timeout_counter
clrf timeout_active
clrf click_timer
clrf click_count
; Initialize new equals screen state
clrf showing_equals_screen
; Initialize propagation variables
clrf propagation_value
clrf propagation_index
; Initialize result display cycling
clrf result_display_state
clrf result_displayed_once

; Show first number input screen and restart the process
call show_the_first_num
call start_timeout
return

handle_equals_screen_click:
; User clicked on equals screen to start calculation
; The calculation will happen automatically via USART, just clear equals screen flag
bcf showing_equals_screen, 0
return

cycle_result_display:
; This function is now handled by handle_result_display_cycling
; Keeping this label for compatibility but redirecting to the new function
goto handle_result_display_cycling

display_result_again:
; Show result again
call display_result_screen
return

display_first_number_on_result:
; Clear screen and show first number on first line
movlw 0x01
call lcd_cmd
movlw 0x0C
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'N'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'b'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'r'
CALL lcd_data
MOVLW '1'
CALL lcd_data
MOVLW ':'
CALL lcd_data

movlw 0xc0
call lcd_cmd


; Display first number
movf digit_array1_0, 0
addlw '0'
call lcd_data
movf digit_array1_1, 0
addlw '0'
call lcd_data
movf digit_array1_2, 0
addlw '0'
call lcd_data
movf digit_array1_3, 0
addlw '0'
call lcd_data
movf digit_array1_4, 0
addlw '0'
call lcd_data
movf digit_array1_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf digit_array1_6, 0
addlw '0'
call lcd_data
movf digit_array1_7, 0
addlw '0'
call lcd_data
movf digit_array1_8, 0
addlw '0'
call lcd_data
movf digit_array1_9, 0
addlw '0'
call lcd_data
movf digit_array1_10, 0
addlw '0'
call lcd_data
movf digit_array1_11, 0
addlw '0'
call lcd_data
return

display_second_number_on_result:
; Clear screen and show second number on first line
movlw 0x01
call lcd_cmd
movlw 0x0C
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'N'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'b'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'r'
CALL lcd_data
MOVLW '2'
CALL lcd_data
MOVLW ':'
CALL lcd_data

movlw 0xc0
call lcd_cmd

; Display second number
movf digit_array2_0, 0
addlw '0'
call lcd_data
movf digit_array2_1, 0
addlw '0'
call lcd_data
movf digit_array2_2, 0
addlw '0'
call lcd_data
movf digit_array2_3, 0
addlw '0'
call lcd_data
movf digit_array2_4, 0
addlw '0'
call lcd_data
movf digit_array2_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf digit_array2_6, 0
addlw '0'
call lcd_data
movf digit_array2_7, 0
addlw '0'
call lcd_data
movf digit_array2_8, 0
addlw '0'
call lcd_data
movf digit_array2_9, 0
addlw '0'
call lcd_data
movf digit_array2_10, 0
addlw '0'
call lcd_data
movf digit_array2_11, 0
addlw '0'
call lcd_data
return

handle_single_click:
; Just increment the current digit - no cursor movement
movlw .1
subwf screen1, 0
btfss STATUS, Z
goto single_click_screen1
call increment_current_digit_2
call update_single_digit_display_2
return

single_click_screen1:
call increment_current_digit_1
call update_single_digit_display_1
return

handle_double_click:
; Reset click detection immediately
clrf click_count
clrf click_timer

; Stop main timeout during transition
call stop_main_timeout

; NEW FEATURE: Do propagation before any double-click transition
call do_propagation_for_double_click

; Handle double-click based on current state
movlw .1
subwf screen1, 0
btfss STATUS, Z
goto double_click_screen1

; Screen 2 (Number 2)
btfsc current_part, 0
goto move_to_equals_screen  ; Show equals screen
goto move_to_fractional_part2

double_click_screen1:
; Screen 1 (Number 1)
btfsc current_part, 0
goto move_to_number2
goto move_to_fractional_part1

move_to_fractional_part1:
; Switch to fractional part (propagation already done)
bsf current_part, 0
movlw .7
movwf digit_cursor_pos
call show_the_first_num_fractional
call restart_main_timeout
return

move_to_number2:
; Move to second number (propagation already done)
; First transmit the first number
movf number_transmitted, 0
sublw .0
btfss STATUS, Z
goto skip_transmission
call transmit_first_number_to_slave
movlw .1
movwf number_transmitted

skip_transmission:
; Reset states for second number input - EXACTLY like first number
clrf current_part      ; Reset to integer part
clrf digit_cursor_pos  ; Reset to first digit position
; Clear click states
clrf click_count
clrf click_timer
; Show second number screen
call show_the_second_num
; Start fresh timeout for second number
call restart_main_timeout
return

move_to_fractional_part2:
; Switch to fractional part (propagation already done)
bsf current_part, 0
movlw .7
movwf digit_cursor_pos
call show_the_second_num_fractional
call restart_main_timeout
return

move_to_equals_screen:
; Show equals screen (propagation already done)
; First transmit second number if not already done
movf number2_transmitted, 0
sublw .0
btfss STATUS, Z
goto skip_second_transmission
call transmit_second_number_to_slave
movlw .1
movwf number2_transmitted

skip_second_transmission:
; Show equals screen
call show_equals_screen
; Set equals screen flag
bsf showing_equals_screen, 0
; Stop timeout since we're waiting for user action
call stop_main_timeout
return

start_calculation_process:
; ; Called when user clicks while on equals screen
; ; Clear equals screen flag
; bcf showing_equals_screen, 0
; ; Start calculation
; call receive_result_from_slave
; bsf calculation_done, 0
; call stop_main_timeout
return

;----------------------------------------TIMEOUT FUNCTIONS-------------------------------------------------------------
start_timeout:
movlw TIMEOUT_2_SECONDS
movwf timeout_counter
bsf timeout_active, 0
return

restart_main_timeout:
movlw TIMEOUT_2_SECONDS
movwf timeout_counter
bsf timeout_active, 0
return

stop_main_timeout:
bcf timeout_active, 0
return

display_result_received:
    MOVLW   0x01
    CALL    lcd_cmd
    MOVLW   0x80
    CALL    lcd_cmd
    MOVLW 0xc0
CALL lcd_cmd

movf result_array_0, 0
addlw '0'
call lcd_data
movf result_array_1, 0
addlw '0'
call lcd_data
movf result_array_2, 0
addlw '0'
call lcd_data
movf result_array_3, 0
addlw '0'
call lcd_data
movf result_array_4, 0
addlw '0'
call lcd_data
movf result_array_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf result_array_6, 0
addlw '0'
call lcd_data
movf result_array_7, 0
addlw '0'
call lcd_data
movf result_array_8, 0
addlw '0'
call lcd_data
movf result_array_9, 0
addlw '0'
call lcd_data
movf result_array_10, 0
addlw '0'
call lcd_data
movf result_array_11, 0
addlw '0'
call lcd_data
RETURN



;----------------------------------------LCD FUNCTIONS-------------------------------------------------------------
lcd_data:
BSF Select,RS
CALL send
RETURN

lcd_cmd:
BCF Select,RS
CALL send
RETURN

print_welcome:
MOVLW 0x80
CALL lcd_cmd
MOVLW 'W'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'l'
CALL lcd_data
MOVLW 'c'
CALL lcd_data
MOVLW 'o'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW ' '
CALL lcd_data
MOVLW 't'
CALL lcd_data
MOVLW 'o'
CALL lcd_data

MOVLW 0xc0
CALL lcd_cmd
MOVLW 'D'
CALL lcd_data
MOVLW 'i'
CALL lcd_data
MOVLW 'v'
CALL lcd_data
MOVLW 'i'
CALL lcd_data
MOVLW 's'
CALL lcd_data
MOVLW 'i'
CALL lcd_data
MOVLW 'o'
CALL lcd_data
MOVLW 'n'
CALL lcd_data
RETURN

show_the_first_num:
clrf current_part
clrf digit_cursor_pos

movlw 0x01
call lcd_cmd
movlw 0x0F
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'N'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'b'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'r'
CALL lcd_data
MOVLW ' '
CALL lcd_data
MOVLW '1'
CALL lcd_data

MOVLW 0xc0
CALL lcd_cmd

CALL display_all_digits_1
CALL position_cursor
RETURN

show_the_first_num_fractional:
movlw 0x01
call lcd_cmd
movlw 0x0F
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'N'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'b'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'r'
CALL lcd_data
MOVLW ' '
CALL lcd_data
MOVLW '1'
CALL lcd_data


MOVLW 0xc0
CALL lcd_cmd

CALL display_all_digits_1
CALL position_cursor
RETURN

show_the_second_num:
; Don't reset current_part and digit_cursor_pos here
; They should already be set by the calling function

movlw 0x01
movwf screen1         ; Set to screen 2
call lcd_cmd
movlw 0x0F
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'N'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'm'
CALL lcd_data
MOVLW 'b'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 'r'
CALL lcd_data
MOVLW ' '
CALL lcd_data
MOVLW '2'
CALL lcd_data
CALL delay_500ms
CALL delay_500ms

movlw 0x01
movwf screen1         ; Set to screen 2
call lcd_cmd
movlw 0x0F
call lcd_cmd

MOVLW 0xc0
CALL lcd_cmd

CALL display_all_digits_2
CALL position_cursor
RETURN

show_the_second_num_fractional:
movlw 0x01
call lcd_cmd
movlw 0x0F
call lcd_cmd

MOVLW 0xc0
CALL lcd_cmd

CALL display_all_digits_2
CALL position_cursor
RETURN

; NEW FEATURE: Show equals screen with "=" on the left
show_equals_screen:
movlw 0x01
call lcd_cmd
movlw 0x0C            ; Display on, cursor off (no blinking cursor needed)
call lcd_cmd

; Position cursor at the leftmost position of first line and display equals sign
MOVLW 0x80            ; Leftmost position of first line (position 0)
CALL lcd_cmd
MOVLW '='
CALL lcd_data
RETURN

display_all_digits_1:
movf digit_array1_0, 0
addlw '0'
call lcd_data
movf digit_array1_1, 0
addlw '0'
call lcd_data
movf digit_array1_2, 0
addlw '0'
call lcd_data
movf digit_array1_3, 0
addlw '0'
call lcd_data
movf digit_array1_4, 0
addlw '0'
call lcd_data
movf digit_array1_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf digit_array1_6, 0
addlw '0'
call lcd_data
movf digit_array1_7, 0
addlw '0'
call lcd_data
movf digit_array1_8, 0
addlw '0'
call lcd_data
movf digit_array1_9, 0
addlw '0'
call lcd_data
movf digit_array1_10, 0
addlw '0'
call lcd_data
movf digit_array1_11, 0
addlw '0'
call lcd_data
RETURN

display_all_digits_2:
movf digit_array2_0, 0
addlw '0'
call lcd_data
movf digit_array2_1, 0
addlw '0'
call lcd_data
movf digit_array2_2, 0
addlw '0'
call lcd_data
movf digit_array2_3, 0
addlw '0'
call lcd_data
movf digit_array2_4, 0
addlw '0'
call lcd_data
movf digit_array2_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf digit_array2_6, 0
addlw '0'
call lcd_data
movf digit_array2_7, 0
addlw '0'
call lcd_data
movf digit_array2_8, 0
addlw '0'
call lcd_data
movf digit_array2_9, 0
addlw '0'
call lcd_data
movf digit_array2_10, 0
addlw '0'
call lcd_data
movf digit_array2_11, 0
addlw '0'
call lcd_data
RETURN

display_result_screen:
call stop_main_timeout

; Reset display state to show result
clrf result_display_state

movlw 0x01
call lcd_cmd
movlw 0x0C
call lcd_cmd

MOVLW 0x80
CALL lcd_cmd
MOVLW 'R'
CALL lcd_data
MOVLW 'e'
CALL lcd_data
MOVLW 's'
CALL lcd_data
MOVLW 'u'
CALL lcd_data
MOVLW 'l'
CALL lcd_data
MOVLW 't'
CALL lcd_data
MOVLW ':'
CALL lcd_data

MOVLW 0xc0
CALL lcd_cmd
movf result_array_0, 0
addlw '0'
call lcd_data
movf result_array_1, 0
addlw '0'
call lcd_data
movf result_array_2, 0
addlw '0'
call lcd_data
movf result_array_3, 0
addlw '0'
call lcd_data
movf result_array_4, 0
addlw '0'
call lcd_data
movf result_array_5, 0
addlw '0'
call lcd_data
MOVLW '.'
CALL lcd_data
movf result_array_6, 0
addlw '0'
call lcd_data
movf result_array_7, 0
addlw '0'
call lcd_data
movf result_array_8, 0
addlw '0'
call lcd_data
movf result_array_9, 0
addlw '0'
call lcd_data
movf result_array_10, 0
addlw '0'
call lcd_data
movf result_array_11, 0
addlw '0'
call lcd_data
return

position_cursor:
movf digit_cursor_pos, 0
addlw 0xC0
call lcd_cmd
return

;----------------------------------------DIGIT MANIPULATION FUNCTIONS-------------------------------------------------------------
increment_current_digit_1:
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto adjust_index_1
movf digit_cursor_pos, 0
addlw digit_array1_0
movwf FSR
goto increment_digit_1
adjust_index_1:
movf digit_cursor_pos, 0
addlw .255
addlw digit_array1_0
movwf FSR
increment_digit_1:
incf INDF, 1
movf INDF, 0
sublw .10
btfsc STATUS, Z
clrf INDF
return

increment_current_digit_2:
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto adjust_index_2
movf digit_cursor_pos, 0
addlw digit_array2_0
movwf FSR
goto increment_digit_2
adjust_index_2:
movf digit_cursor_pos, 0
addlw .255
addlw digit_array2_0
movwf FSR
increment_digit_2:
incf INDF, 1
movf INDF, 0
sublw .10
btfsc STATUS, Z
clrf INDF
return

update_single_digit_display_1:
movf digit_cursor_pos, 0
addlw 0xC0
call lcd_cmd
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto adjust_display_index_1
movf digit_cursor_pos, 0
addlw digit_array1_0
movwf FSR
goto display_digit_1
adjust_display_index_1:
movf digit_cursor_pos, 0
addlw .255
addlw digit_array1_0
movwf FSR
display_digit_1:
movf INDF, 0
addlw '0'
call lcd_data
movf digit_cursor_pos, 0
addlw 0xC0
call lcd_cmd
return

update_single_digit_display_2:
movf digit_cursor_pos, 0
addlw 0xC0
call lcd_cmd
movf digit_cursor_pos, 0
sublw .6
btfss STATUS, C
goto adjust_display_index_2
movf digit_cursor_pos, 0
addlw digit_array2_0
movwf FSR
goto display_digit_2
adjust_display_index_2:
movf digit_cursor_pos, 0
addlw .255
addlw digit_array2_0
movwf FSR
display_digit_2:
movf INDF, 0
addlw '0'
call lcd_data
movf digit_cursor_pos, 0
addlw 0xC0
call lcd_cmd
return

debounce:
movlw .10
call delay_ms
return

;----------------------------------------DELAY ROUTINES-------------------------------------------------------------
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

;----------------------------------------USART COMMUNICATION SUBROUTINES-------------------------------------------------------------
init_master_usart:
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

show_the_second_num_and_transmit:
MOVF number_transmitted, 0
SUBLW .0
BTFSS STATUS, Z
GOTO just_show_second_num
CALL transmit_first_number_to_slave
MOVLW .1
MOVWF number_transmitted
just_show_second_num:
CALL show_the_second_num
RETURN

transmit_first_number_to_slave:
CLRF transmit_index
transmit_loop:
MOVF transmit_index, 0
ADDLW digit_array1_0
MOVWF FSR
MOVF INDF, 0
CALL usart_send_byte
CALL delay_5ms
INCF transmit_index, 1
MOVF transmit_index, 0
SUBLW .12
BTFSS STATUS, Z
GOTO transmit_loop
RETURN

transmit_second_number_to_slave:
CLRF transmit_index
transmit_loop_2:
MOVF transmit_index, 0
ADDLW digit_array2_0
MOVWF FSR
MOVF INDF, 0
CALL usart_send_byte
CALL delay_5ms
INCF transmit_index, 1
MOVF transmit_index, 0
SUBLW .12
BTFSS STATUS, Z
GOTO transmit_loop_2
RETURN


usart_send_byte:
BANKSEL TXSTA
BTFSS TXSTA, TRMT
GOTO $-1
BANKSEL TXREG
MOVWF TXREG
RETURN


INCLUDE "LCDIS.INC"
END