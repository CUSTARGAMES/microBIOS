# ============================================================================
# Makefile for v86-BIOS
# ============================================================================

ASM = nasm
ASMFLAGS = -f bin
TARGET = bios.bin
TEST_BOOT = test_boot.bin
TEST_DISK = disk.img

.PHONY: all build test clean help

all: build

# Build main BIOS
build: $(TARGET)
	@echo ""
	@echo "v86-BIOS built successfully!"
	@echo "File: $(TARGET)"
	@if command -v stat >/dev/null 2>&1; then \
		SIZE=$$(stat -c%s $(TARGET) 2>/dev/null || echo "0"); \
		echo "Size: $$SIZE bytes"; \
	fi
	@echo ""

$(TARGET): bios.asm
	@echo "Assembling v86-BIOS..."
	$(ASM) $(ASMFLAGS) -o $(TARGET) bios.asm

# Build test boot sector
$(TEST_BOOT): test_boot.asm
	@echo "Building test boot sector..."
	$(ASM) $(ASMFLAGS) -o $(TEST_BOOT) test_boot.asm

# Create test disk image
$(TEST_DISK): $(TEST_BOOT)
	@echo "Creating test disk image..."
	dd if=/dev/zero of=$(TEST_DISK) bs=512 count=2880 2>/dev/null
	dd if=$(TEST_BOOT) of=$(TEST_DISK) conv=notrunc 2>/dev/null
	@echo "Created: $(TEST_DISK)"

# Build everything
full: build $(TEST_DISK)
	@echo ""
	@echo "Complete build finished"
	@echo "  - $(TARGET) (BIOS ROM)"
	@echo "  - $(TEST_DISK) (Test floppy image)"
	@echo ""

# Test with QEMU
test: build $(TEST_DISK)
	@echo ""
	@echo "Testing with QEMU..."
	@echo "Press Ctrl+A then X to exit"
	@echo ""
	qemu-system-i386 -bios $(TARGET) -drive format=raw,file=$(TEST_DISK)

# Quick test without disk
quick-test: build
	@echo ""
	@echo "Quick test (no disk)..."
	qemu-system-i386 -bios $(TARGET) -nographic -display none -no-reboot -monitor none || true
	@echo "Test complete"

# Clean
clean:
	@echo "Cleaning..."
	rm -f $(TARGET) $(TEST_BOOT) $(TEST_DISK) *.o *.elf
	@echo "Clean complete"

# Help
help:
	@echo ""
	@echo "v86-BIOS Makefile Commands:"
	@echo ""
	@echo "  make build        - Build bios.bin only"
	@echo "  make full         - Build BIOS + test disk image"
	@echo "  make test         - Test with QEMU (graphical)"
	@echo "  make quick-test   - Quick test without display"
	@echo "  make clean        - Remove built files"
	@echo "  make help         - Show this help"
	@echo ""
