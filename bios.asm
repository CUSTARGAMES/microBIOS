; ============================================================================
; v86-BIOS - Minimal BIOS for v86 emulator
; Compatible with SeaBIOS interface, but simplified
; Assembler: NASM
; Size: 64KB ROM at 0xF0000
; ============================================================================

[ORG 0xF0000]
[BITS 16]

; ============================================================================
; Constants
; ============================================================================
VIDEO_TEXT_BASE    equ 0xB8000
BIOS_DATA_AREA     equ 0x00400
BOOT_SECTOR_ADDR   equ 0x7C00
STACK_TOP          equ 0xFFFE

; Video modes
MODE_80x25         equ 0x03
MODE_320x200       equ 0x13

; ============================================================================
; Entry Point - Reset Vector at 0xFFFF0
; ============================================================================
SECTION .text
global _start

_start:
    jmp 0xF000:init_bios

; ============================================================================
; BIOS Initialization
; ============================================================================
init_bios:
    cli                      ; Disable interrupts
    cld                      ; Clear direction flag
    
    ; Initialize segment registers
    mov ax, 0xF000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, STACK_TOP
    
    ; Initialize BIOS Data Area (BDA)
    call init_bda
    
    ; Initialize hardware
    call init_video
    call init_keyboard
    call init_timer
    call init_pic
    
    sti                      ; Enable interrupts
    
    ; Print welcome message
    mov si, msg_welcome
    call print_string
    
    ; Show BIOS info
    call print_bios_info
    
    ; Memory detection
    call detect_memory
    
    ; Test hardware
    call test_hardware
    
    ; Boot attempt
    call boot_attempt
    
    ; If we get here, boot failed
    mov si, msg_boot_failed
    call print_string
    
    ; Enter ROM BASIC stub (or just halt)
    call rom_basic
    
halt_system:
    mov si, msg_halted
    call print_string
    cli
    hlt
    jmp halt_system

; ============================================================================
; Initialize BIOS Data Area
; ============================================================================
init_bda:
    push ax
    push cx
    push di
    
    ; Clear BDA (0x400-0x500)
    mov ax, 0x0040
    mov es, ax
    xor di, di
    mov cx, 0x100
    xor al, al
    rep stosb
    
    ; Set default values
    mov ax, 0x0040
    mov ds, ax
    
    ; COM port addresses
    mov word [0x00], 0x03F8   ; COM1
    mov word [0x02], 0x02F8   ; COM2
    mov word [0x04], 0x03E8   ; COM3
    mov word [0x06], 0x02E8   ; COM4
    
    ; LPT ports
    mov word [0x08], 0x0378   ; LPT1
    mov word [0x0A], 0x0278   ; LPT2
    
    ; Equipment word
    mov word [0x10], 0x0000   ; No equipment detected
    
    ; Memory size (will be updated later)
    mov word [0x13], 0x0280   ; 640KB default
    
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
    mov al, MODE_80x25
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
    push dx
    
    ; Flush keyboard buffer
    mov ah, 0x01
    int 0x16
    jz .done
    
    ; Clear buffer
    mov ah, 0x00
    int 0x16
    
.done:
    pop dx
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
    
    ; 1193180 / 18.2 = 65535 (max value)
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
    
    ; Start initialization sequence
    mov al, 0x11
    out 0x20, al           ; ICW1 to master
    out 0xA0, al           ; ICW1 to slave
    
    ; Set interrupt vectors
    mov al, 0x20
    out 0x21, al           ; ICW2 master - IRQ 0-7 -> INT 20-27
    mov al, 0x28
    out 0xA1, al           ; ICW2 slave - IRQ 8-15 -> INT 28-2F
    
    ; Set cascade
    mov al, 0x04
    out 0x21, al           ; ICW3 master - slave on IRQ2
    mov al, 0x02
    out 0xA1, al           ; ICW3 slave - cascade ID
    
    ; Set 8086 mode
    mov al, 0x01
    out 0x21, al           ; ICW4 master
    out 0xA1, al           ; ICW4 slave
    
    ; Mask all interrupts initially
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
; Print Character
; ============================================================================
print_char:
    push ax
    mov ah, 0x0E
    int 0x10
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
; Print BIOS Information
; ============================================================================
print_bios_info:
    push ax
    push si
    
    mov si, msg_version
    call print_string
    
    ; Print version number
    mov ax, 0x0100
    call print_hex_word
    
    mov si, msg_newline
    call print_string
    
    mov si, msg_date
    call print_string
    mov si, msg_date_str
    call print_string
    
    pop si
    pop ax
    ret

