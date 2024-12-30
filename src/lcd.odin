package gbemu

import "core:mem"

LCDMode :: enum {
	HBLANK, VBLANK, OAM, TRANSFER
}

LCDState :: struct {
	control, status: u8,
	scrollY, scrollX: u8,
	yCoord, yCmp: u8,
	dma: u8,
	bgPalette: u8,
	objPalette: [2]u8,
	winY, winX: u8
}

StatSrc :: enum {
	HBLANK = (1 << 3),
	VBLANK = (1 << 4),
	OAM    = (1 << 5),
	LYC    = (1 << 6)
}

lcd: LCDState

bgColors, sp1Colors, sp2Colors: [4]u32

LCD_Init :: proc() {
	lcd.control = 0x91
	lcd.bgPalette = 0xFC
	lcd.objPalette[0] = 0xFF
	lcd.objPalette[1] = 0xFF
	for i in 0..<4 {
		bgColors[i] = defaultColors[i]
		sp1Colors[i] = defaultColors[i]
		sp2Colors[i] = defaultColors[i]
	}
}

LCD_Read :: proc(addr: u16) -> u8 {
	ptr := mem.any_to_bytes(lcd)
	return ptr[addr - 0xFF40]
}

LCD_Write :: proc(addr: u16, val: u8) {
	ptr := mem.any_to_bytes(lcd)
	ptr[addr - 0xFF40] = val
	switch addr {
		case 0xFF46: DMA_Start(val)
		case 0xFF47: update_palette(val, 0)
		case 0xFF48: update_palette(val & 0b11111100, 1)
		case 0xFF49: update_palette(val & 0b11111100, 2)
	}
}

@(private="file")
update_palette :: proc(data, palette: u8) {
	switch palette {
		case 0: for i in 0..<4 { bgColors[i]  = defaultColors[(data >> u8(i * 2)) & 0b11] }
		case 1: for i in 0..<4 { sp1Colors[i] = defaultColors[(data >> u8(i * 2)) & 0b11] }
		case 2: for i in 0..<4 { sp2Colors[i] = defaultColors[(data >> u8(i * 2)) & 0b11] }
	}
}

LCD_SetMode :: #force_inline proc(mode: LCDMode) {
	lcd.status &= 0b11111100
	lcd.status |= u8(mode)
}
LCD_GetMode :: #force_inline proc() -> LCDMode {
	return LCDMode(lcd.status & 0b11)
}
LCD_GetYC :: #force_inline proc() -> u8 {
	return lcd.status & (1 << 2)
}
LCD_SetYC :: #force_inline proc(on: bool) {
	lcd.status = u8(set_bit(uint(lcd.status), 2, on))
}
LCD_StatInt :: #force_inline proc(src: StatSrc) -> u8 {
	return lcd.status & u8(src)
}
LCD_BgwEnable :: #force_inline proc() -> u8 {
	return lcd.control & (1 << 0)
}
LCD_BgwDataArea :: #force_inline proc() -> u16 {
	return 0 != (lcd.control & (1 << 4)) ? 0x8000 : 0x8800
}
LCD_BgMapArea :: #force_inline proc() -> u16 {
	return 0 != (lcd.control & (1 << 3)) ? 0x9C00 : 0x9800
}
LCD_ObjHeight :: #force_inline proc() -> u8 {
	return 0 != (lcd.control & (1 << 2)) ? 16 : 8
}
LCD_ObjEnable :: #force_inline proc() -> u8 {
	return lcd.control & (1 << 1)
}
LCD_WinEnable :: #force_inline proc() -> u8 {
	return lcd.control & (1 << 5)
}
LCD_WinMapArea :: #force_inline proc() -> u16 {
	return 0 != (lcd.control & (1 << 6)) ? 0x9C00 : 0x9800
}
LCD_LcdEnable :: #force_inline proc() -> u8 {
	return lcd.control & (1 << 7)
}
