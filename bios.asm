; ============================================================================
; v86-BIOS - Minimal BIOS for v86 Emulator
; NASM Assembler - 64KB ROM at 0xF0000
; ============================================================================

[ORG 0xF0000]
[BITS 16]

; ============================================================================
; Constants
; ============================================================================
BOOT_SECTOR_ADDR   equ 0x7C00
STACK_TOP          equ 0xFFFE

; ============================================================================
; Reset Vector Entry Point (0xFFFF0)
; ============================================================================
SECTION .text

_start:
    jmp 0xF000:init_bios

; ============================================================================
; Main BIOS Initialization
; ============================================================================
init_bios:
    cli                     ; Disable interrupts
    cld                     ; Clear direction flag
    
    ; Initialize segment registers
    mov ax, 0xF000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    
    ; Initialize BIOS Data Area
    call init_bda
    
    ; Initialize hardware
    call init_video
    call init_keyboard
    call init_timer
    call init_pic
    
    sti                     ; Enable interrupts
    
    ; Print welcome message
    mov si, msg_welcome
    call print_string
    
    ; Detect memory
    call detect_memory
    
    ; Boot attempt
    call boot_attempt
    
    ; Boot failed - enter ROM BASIC
    call rom_basic
    
halt_system:
    mov si, msg_halted
    call print_string
    cli
    hlt
    jmp halt_system

; ============================================================================
; Initialize BIOS Data Area (BDA) at 0x400
; ============================================================================
init_bda:
    push ax
    push cx
    push di
    
    ; Clear BDA
    mov ax, 0x0040
    mov es, ax
    xor di, di
    mov cx, 0x100
    xor al, al
    rep stosb
    
    ; Set COM port addresses
    mov ax, 0x0040
    mov ds, ax
    mov word [0x00], 0x03F8   ; COM1
    mov word [0x02], 0x02F8   ; COM2
    mov word [0x04], 0x03E8   ; COM3
    mov word [0x06], 0x02E8   ; COM4
    
    ; Set LPT port addresses
    mov word [0x08], 0x0378   ; LPT1
    mov word [0x0A], 0x0278   ; LPT2
    
    ; Default memory size (640KB)
    mov word [0x13], 0x0280
    
    pop di
    pop cx
    pop ax
    ret

; ============================================================================
; Video Initialization
; ============================================================================
init_video:
    push ax
    
    ; Set 80x25 text mode
    mov ah, 0x00
    mov al, 0x03
    int 0x10
    
    ; Clear screen
    mov ax, 0x0600
    mov bh, 0x07
    xor cx, cx
    mov dx, 0x184F
    int 0x10
    
    ; Set cursor to home
    mov ah, 0x02
    xor bx, bx
    xor dx, dx
    int 0x10
    
    pop ax
    ret

; ============================================================================
; Keyboard Initialization
; ============================================================================
init_keyboard:
    push ax
    
    ; Flush keyboard buffer
    mov ah, 0x01
    int 0x16
    jz .done
    
    ; Clear buffer
    mov ah, 0x00
    int 0x16
    
.done:
    pop ax
    ret

; ============================================================================
; Timer Initialization (PIT)
; ============================================================================
init_timer:
    push ax
    
    ; Program PIT channel 0 for ~18.2 Hz
    mov al, 0x36
    out 0x43, al
    
    ; Set count to maximum (0xFFFF)
    mov al, 0xFF
    out 0x40, al
    mov al, 0xFF
    out 0x40, al
    
    pop ax
    ret

; ============================================================================
; PIC Initialization
; ============================================================================
init_pic:
    push ax
    
    ; Start initialization
    mov al, 0x11
    out 0x20, al
    out 0xA0, al
    
    ; Set interrupt vectors (master: 0x20, slave: 0x28)
    mov al, 0x20
    out 0x21, al
    mov al, 0x28
    out 0xA1, al
    
    ; Set cascade
    mov al, 0x04
    out 0x21, al
    mov al, 0x02
    out 0xA1, al
    
    ; 8086 mode
    mov al, 0x01
    out 0x21, al
    out 0xA1, al
    
    ; Mask all interrupts
    mov al, 0xFF
    out 0x21, al
    out 0xA1, al
    
    pop ax
    ret

; ============================================================================
; Print String (DS:SI)
; ============================================================================
print_string:
    push ax
    push si
.loop:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp .loop
.done:
    pop si
    pop ax
    ret

; ============================================================================
; Print Hex Word
; ============================================================================
print_hex_word:
    push ax
    push cx
    push dx
    
    mov cx, 4
.loop:
    rol ax, 4
    mov dx, ax
    and dl, 0x0F
    add dl, '0'
    cmp dl, '9'
    jbe .digit
    add dl, 7
.digit:
    mov ah, 0x0E
    int 0x10
    loop .loop
    
    pop dx
    pop cx
    pop ax
    ret