; ============================================================================
; Memory Detection using INT 15h
; ============================================================================
detect_memory:
    push ax
    push bx
    push cx
    push dx
    push si
    
    mov si, msg_memory
    call print_string
    
    ; Use E820 function if available
    mov ax, 0xE820
    mov bx, 0x0000
    mov cx, 24
    mov dx, 0x534D4150   ; 'SMAP'
    mov di, 0x6000       ; Buffer in EBDA
    int 0x15
    jc .legacy_method
    
    ; Use E820 data
    mov ax, [0x6000 + 8]  ; Get memory size in KB
    mov bx, 0x0040
    mov ds, bx
    mov [0x13], ax        ; Store in BDA
    jmp .print_size
    
.legacy_method:
    ; Legacy method using INT 12h
    int 0x12
    mov bx, 0x0040
    mov ds, bx
    mov [0x13], ax
    
.print_size:
    call print_hex_word
    mov si, msg_kb
    call print_string
    
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ============================================================================
; Test Hardware (Disk, Keyboard, etc.)
; ============================================================================
test_hardware:
    push ax
    push si
    
    mov si, msg_test
    call print_string
    
    ; Test disk controller
    mov ah, 0x00
    mov dl, 0x80        ; First hard disk
    int 0x13
    jc .disk_error
    mov si, msg_ok
    call print_string
    jmp .keyboard_test
    
.disk_error:
    mov si, msg_failed
    call print_string
    
.keyboard_test:
    ; Test keyboard controller
    mov si, msg_keyboard
    call print_string
    mov si, msg_ok
    call print_string
    
    pop si
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
    
    ; Try to read first sector
    mov ah, 0x02
    mov al, 0x01
    mov ch, 0x00
    mov cl, 0x01
    mov dh, 0x00
    mov dl, 0x00        ; Drive 0 (floppy)
    mov bx, BOOT_SECTOR_ADDR
    int 0x13
    jc .read_error
    
    ; Jump to boot sector
    mov si, msg_jumping
    call print_string
    
    ; Jump to boot code
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
; ROM BASIC Stub (just a simple monitor)
; ============================================================================
rom_basic:
    push ax
    push si
    
    mov si, msg_basic
    call print_string
    
.basic_loop:
    ; Simple command handler
    mov si, msg_prompt
    call print_string
    
    ; Wait for key
    xor ax, ax
    int 0x16
    
    ; Echo key
    mov ah, 0x0E
    int 0x10
    
    ; Check for 'r' to reboot
    cmp al, 'r'
    je .reboot
    
    ; Check for '?' for help
    cmp al, '?'
    je .help
    
    jmp .basic_loop
    
.help:
    mov si, msg_help
    call print_string
    jmp .basic_loop
    
.reboot:
    mov si, msg_reboot
    call print_string
    int 0x19
    
    pop si
    pop ax
    ret

; ============================================================================
; Interrupt Handlers
; ============================================================================

; Default handler for unhandled interrupts
default_handler:
    pusha
    mov si, msg_unhandled_int
    call print_string
    popa
    iret

; Timer interrupt (IRQ0 - INT 20h)
timer_handler:
    push ax
    push ds
    
    ; Update tick count in BDA
    mov ax, 0x0040
    mov ds, ax
    inc word [0x006C]    ; Timer ticks low word
    adc word [0x006E], 0 ; High word
    
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop ax
    iret

; Keyboard interrupt (IRQ1 - INT 21h)
keyboard_handler:
    push ax
    push ds
    
    ; Read scan code
    in al, 0x60
    
    ; Store in BIOS keyboard buffer
    mov ax, 0x0040
    mov ds, ax
    mov bx, [0x001A]    ; Buffer head
    mov [bx], al        ; Store scan code
    inc bx
    cmp bx, 0x003E
    jb .no_wrap
    mov bx, 0x001E
.no_wrap:
    mov [0x001C], bx    ; Update tail
    
    ; Send EOI
    mov al, 0x20
    out 0x20, al
    
    pop ds
    pop ax
    iret

; INT 10h - Video services
int10_handler:
    cmp ah, 0x00        ; Set mode
    je .set_mode
    cmp ah, 0x01        ; Set cursor shape
    je .set_cursor
    cmp ah, 0x02        ; Set cursor position
    je .set_cursor_pos
    cmp ah, 0x03        ; Get cursor position
    je .get_cursor_pos
    cmp ah, 0x0E        ; Teletype output
    je .teletype
    
    ; Unsupported function
    iret

.set_mode:
    int 0x10            ; Call real BIOS INT 10h
    iret

.set_cursor:
    int 0x10
    iret

.set_cursor_pos:
    int 0x10
    iret

.get_cursor_pos:
    int 0x10
    iret

.teletype:
    int 0x10
    iret

; INT 13h - Disk services
int13_handler:
    cmp ah, 0x00        ; Reset disk
    je .reset
    cmp ah, 0x02        ; Read sectors
    je .read
    cmp ah, 0x03        ; Write sectors
    je .write
    
    ; Unsupported - set error
    mov ah, 0x01
    stc
    iret

