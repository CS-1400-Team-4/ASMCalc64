section .data
    prompt_msg db "Enter operation (+ - * / q to quit): ", 0
    prompt_len equ $ - prompt_msg
    num1_msg db "Enter first number: ", 0xa
    num1_len equ $ - num1_msg
    num2_msg db "Enter second number: ", 0xa
    num2_len equ $ - num2_msg
    result_msg db "Result: "
    result_len equ $ - result_msg
    div_zero_msg db "Error: Division by zero!", 0xa
    div_zero_len equ $ - div_zero_msg
    invalid_op_msg db "Error: Invalid operation!", 0xa
    invalid_op_len equ $ - invalid_op_msg
    debug_num1 db "Debug - First number: ", 0
    debug_num1_len equ $ - debug_num1
    debug_num2 db "Debug - Second number: ", 0
    debug_num2_len equ $ - debug_num2
    newline db 0xa

section .bss
    operation resb 2
    num1 resb 32
    num2 resb 32
    result resb 32
    num1_val resq 1    ; 64-bit storage for first number
    num2_val resq 1    ; 64-bit storage for second number
    debug_buf resb 32

section .text
    global _start

_start:
calculator_loop:
    ; Print operation prompt
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rsi, prompt_msg
    mov rdx, prompt_len
    syscall
    
    ; Read operation
    mov rax, 0          ; sys_read
    mov rdi, 0          ; stdin
    mov rsi, operation
    mov rdx, 2
    syscall
    
    ; Check for quit
    mov al, [operation]
    cmp al, 'q'
    je exit_program
    
    ; Get first number
    mov rax, 1
    mov rdi, 1
    mov rsi, num1_msg
    mov rdx, num1_len
    syscall
    
    ; Read first number
    mov rax, 0
    mov rdi, 0
    mov rsi, num1
    mov rdx, 32
    syscall
    
    ; Convert first number
    mov rsi, num1
    call string_to_int
    mov [num1_val], rax    ; Store first number
    
    ; Debug output for first number
    push rax
    mov rax, 1
    mov rdi, 1
    mov rsi, debug_num1
    mov rdx, debug_num1_len
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
    
    ; Get second number
    mov rax, 1
    mov rdi, 1
    mov rsi, num2_msg
    mov rdx, num2_len
    syscall
    
    ; Read second number
    mov rax, 0
    mov rdi, 0
    mov rsi, num2
    mov rdx, 32
    syscall
    
    ; Convert second number
    mov rsi, num2
    call string_to_int
    mov [num2_val], rax    ; Store second number
    
    ; Debug output for second number
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
    
    ; Load numbers for operation
    mov rax, [num1_val]
    mov rbx, [num2_val]
    
    ; Perform operation
    mov cl, [operation]
    cmp cl, '+'
    je do_add
    cmp cl, '-'
    je do_subtract
    cmp cl, '*'
    je do_multiply
    cmp cl, '/'
    je do_divide
    
    ; Invalid operation
    mov rax, 1
    mov rdi, 1
    mov rsi, invalid_op_msg
    mov rdx, invalid_op_len
    syscall
    jmp calculator_loop

do_add:
    add rax, rbx
    jmp print_result

do_subtract:
    sub rax, rbx
    jmp print_result

do_multiply:
    imul rbx
    jmp print_result

do_divide:
    test rbx, rbx
    jz division_by_zero
    cqo                 ; Sign-extend RAX into RDX:RAX
    idiv rbx
    
print_result:
    push rax            ; Save result
    
    ; Print "Result: "
    mov rax, 1
    mov rdi, 1
    mov rsi, result_msg
    mov rdx, result_len
    syscall
    
    pop rax             ; Restore result
    call print_number
    
    ; Print newline
    mov rax, 1
    mov rdi, 1
    mov rsi, newline
    mov rdx, 1
    syscall
    
    jmp calculator_loop

division_by_zero:
    mov rax, 1
    mov rdi, 1
    mov rsi, div_zero_msg
    mov rdx, div_zero_len
    syscall
    jmp calculator_loop

; Convert string to integer
; Input: RSI points to string
; Output: RAX contains integer
string_to_int:
    push rbx
    push rcx
    push rdx
    push rsi
    
    xor rax, rax        ; Clear result
    xor rcx, rcx        ; Clear sign flag
    
    ; Check for minus sign
    mov bl, byte [rsi]
    cmp bl, '-'
    jne .process_digits
    inc rsi
    mov rcx, 1          ; Set sign flag
    
.process_digits:
    movzx rbx, byte [rsi]   ; Get character
    cmp bl, 0xa             ; Check for newline
    je .done
    cmp bl, 0              ; Check for null
    je .done
    cmp bl, '0'            ; Check if below '0'
    jb .done
    cmp bl, '9'            ; Check if above '9'
    ja .done
    
    sub bl, '0'            ; Convert to number
    imul rax, 10           ; Multiply previous result by 10
    add rax, rbx           ; Add new digit
    inc rsi                ; Next character
    jmp .process_digits
    
.done:
    ; Apply sign if negative
    test rcx, rcx
    jz .exit
    neg rax
    
.exit:
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    ret

; Print number in RAX
print_number:
    push rax
    push rbx
    push rcx
    push rdx
    
    mov rcx, debug_buf
    add rcx, 31         ; Point to end of buffer
    mov byte [rcx], 0   ; Null terminate
    mov rbx, 10         ; Divisor
    
    ; Check if negative
    test rax, rax
    jns .convert
    neg rax             ; Make positive
    push rax            ; Save number
    mov al, '-'         ; Print minus sign
    mov [debug_buf], al
    pop rax
    
.convert:
    dec rcx             ; Move buffer pointer
    xor rdx, rdx        ; Clear for division
    div rbx             ; Divide by 10
    add dl, '0'         ; Convert remainder to ASCII
    mov [rcx], dl       ; Store digit
    test rax, rax       ; Check if more digits
    jnz .convert
    
    ; Print the number
    mov rax, 1          ; sys_write
    mov rdi, 1          ; stdout
    mov rdx, debug_buf
    add rdx, 31
    sub rdx, rcx        ; Calculate length
    mov rsi, rcx        ; Set string pointer
    syscall
    
    pop rdx
    pop rcx
    pop rbx
    pop rax
    ret

exit_program:
    mov rax, 60         ; sys_exit
    xor rdi, rdi        ; status = 0
    syscall