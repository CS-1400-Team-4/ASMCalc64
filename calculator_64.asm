section .data
    ; Prompts and messages for user interaction
    prompt_msg db "Enter operation (+ - * / q to quit): ", 0   ; Prompt for calculator operation
    prompt_len equ $ - prompt_msg                              ; Calculate prompt message length
    num1_msg db "Enter first number: ", 0xa                    ; Prompt for first number
    num1_len equ $ - num1_msg                                  ; Calculate first number prompt length
    num2_msg db "Enter second number: ", 0xa                   ; Prompt for second number
    num2_len equ $ - num2_msg                                  ; Calculate second number prompt length
    result_msg db "Result: "                                   ; Result message prefix
    result_len equ $ - result_msg                              ; Calculate result message length
    div_zero_msg db "Error: Division by zero!", 0xa            ; Division by zero error message
    div_zero_len equ $ - div_zero_msg                          ; Calculate division by zero message length
    invalid_op_msg db "Error: Invalid operation!", 0xa         ; Invalid operation error message
    invalid_op_len equ $ - invalid_op_msg                      ; Calculate invalid operation message length
    
    ; Debug messages for tracing number inputs
    debug_num1 db "Debug - First number: ", 0                  ; Debug message for first number
    debug_num1_len equ $ - debug_num1                          ; Calculate debug first number message length
    debug_num2 db "Debug - Second number: ", 0                 ; Debug message for second number
    debug_num2_len equ $ - debug_num2                          ; Calculate debug second number message length
    newline db 0xa                                             ; Newline character for formatting

section .bss
    ; Buffer and variable reservations for runtime data
    operation resb 2    ; Buffer to store user-input operation
    num1 resb 32        ; Buffer to store first number as string
    num2 resb 32        ; Buffer to store second number as string
    result resb 32      ; Buffer to store result
    num1_val resq 1     ; 64-bit storage for first number's numeric value
    num2_val resq 1     ; 64-bit storage for second number's numeric value
    debug_buf resb 32   ; Temporary buffer for number conversion and printing

section .text
    global _start       ; Entry point for the program

_start:
calculator_loop:
    ; Display operation prompt and get user input
    mov rax, 1          ; sys_write syscall
    mov rdi, 1          ; File descriptor (stdout)
    mov rsi, prompt_msg ; Message to display
    mov rdx, prompt_len ; Message length
    syscall
    
    ; Read user's operation choice
    mov rax, 0          ; sys_read syscall
    mov rdi, 0          ; File descriptor (stdin)
    mov rsi, operation  ; Buffer to store input
    mov rdx, 2          ; Read 2 bytes (operation + newline)
    syscall
    
    ; Check if user wants to quit
    mov al, [operation]
    cmp al, 'q'         ; Compare input with 'q'
    je exit_program     ; Exit if 'q' is entered
    
    ; Prompt and read first number (with similar syscalls as operation input)
    mov rax, 1
    mov rdi, 1
    mov rsi, num1_msg
    mov rdx, num1_len
    syscall
    
    mov rax, 0
    mov rdi, 0
    mov rsi, num1
    mov rdx, 32
    syscall
    
    ; Convert first number from string to integer
    mov rsi, num1
    call string_to_int
    mov [num1_val], rax    ; Store converted first number
    
    ; Optional debug output for first number
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, debug_num1
    mov rdx, debug_num1_len
    syscall
    pop rax
    
    push rax
    call print_number   ; Print the converted number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax
    
    ; Repeat similar process for second number
    mov rax, 1
    mov rdi, 1
    mov rsi, num2_msg
    mov rdx, num2_len
    syscall
    
    mov rax, 0
    mov rdi, 0
    mov rsi, num2
    mov rdx, 32
    syscall
    
    mov rsi, num2
    call string_to_int
    mov [num2_val], rax    ; Store converted second number
    
    ; Optional debug output for second number
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, debug_num2
    mov rdx, debug_num2_len
    syscall
    pop rax
    
    push rax
    call print_number
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    pop rax
    
    ; Load numbers for arithmetic operation
    mov rax, [num1_val]
    mov rbx, [num2_val]
    
    ; Determine and perform arithmetic operation based on user input
    mov cl, [operation]
    cmp cl, '+'         ; Check for addition
    je do_add
    cmp cl, '-'         ; Check for subtraction
    je do_subtract
    cmp cl, '*'         ; Check for multiplication
    je do_multiply
    cmp cl, '/'         ; Check for division
    je do_divide
    
    ; Handle invalid operation
    mov rax, 1
    mov rdi, 1
    mov rsi, invalid_op_msg
    mov rdx, invalid_op_len
    syscall
    jmp calculator_loop