; ============================================================================
; Memory Detection
; ============================================================================
detect_memory:
    push ax
    push bx
    push si
    
    mov si, msg_memory
    call print_string
    
    ; Use INT 12h to get conventional memory
    int 0x12
    
    call print_hex_word
    mov si, msg_kb
    call print_string
    
    ; Store in BDA
    push ax
    mov ax, 0x0040
    mov ds, ax
    pop ax
    mov [0x13], ax
    
    pop si
    pop bx
    pop ax
    ret

; ============================================================================
; Boot Attempt
; ============================================================================
boot_attempt:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, msg_booting
    call print_string
    
    ; Check for boot signature at 0x7C00
    mov ax, 0x0000
    mov es, ax
    mov bx, BOOT_SECTOR_ADDR + 0x1FE
    mov ax, [es:bx]
    cmp ax, 0xAA55
    jne .no_boot_sector
    
    ; Read first sector
    mov ah, 0x02
    mov al, 0x01
    mov ch, 0x00
    mov cl, 0x01
    mov dh, 0x00
    mov dl, 0x00
    mov bx, BOOT_SECTOR_ADDR
    int 0x13
    jc .read_error
    
    ; Jump to boot sector
    mov si, msg_jumping
    call print_string
    
    jmp 0x0000:BOOT_SECTOR_ADDR
    
.read_error:
    mov si, msg_read_error
    call print_string
    jmp .done
    
.no_boot_sector:
    mov si, msg_no_boot
    call print_string
    
.done:
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
; ROM BASIC Monitor
; ============================================================================
rom_basic:
    push ax
    push si
    
    mov si, msg_basic
    call print_string
    
.basic_loop:
    mov si, msg_prompt
    call print_string
    
    ; Wait for key
    xor ax, ax
    int 0x16
    
    ; Echo
    mov ah, 0x0E
    int 0x10
    
    ; Commands
    cmp al, 'r'
    je .reboot
    cmp al, '?'
    je .help
    cmp al, 'm'
    je .memory
    cmp al, 0x0D        ; Enter
    je .basic_loop
    
    jmp .basic_loop
    
.help:
    mov si, msg_help
    call print_string
    jmp .basic_loop
    
.memory:
    push ax
    mov si, msg_memory_show
    call print_string
    mov ax, [0x0040 + 0x13]
    call print_hex_word
    mov si, msg_kb
    call print_string
    pop ax
    jmp .basic_loop
    
.reboot:
    mov si, msg_reboot
    call print_string
    int 0x19
    
    pop si
    pop ax
    ret

; ============================================================================
; Messages
; ============================================================================
msg_welcome:
    db 0x0D, 0x0A
    db "+==================================+", 0x0D, 0x0A
    db "|         v86-BIOS v1.0            |", 0x0D, 0x0A
    db "|      Minimal BIOS for v86        |", 0x0D, 0x0A
    db "+==================================+", 0x0D, 0x0A, 0x0D, 0x0A, 0x00

msg_memory:
    db "Memory detected: ", 0x00
msg_kb:
    db " KB", 0x0D, 0x0A, 0x00

msg_booting:
    db 0x0D, 0x0A, "Booting from disk...", 0x0D, 0x0A, 0x00
msg_jumping:
    db "Jumping to boot sector...", 0x0D, 0x0A, 0x00
msg_no_boot:
    db "No bootable device found.", 0x0D, 0x0A, 0x00
msg_read_error:
    db "Disk read error.", 0x0D, 0x0A, 0x00
msg_halted:
    db "System halted.", 0x0D, 0x0A, 0x00

msg_basic:
    db 0x0D, 0x0A, "Entering ROM BASIC monitor...", 0x0D, 0x0A, 0x00
msg_prompt:
    db "> ", 0x00
msg_help:
    db 0x0D, 0x0A, "Commands:", 0x0D, 0x0A
    db "  r - Reboot", 0x0D, 0x0A
    db "  m - Show memory", 0x0D, 0x0A
    db "  ? - Show help", 0x0D, 0x0A, 0x0D, 0x0A, 0x00
msg_reboot:
    db 0x0D, 0x0A, "Rebooting...", 0x0D, 0x0A, 0x00
msg_memory_show:
    db 0x0D, 0x0A, "Memory: ", 0x00

; ============================================================================
; Pad to reset vector at 0xFFF0 (relative to ORG 0xF0000)
; Current position: $ - $$ (offset from start)
; Need to pad from current position to 0xFFF0
; ============================================================================

current_pos equ ($ - $$)
pad_size equ (0xFFF0 - current_pos)

%if pad_size > 0
    times pad_size db 0
%endif

; ============================================================================
; Reset Vector at 0xFFFF0 (physical address)
; ============================================================================
reset_vector:
    jmp 0xF000:init_bios
    nop
    nop

; ============================================================================
; BIOS Signature at 0xFFFFE
; ============================================================================
signature:
    dw 0xAA55

; ============================================================================
; Fill remaining space to exactly 64KB (0x10000 bytes)
; ============================================================================

current_pos2 equ ($ - $$)
pad_size2 equ (0x10000 - current_pos2)

%if pad_size2 > 0
    times pad_size2 db 0
%endif
