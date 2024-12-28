package gbemu

import "core:fmt"
import "core:mem"

OAMEntry :: struct {
	y, x, tileInd, flags: u8,
}

PPUState :: struct {
	oamRam: [40]OAMEntry,
	vram: [0x2000]u8
}

ppu: PPUState

PPU_OAMWrite :: proc(addr: u16, val: u8) {
	addr := addr
	if addr >= 0xFE00 {
		addr -= 0xFE00
	}
	bytes := mem.any_to_bytes(ppu.oamRam)
	// read_pause(fmt.aprintfln("IN OAM WRITE: %04X, %02X", addr, val))
	bytes[addr] = val
}

PPU_OAMRead :: proc(addr: u16) -> u8 {
	addr := addr
	if addr >= 0xFE00 {
		addr -= 0xFE00
	}
	bytes := mem.any_to_bytes(ppu.oamRam)
	return bytes[addr]
}

PPU_VramWrite :: proc(addr: u16, val: u8) {
	ppu.vram[addr - 0x8000] = val
}

PPU_VramRead :: proc(addr: u16) -> u8 {
	return ppu.vram[addr - 0x8000]
}

@(private="file") get_flag_cgb_palette_num :: #force_inline proc(e: OAMEntry) -> u8 {
	return e.flags & 0b00000111
}
@(private="file") set_flag_cgb_palette_num :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 0, 0 != val))
	e.flags = u8(set_bit(uint(e.flags), 1, 0 != val))
	e.flags = u8(set_bit(uint(e.flags), 2, 0 != val))
}
@(private="file") get_flag_vram_bank :: #force_inline proc(e: OAMEntry) -> u8 {
	return (e.flags & 0b00001000) >> 3
}
@(private="file") set_flag_vram_bank :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 3, 0 != val))
}
@(private="file") get_flag_palette_num :: #force_inline proc(e: OAMEntry) -> u8 {
	return (e.flags & 0b00010000) >> 4
}
@(private="file") set_flag_palette_num :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 4, 0 != val))
}
@(private="file") get_flag_xflip :: #force_inline proc(e: OAMEntry) -> u8 {
	return (e.flags & 0b00100000) >> 5
}
@(private="file") set_flag_xflip :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 5, 0 != val))
}
@(private="file") get_flag_yflip :: #force_inline proc(e: OAMEntry) -> u8 {
	return (e.flags & 0b01000000) >> 6
}
@(private="file") set_flag_yflip :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 6, 0 != val))
}
@(private="file") get_flag_bgp :: #force_inline proc(e: OAMEntry) -> u8 {
	return (e.flags & 0b10000000) >> 7
}
@(private="file") set_flag_bgp :: #force_inline proc(e: ^OAMEntry, val: u8) {
	e.flags = u8(set_bit(uint(e.flags), 7, 0 != val))
}
