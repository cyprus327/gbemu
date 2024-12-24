package gbemu

InterruptType :: enum {
	VBLANK   = 1 << 0,
	LCD_STAT = 1 << 1,
	TIMER    = 1 << 2,
	SERIAL   = 1 << 3,
	JOYPAD   = 1 << 4
}

Interrupt_Request :: proc(type: InterruptType) {

}

Interrupt_HandleAll :: proc() {
	if check(0x40, InterruptType.VBLANK) {

	} else if check(0x48, InterruptType.LCD_STAT) {

	} else if check(0x50, InterruptType.TIMER) {

	} else if check(0x58, InterruptType.SERIAL) {

	} else if check(0x60, InterruptType.JOYPAD) {

	}
}

@(private="file")
check :: proc(addr: u16, type: InterruptType) -> bool {
	if 0 == (cpu.intFlags & u8(type)) || 0 == (cpu.ieReg & u8(type)) {
		return false
	}

	handle(addr)
	cpu.intFlags &= ~u8(type)
	cpu.isHalted = false
	cpu.isIntMstOn = false

	return true
}

@(private="file")
handle :: proc(addr: u16) {
	Stack_Push16(cpu.reg.pc)
	cpu.reg.pc = addr
}