; Arithmetic operation implementations
do_add:
    add rax, rbx        ; Add two numbers
    jmp print_result

do_subtract:
    sub rax, rbx        ; Subtract second from first number
    jmp print_result

do_multiply:
    imul rbx            ; Signed multiply
    jmp print_result

do_divide:
    test rbx, rbx       ; Check if divisor is zero
    jz division_by_zero
    cqo                 ; Sign-extend RAX into RDX:RAX for signed division
    idiv rbx            ; Signed integer divide
    
print_result:
    push rax            ; Save result before printing
    
    ; Print "Result: " prefix
    mov rax, 1
    mov rdi, 1
    mov rsi, result_msg
    mov rdx, result_len
    syscall
    
    pop rax             ; Restore result
    call print_number   ; Convert and print result
    
    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    
    jmp calculator_loop ; Continue calculator loop

division_by_zero:
    ; Handle division by zero error
    mov rax, 1
    mov rdi, 1
    mov rsi, div_zero_msg
    mov rdx, div_zero_len
    syscall
    jmp calculator_loop

; Convert string to signed 64-bit integer
; Input: RSI points to string
; Output: RAX contains converted integer
string_to_int:
    push rbx            ; Save registers
    push rcx
    push rdx
    push rsi
    
    xor rax, rax        ; Clear result register
    xor rcx, rcx        ; Clear sign flag
    
    ; Check for negative sign
    mov bl, byte [rsi]
    cmp bl, '-'
    jne .process_digits ; Skip sign handling if not negative
    inc rsi             ; Move past minus sign
    mov rcx, 1          ; Set negative sign flag
    
.process_digits:
    movzx rbx, byte [rsi]   ; Get current character
    cmp bl, 0xa             ; Check for newline (end of input)
    je .done
    cmp bl, 0               ; Check for null terminator
    je .done
    cmp bl, '0'             ; Validate digit range
    jb .done
    cmp bl, '9'
    ja .done
    
    sub bl, '0'             ; Convert ASCII to numeric value
    imul rax, 10            ; Multiply previous result by 10
    add rax, rbx            ; Add current digit
    inc rsi                 ; Move to next character
    jmp .process_digits
    
.done:
    ; Apply sign if number was negative
    test rcx, rcx
    jz .exit
    neg rax
    
.exit:
    pop rsi             ; Restore registers
    pop rdx
    pop rcx
    pop rbx
    ret

; Print signed 64-bit integer
; Input: RAX contains number to print
print_number:
    push rax            ; Save registers
    push rbx
    push rcx
    push rdx
    
    mov rcx, debug_buf
    add rcx, 31         ; Point to end of buffer
    mov byte [rcx], 0   ; Null terminate
    mov rbx, 10         ; Divisor for decimal conversion
    
    ; Handle negative numbers
    test rax, rax
    jns .convert        ; Skip if non-negative
    neg rax             ; Make positive
    push rax
    mov al, '-'         ; Print minus sign
    mov [debug_buf], al
    pop rax
    
.convert:
    dec rcx             ; Move buffer pointer
    xor rdx, rdx        ; Clear for division
    div rbx             ; Divide by 10
    add dl, '0'         ; Convert remainder to ASCII
    mov [rcx], dl       ; Store digit
    test rax, rax       ; Check if more digits remain
    jnz .convert
    
    ; Print the converted number
    mov rax, 1          ; sys_write syscall
    mov rdi, 1          ; stdout
    mov rdx, debug_buf
    add rdx, 31
    sub rdx, rcx        ; Calculate length
    mov rsi, rcx        ; Set string pointer
    syscall
    
    pop rdx             ; Restore registers
    pop rcx
    pop rbx
    pop rax
    ret

exit_program:
    mov rax, 60         ; sys_exit syscall
    xor rdi, rdi        ; Exit status = 0
    syscall             ; Exit the program