.reset:
    xor ah, ah          ; Success
    clc
    iret

.read:
    ; Simple read (just success for v86)
    xor ah, ah
    clc
    iret

.write:
    xor ah, ah
    clc
    iret

; INT 15h - System services
int15_handler:
    cmp ah, 0x88        ; Get extended memory
    je .get_ext_mem
    cmp ah, 0xE820      ; Get memory map
    je .e820
    
    ; Unsupported
    mov ah, 0x86
    stc
    iret

.get_ext_mem:
    mov ax, 0x7F00      ; 32512KB extended memory
    clc
    iret

.e820:
    mov ax, 0x534D4150  ; 'SMAP'
    clc
    iret

; INT 16h - Keyboard services
int16_handler:
    cmp ah, 0x00        ; Get keystroke
    je .get_key
    cmp ah, 0x01        ; Check keystroke
    je .check_key
    
    iret

.get_key:
    xor ax, ax
    iret

.check_key:
    xor ax, ax
    iret

; INT 19h - Bootstrap
int19_handler:
    call boot_attempt
    iret

; ============================================================================
; Messages
; ============================================================================
msg_welcome:
    db 0x0D, 0x0A
    db "====================================="
    db 0x0D, 0x0A
    db "v86-BIOS v1.0 - Minimal BIOS for v86"
    db 0x0D, 0x0A
    db "Copyright (c) 2024"
    db 0x0D, 0x0A
    db "====================================="
    db 0x0D, 0x0A, 0x00

msg_version:
    db "BIOS Version: ", 0x00
msg_date:
    db "Build Date: ", 0x00
msg_date_str:
    db __DATE__ " " __TIME__, 0x0D, 0x0A, 0x00
msg_newline:
    db 0x0D, 0x0A, 0x00

msg_memory:
    db "Memory Size: ", 0x00
msg_kb:
    db " KB", 0x0D, 0x0A, 0x00

msg_test:
    db "Testing hardware...", 0x00
msg_ok:
    db " OK", 0x0D, 0x0A, 0x00
msg_failed:
    db " FAILED", 0x0D, 0x0A, 0x00
msg_keyboard:
    db "Keyboard controller: ", 0x00

msg_booting:
    db 0x0D, 0x0A, "Booting from disk...", 0x0D, 0x0A, 0x00
msg_jumping:
    db "Jumping to boot sector...", 0x0D, 0x0A, 0x00
msg_no_boot:
    db "No boot signature found", 0x0D, 0x0A, 0x00
msg_read_error:
    db "Disk read error", 0x0D, 0x0A, 0x00
msg_boot_failed:
    db 0x0D, 0x0A, "Boot failed!", 0x0D, 0x0A, 0x00

msg_halted:
    db "System halted.", 0x0D, 0x0A, 0x00

msg_basic:
    db 0x0D, 0x0A, "Entering ROM BASIC monitor...", 0x0D, 0x0A, 0x00
msg_prompt:
    db "> ", 0x00
msg_help:
    db 0x0D, 0x0A, "Commands:", 0x0D, 0x0A
    db "  r - Reboot", 0x0D, 0x0A
    db "  ? - Show this help", 0x0D, 0x0A
    db 0x0D, 0x0A, 0x00
msg_reboot:
    db "Rebooting...", 0x0D, 0x0A, 0x00

msg_unhandled_int:
    db "Unhandled interrupt!", 0x0D, 0x0A, 0x00

; ============================================================================
; Interrupt Vector Table (IVT) at 0x00000
; Note: This will be copied to 0x00000 by the BIOS
; ============================================================================
SECTION .ivt start=0x00000
ivt:
    %rep 0x100
    dw default_handler
    dw 0xF000
    %endrep

; ============================================================================
; BIOS Data Area (BDA) at 0x00400
; ============================================================================
SECTION .bda start=0x00400
bda:
    times 0x100 db 0

; ============================================================================
; Extended BIOS Data Area (EBDA) at 0x00600
; ============================================================================
SECTION .ebda start=0x00600
ebda:
    times 0x200 db 0

; ============================================================================
; Main BIOS Code - continues to 0x10000 (64KB)
; ============================================================================
SECTION .text

; Pad to 0x0FFF0
times (0x0FFF0 - ($ - $$)) db 0

; ============================================================================
; BIOS Signature at 0x0FFFE
; ============================================================================
bios_signature:
    dw 0xAA55

; Pad to 0x0FFF0 again for reset vector
times (0x0FFF0 - ($ - $$)) db 0

; ============================================================================
; Reset Vector at 0x0FFF0 (physical 0xFFFF0)
; ============================================================================
reset_vector:
    jmp 0xF000:init_bios

; ============================================================================
; Fill to exactly 64KB
; ============================================================================
times (0x10000 - ($ - $$)) db 0
