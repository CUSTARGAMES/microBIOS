; Simple boot sector for testing v86-BIOS
[ORG 0x7C00]
[BITS 16]

start:
    mov ax, 0x0000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    
    mov si, boot_message
    call print
    
    cli
    hlt

print:
    lodsb
    test al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print
.done:
    ret

boot_message:
    db 0x0D, 0x0A
    db "====================================="
    db 0x0D, 0x0A
    db "Booted successfully with v86-BIOS!"
    db 0x0D, 0x0A
    db "====================================="
    db 0x0D, 0x0A, 0x00

times 510 - ($ - $$) db 0
dw 0xAA55
