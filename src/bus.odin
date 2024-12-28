package gbemu

import "core:os"
import "core:fmt"

RamState :: struct {
	wram: [0x2000]u8,
	hram: [0x80]u8
}

@(private="file")
ram: RamState

/*
0x0000 - 0x3FFF  rom bank 0
0x4000 - 0x7FFF  rom bank 1, switchable
0x8000 - 0x97FF  chr ram
0x9800 - 0x9BFF  bg map 1
0x9C00 - 0x9FFF  bg map 2
0xA000 - 0xBFFF  cart ram
0xC000 - 0xCFFF  ram bank 0
0xD000 - 0xDFFF  ram bank 1-7, switchable, color only
0xE000 - 0xFDFF  reserved, echo ram
0xFE00 - 0xFE9F  obj attribute memory
0xFEA0 - 0xFEFF  reserved, unusable
0xFF00 - 0xFF7F  io registers
0xFF80 - 0xFFFE  zero page (high ram)
*/

Bus_Read :: proc(addr: u16) -> u8 {
	switch addr {
	case 0x0000..=0x7FFF: // rom data
		return cart_read(addr)
	case 0x8000..=0x9FFF: // char/map data
		return PPU_VramRead(addr)
	case 0xA000..=0xBFFF: // cart ram
		return cart_read(addr)
	case 0xC000..=0xDFFF: // ram banks (wram)
		return wram_read(addr)
	case 0xE000..=0xFDFF: // reserved echo ram
		return 0
	case 0xFE00..=0xFE9F: // obj attrib memory
		return dma.isActive ? 0xFF : PPU_OAMRead(addr)
	case 0xFEA0..=0xFEFF: // reserved
		return 0
	case 0xFF00..=0xFF7F: // io registers
		return io_read(addr)
	case 0xFF80..=0xFFFE: // high ram
		return hram_read(addr)
	case 0xFFFF: // cpu enable register
		return cpu.ieReg
	}

	no_impl("impossible bus read")
	return 0 // cant be here
}

Bus_Read16 :: proc(addr: u16) -> u16 {
	lo := Bus_Read(addr)
	hi := Bus_Read(addr + 1)
	return u16(lo) | (u16(hi) << 8)
}

Bus_Write :: proc(addr: u16, val: u8) {
	switch addr {
	case 0x0000..=0x7FFF: // rom data
		cart_write(addr, val)
	case 0x8000..=0x9FFF: // char/map data
		PPU_VramWrite(addr, val)
	case 0xA000..=0xBFFF: // cart ram
		cart_write(addr, val)
	case 0xC000..=0xDFFF: // ram banks (wram)
		wram_write(addr, val)
	case 0xE000..=0xFDFF: // reserved echo ram
		no_impl("WRITE echo ram")
	case 0xFE00..=0xFE9F: // obj attrib memory
		if dma.isActive {
			return
		}
		PPU_OAMWrite(addr, val)
	case 0xFEA0..=0xFEFF: // reserved
		no_impl("cannot write to reserved memory")
	case 0xFF00..=0xFF7F: // io registers
		io_write(addr, val)
	case 0xFF80..=0xFFFE: // high ram
		hram_write(addr, val)
	case 0xFFFF: // cpu enable register
		cpu.ieReg = val
	}
}

Bus_Write16 :: proc(addr: u16, val: u16) {
	Bus_Write(addr + 1, u8((val >> 8) & 0xFF))
	Bus_Write(addr, u8(val & 0xFF))
}

@(private="file")
cart_read :: #force_inline proc(addr: u16) -> u8 {
	return cart.romData[addr]
}

@(private="file")
cart_write :: #force_inline proc(addr: u16, val: u8) {
	no_impl("unsupported cart write")
	// os.exit(1)
}

// @(private="file")
wram_read :: #force_inline proc(addr: u16) -> u8 {
	return ram.wram[addr - 0xC000]
}

@(private="file")
wram_write :: #force_inline proc(addr: u16, val: u8) {
	ram.wram[addr - 0xC000] = val
}

@(private="file")
hram_read :: #force_inline proc(addr: u16) -> u8 {
	return ram.hram[addr - 0xFF80]
}

@(private="file")
hram_write :: #force_inline proc(addr: u16, val: u8) {
	ram.hram[addr - 0xFF80] = val
}

@(private="file")
serialData: [2]u8

@(private="file")
io_read :: #force_inline proc(addr: u16) -> u8 {
	switch addr {
	case 0xFF01:
		return serialData[0]
	case 0xFF02:
		return serialData[1]
	case 0xFF0F:
		return cpu.intFlags
	case 0xFF04..=0xFF07:
		return Timer_Read(addr)
	case 0xFF44:
		@static asdf: u8 = 0
		asdf += 1
		return asdf
	}

	no_impl(fmt.aprintf("io read (%04X)", addr))
	return 0
}

@(private="file")
io_write :: #force_inline proc(addr: u16, val: u8) {
	switch addr {
	case 0xFF01:
		serialData[0] = val
	case 0xFF02:
		serialData[1] = val
	case 0xFF0F:
		cpu.intFlags = val
	case 0xFF04..=0xFF07:
		Timer_Write(addr, val)
	case 0xFF46:
		DMA_Start(val)
		fmt.println("DMA START")
	case:
		no_impl("io write")
	}
}
