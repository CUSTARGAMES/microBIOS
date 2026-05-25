#!/bin/bash
# Build script for v86-BIOS

echo "Building v86-BIOS..."

# Assemble with NASM
nasm -f bin -o bios.bin bios.asm

# Check size
SIZE=$(stat -c%s "bios.bin")
echo "BIOS size: $SIZE bytes"

if [ $SIZE -eq 65536 ]; then
    echo "✓ BIOS built successfully (64KB)"
else
    echo "✗ Wrong size! Expected 65536 bytes, got $SIZE"
    exit 1
fi

# Create test disk image
echo "Creating test disk image..."
dd if=/dev/zero of=disk.img bs=512 count=2880 2>/dev/null

# Create simple boot sector test
nasm -f bin -o test.bin test_boot.asm 2>/dev/null || {
    echo "Creating simple boot sector..."
    echo -e "\xEB\x3C\x90" | dd of=test.bin bs=512 count=1 2>/dev/null
    printf "Test BIOS boot sector\0" | dd of=test.bin seek=3 conv=notrunc 2>/dev/null
    echo -n -e "\x55\xAA" | dd of=test.bin seek=510 conv=notrunc 2>/dev/null
}

dd if=test.bin of=disk.img conv=notrunc 2>/dev/null

echo "Build complete!"
echo "Files:"
echo "  bios.bin - BIOS ROM (64KB)"
echo "  disk.img - Test floppy disk image"
echo ""
echo "Test with QEMU:"
echo "  qemu-system-i386 -bios bios.bin -drive format=raw,file=disk.img"
echo ""
echo "Test with v86:"
echo "  Use bios.bin as the bios file in v86 configuration"
