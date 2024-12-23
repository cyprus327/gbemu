package gbemu

import "core:os"
import "core:fmt"

CpuRegisters :: struct {
	a, f, b, c, d, e, h, l: u8,
	pc, sp: u16
}

CpuState :: struct {
	reg: CpuRegisters,

	fetchedData: u16,
	memDest: u16,
	destIsMem: bool,
	currOp: u8,
	currInst: ^Instruction,

	isHalted, isStepping: bool,

	isIntMstOn: bool, // is interrupt master enabled
	ieReg: u8
}

cpu: CpuState

CPU_Init :: proc() {
	instructions[0x00] = Instruction{type = .NOP, mode = .IMP}

	// 0x0X LD
	instructions[0x01] = Instruction{type = .LD, mode = .R_D16, reg1 = .BC}
	instructions[0x02] = Instruction{type = .LD, mode = .MR_R,  reg1 = .BC, reg2 = .A}
	instructions[0x05] = Instruction{type = .LD, mode = .R,     reg1 = .B}
	instructions[0x06] = Instruction{type = .LD, mode = .R_D8,  reg1 = .B}
	instructions[0x08] = Instruction{type = .LD, mode = .A16_R, reg1 = .NONE, reg2 = .SP}
	instructions[0x0A] = Instruction{type = .LD, mode = .R_MR,  reg1 = .A, reg2 = .BC}
	instructions[0x0E] = Instruction{type = .LD, mode = .R_D8,  reg1 = .C}

	// 0x1X LD
	instructions[0x11] = Instruction{type = .LD, mode = .R_D16, reg1 = .DE}
	instructions[0x12] = Instruction{type = .LD, mode = .MR_R,  reg1 = .DE, reg2 = .A}
	instructions[0x15] = Instruction{type = .LD, mode = .R,     reg1 = .D}
	instructions[0x16] = Instruction{type = .LD, mode = .R_D8,  reg1 = .D}
	instructions[0x1A] = Instruction{type = .LD, mode = .R_MR,  reg1 = .A, reg2 = .DE}
	instructions[0x1E] = Instruction{type = .LD, mode = .R_D8,  reg1 = .E}

	// 0x2X LD
	instructions[0x21] = Instruction{type = .LD, mode = .R_D16, reg1 = .HL}
	instructions[0x22] = Instruction{type = .LD, mode = .HLI_R, reg1 = .HL, reg2 = .A}
	instructions[0x25] = Instruction{type = .LD, mode = .R,     reg1 = .H}
	instructions[0x26] = Instruction{type = .LD, mode = .R_D8,  reg1 = .H}
	instructions[0x2A] = Instruction{type = .LD, mode = .R_HLI, reg1 = .A, reg2 = .HL}
	instructions[0x2E] = Instruction{type = .LD, mode = .R_D8,  reg1 = .L}

	// 0x3X LD
	instructions[0x31] = Instruction{type = .LD, mode = .R_D16, reg1 = .SP}
	instructions[0x32] = Instruction{type = .LD, mode = .HLD_R, reg1 = .HL, reg2 = .A}
	instructions[0x35] = Instruction{type = .LD, mode = .R,     reg1 = .HL}
	instructions[0x36] = Instruction{type = .LD, mode = .MR_D8, reg1 = .HL}
	instructions[0x3A] = Instruction{type = .LD, mode = .R_HLD, reg1 = .A, reg2 = .HL}
	instructions[0x3E] = Instruction{type = .LD, mode = .R_D8,  reg1 = .A}

	// 0x4X LD
	instructions[0x40] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .B}
	instructions[0x41] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .C}
	instructions[0x42] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .D}
	instructions[0x43] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .E}
	instructions[0x44] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .H}
	instructions[0x45] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .L}
	instructions[0x46] = Instruction{type = .LD, mode = .R_MR, reg1 = .B, reg2 = .HL}
	instructions[0x47] = Instruction{type = .LD, mode = .R_R,  reg1 = .B, reg2 = .A}
	instructions[0x48] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .B}
	instructions[0x49] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .C}
	instructions[0x4A] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .D}
	instructions[0x4B] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .E}
	instructions[0x4C] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .H}
	instructions[0x4D] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .L}
	instructions[0x4E] = Instruction{type = .LD, mode = .R_MR, reg1 = .C, reg2 = .HL}
	instructions[0x4F] = Instruction{type = .LD, mode = .R_R,  reg1 = .C, reg2 = .A}

	// 0x5X LD
	instructions[0x50] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .B}
	instructions[0x51] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .C}
	instructions[0x52] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .D}
	instructions[0x53] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .E}
	instructions[0x54] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .H}
	instructions[0x55] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .L}
	instructions[0x56] = Instruction{type = .LD, mode = .R_MR, reg1 = .D, reg2 = .HL}
	instructions[0x57] = Instruction{type = .LD, mode = .R_R,  reg1 = .D, reg2 = .A}
	instructions[0x58] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .B}
	instructions[0x59] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .C}
	instructions[0x5A] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .D}
	instructions[0x5B] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .E}
	instructions[0x5C] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .H}
	instructions[0x5D] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .L}
	instructions[0x5E] = Instruction{type = .LD, mode = .R_MR, reg1 = .E, reg2 = .HL}
	instructions[0x5F] = Instruction{type = .LD, mode = .R_R,  reg1 = .E, reg2 = .A}

	// 0x6X LD
	instructions[0x60] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .B}
	instructions[0x61] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .C}
	instructions[0x62] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .D}
	instructions[0x63] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .E}
	instructions[0x64] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .H}
	instructions[0x65] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .L}
	instructions[0x66] = Instruction{type = .LD, mode = .R_MR, reg1 = .H, reg2 = .HL}
	instructions[0x67] = Instruction{type = .LD, mode = .R_R,  reg1 = .H, reg2 = .A}
	instructions[0x68] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .B}
	instructions[0x69] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .C}
	instructions[0x6A] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .D}
	instructions[0x6B] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .E}
	instructions[0x6C] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .H}
	instructions[0x6D] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .L}
	instructions[0x6E] = Instruction{type = .LD, mode = .R_MR, reg1 = .L, reg2 = .HL}
	instructions[0x6F] = Instruction{type = .LD, mode = .R_R,  reg1 = .L, reg2 = .A}

	// 0x7X LD
	instructions[0x70] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .B}
	instructions[0x71] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .C}
	instructions[0x72] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .D}
	instructions[0x73] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .E}
	instructions[0x74] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .H}
	instructions[0x75] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .L}
	instructions[0x76] = Instruction{type = .HALT}
	instructions[0x77] = Instruction{type = .LD, mode = .MR_R, reg1 = .HL, reg2 = .A}
	instructions[0x78] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x79] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x7A] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x7B] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x7C] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x7D] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x7E] = Instruction{type = .LD, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x7F] = Instruction{type = .LD, mode = .R_R,  reg1 = .A, reg2 = .A}

	// 0xEX LD
	instructions[0xE2] = Instruction{type = .LD, mode = .MR_R,  reg1 = .C,    reg2 = .A}
	instructions[0xEA] = Instruction{type = .LD, mode = .A16_R, reg1 = .NONE, reg2 = .A}

	// 0xFX LD
	instructions[0xF2] = Instruction{type = .LD, mode = .R_MR,  reg1 = .A, reg2 = .C}
	instructions[0xFA] = Instruction{type = .LD, mode = .R_A16, reg1 = .A}

	// LDH
	instructions[0xE0] = Instruction{type = .LDH, mode = .A8_R, reg1 = .NONE, reg2 = .A}
	instructions[0xF0] = Instruction{type = .LDH, mode = .R_A8, reg1 = .A}

	// POP
	instructions[0xC1] = Instruction{type = .POP, mode = .R, reg1 = .BC}
	instructions[0xD1] = Instruction{type = .POP, mode = .R, reg1 = .DE}
	instructions[0xE1] = Instruction{type = .POP, mode = .R, reg1 = .HL}
	instructions[0xF1] = Instruction{type = .POP, mode = .R, reg1 = .AF}

	// PUSH
	instructions[0xC5] = Instruction{type = .PUSH, mode = .R, reg1 = .BC}
	instructions[0xD5] = Instruction{type = .PUSH, mode = .R, reg1 = .DE}
	instructions[0xE5] = Instruction{type = .PUSH, mode = .R, reg1 = .HL}
	instructions[0xF5] = Instruction{type = .PUSH, mode = .R, reg1 = .AF}

	// CALL
	instructions[0xC4] = Instruction{type = .CALL, mode = .D16, cond = .NZ}
	instructions[0xCC] = Instruction{type = .CALL, mode = .D16, cond = .Z}
	instructions[0xCD] = Instruction{type = .CALL, mode = .D16}
	instructions[0xD4] = Instruction{type = .CALL, mode = .D16, cond = .NC}
	instructions[0xDC] = Instruction{type = .CALL, mode = .D16, cond = .C}

	// JR
	instructions[0x18] = Instruction{type = .JR, mode = .D8}
	instructions[0x20] = Instruction{type = .JR, mode = .D8, cond = .NZ}
	instructions[0x28] = Instruction{type = .JR, mode = .D8, cond = .Z}
	instructions[0x30] = Instruction{type = .JR, mode = .D8, cond = .NC}
	instructions[0x38] = Instruction{type = .JR, mode = .D8, cond = .C}

	// JP
	instructions[0xC2] = Instruction{type = .JP,  mode = .D16, cond = .NZ}
	instructions[0xC3] = Instruction{type = .JP,  mode = .D16}
	instructions[0xCA] = Instruction{type = .JP,  mode = .D16, cond = .Z}
	instructions[0xD2] = Instruction{type = .JP,  mode = .D16, cond = .NC}
	instructions[0xDA] = Instruction{type = .JP,  mode = .D16, cond = .C}
	instructions[0xE9] = Instruction{type = .JP,  mode = .MR,  reg1 = .HL}

	// RET
	instructions[0xC0] = Instruction{type = .RET, mode = .IMP, cond = .NZ}
	instructions[0xC8] = Instruction{type = .RET, mode = .IMP, cond = .Z}
	instructions[0xC9] = Instruction{type = .RET}
	instructions[0xD0] = Instruction{type = .RET, mode = .IMP, cond = .NC}
	instructions[0xD8] = Instruction{type = .RET, mode = .IMP, cond = .C}
	instructions[0xD9] = Instruction{type = .RETI}

	// RST
	instructions[0xC7] = Instruction{type = .RST, param = 0x00}
	instructions[0xCF] = Instruction{type = .RST, param = 0x08}
	instructions[0xD7] = Instruction{type = .RST, param = 0x10}
	instructions[0xDF] = Instruction{type = .RST, param = 0x18}
	instructions[0xE7] = Instruction{type = .RST, param = 0x20}
	instructions[0xEF] = Instruction{type = .RST, param = 0x28}
	instructions[0xF7] = Instruction{type = .RST, param = 0x30}
	instructions[0xFF] = Instruction{type = .RST, param = 0x38}

	// INC
	instructions[0x03] = Instruction{type = .INC, mode = .R,  reg1 = .BC}
	instructions[0x04] = Instruction{type = .INC, mode = .R,  reg1 = .B}
	instructions[0x0C] = Instruction{type = .INC, mode = .R,  reg1 = .C}
	instructions[0x13] = Instruction{type = .INC, mode = .R,  reg1 = .DE}
	instructions[0x14] = Instruction{type = .INC, mode = .R,  reg1 = .D}
	instructions[0x1C] = Instruction{type = .INC, mode = .R,  reg1 = .E}
	instructions[0x23] = Instruction{type = .INC, mode = .R,  reg1 = .HL}
	instructions[0x24] = Instruction{type = .INC, mode = .R,  reg1 = .H}
	instructions[0x2C] = Instruction{type = .INC, mode = .R,  reg1 = .L}
	instructions[0x33] = Instruction{type = .INC, mode = .R,  reg1 = .SP}
	instructions[0x34] = Instruction{type = .INC, mode = .MR, reg1 = .HL}
	instructions[0x3C] = Instruction{type = .INC, mode = .R,  reg1 = .A}

	// DEC
	instructions[0x05] = Instruction{type = .DEC, mode = .R,  reg1 = .B}
	instructions[0x0B] = Instruction{type = .DEC, mode = .R,  reg1 = .BC}
	instructions[0x0D] = Instruction{type = .DEC, mode = .R,  reg1 = .C}
	instructions[0x15] = Instruction{type = .DEC, mode = .R,  reg1 = .D}
	instructions[0x1B] = Instruction{type = .DEC, mode = .R,  reg1 = .DE}
	instructions[0x1D] = Instruction{type = .DEC, mode = .R,  reg1 = .E}
	instructions[0x25] = Instruction{type = .DEC, mode = .R,  reg1 = .H}
	instructions[0x2B] = Instruction{type = .DEC, mode = .R,  reg1 = .HL}
	instructions[0x2D] = Instruction{type = .DEC, mode = .R,  reg1 = .L}
	instructions[0x35] = Instruction{type = .DEC, mode = .MR, reg1 = .HL}
	instructions[0x3B] = Instruction{type = .DEC, mode = .R,  reg1 = .SP}
	instructions[0x3D] = Instruction{type = .DEC, mode = .R,  reg1 = .A}

	// ADD
	instructions[0x09] = Instruction{type = .ADD, mode = .R_R,  reg1 = .HL, reg2 = .BC}
	instructions[0x19] = Instruction{type = .ADD, mode = .R_R,  reg1 = .HL, reg2 = .DE}
	instructions[0x29] = Instruction{type = .ADD, mode = .R_R,  reg1 = .HL, reg2 = .HL}
	instructions[0x39] = Instruction{type = .ADD, mode = .R_R,  reg1 = .HL, reg2 = .SP}
	instructions[0x80] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .B}
	instructions[0x81] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .C}
	instructions[0x82] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .D}
	instructions[0x83] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .E}
	instructions[0x84] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .H}
	instructions[0x85] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .L}
	instructions[0x86] = Instruction{type = .ADD, mode = .R_MR, reg1 = .A,  reg2 = .HL}
	instructions[0x87] = Instruction{type = .ADD, mode = .R_R,  reg1 = .A,  reg2 = .A}

	// ADC
	instructions[0x88] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x89] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x8A] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x8B] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x8C] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x8D] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x8E] = Instruction{type = .ADC, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x8F] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .A}

	// SUB
	instructions[0x90] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x91] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x92] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x93] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x94] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x95] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x96] = Instruction{type = .SUB, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x97] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .A}

	// SBC
	instructions[0x98] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x99] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x9A] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x9B] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x9C] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x9D] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x9E] = Instruction{type = .SBC, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x9F] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .A}

	instructions[0xAF] = Instruction{type = .XOR, mode = .R, reg1 = .A}

	instructions[0xF3] = Instruction{type = .DI}

	cpu.reg.pc = 0x100
	cpu.reg.a = 1
}

CPU_Step :: proc() -> bool {
	if cpu.isHalted {
		return false
	}

	startPC := cpu.reg.pc

	fetch_inst()
	fetch_data()

	z := cpu.reg.f & (1 << 7) != 0 ? 'Z' : '-'
	n := cpu.reg.f & (1 << 6) != 0 ? 'N' : '-'
	h := cpu.reg.f & (1 << 5) != 0 ? 'H' : '-'
	c := cpu.reg.f & (1 << 4) != 0 ? 'C' : '-'
	fmt.printfln("%08X - %04X: %-4s (%02X %02X %02X), F: %c%c%c%c, A: %02X, BC: %02X%02X, DE: %02X%02X, HL: %02X%02X",
            emu.ticks, startPC, cpu.currInst.type, cpu.currOp,
            Bus_Read(startPC + 1), Bus_Read(startPC + 2),
            z, n, h, c,
            cpu.reg.a, cpu.reg.b, cpu.reg.c, cpu.reg.d, cpu.reg.e, cpu.reg.h, cpu.reg.l);

    if InstType.NONE == cpu.currInst.type || !handle_proc() {
		fmt.printfln("Unknown instruction: %04X, %02X (%s)", startPC, cpu.currOp, cpu.currInst.type)
		return false
	}

	return true
}

@(private="file")
fetch_inst :: proc() {
	cpu.currOp = Bus_Read(cpu.reg.pc)
	cpu.reg.pc += 1

	cpu.currInst = &instructions[cpu.currOp]
}

@(private="file")
fetch_data :: proc() {
	cpu.memDest = 0
	cpu.destIsMem = false

	switch cpu.currInst.mode {
		case .IMP: break
		case .R: {
			cpu.fetchedData = read_reg(cpu.currInst.reg1)
		}
		case .R_R: {
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
		}
		case .R_D8: {
			cpu.fetchedData = u16(Bus_Read(cpu.reg.pc))
			Emu_Cycles(1)
			cpu.reg.pc += 1
		}
		case .R_D16: fallthrough
		case .D16: {
			lo := Bus_Read(cpu.reg.pc)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(2)
			cpu.fetchedData = u16(lo) | (u16(hi) << 8)
			cpu.reg.pc += 2
		}
		case .MR_R: {
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
			cpu.memDest = read_reg(cpu.currInst.reg1)
			cpu.destIsMem = true
			if RegType.C == cpu.currInst.reg1 {
				cpu.memDest |= 0xFF00
			}
		}
		case .R_MR: {
			addr := read_reg(cpu.currInst.reg2)
			if RegType.C == cpu.currInst.reg1 {
				addr |= 0xFF00
			}
			cpu.fetchedData = u16(Bus_Read(addr))
			Emu_Cycles(1)
		}
		case .R_HLI: {
			cpu.fetchedData = u16(Bus_Read(read_reg(cpu.currInst.reg2)))
			Emu_Cycles(1)
			set_reg(RegType.HL, read_reg(RegType.HL) + 1)
		}
		case .R_HLD: {
			cpu.fetchedData = u16(Bus_Read(read_reg(cpu.currInst.reg2)))
			Emu_Cycles(1)
			set_reg(RegType.HL, read_reg(RegType.HL) - 1)
		}
		case .HLI_R: {
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
			cpu.memDest = read_reg(cpu.currInst.reg1)
			cpu.destIsMem = true
			set_reg(RegType.HL, read_reg(RegType.HL) + 1)
		}
		case .HLD_R: {
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
			cpu.memDest = read_reg(cpu.currInst.reg1)
			cpu.destIsMem = true
			set_reg(RegType.HL, read_reg(RegType.HL) - 1)
		}
		case .R_A8: {
			cpu.fetchedData = u16(Bus_Read(cpu.reg.pc))
			Emu_Cycles(1)
			cpu.reg.pc += 1
		}
		case .A8_R: {
			cpu.memDest = u16(Bus_Read(cpu.reg.pc)) | 0xFF00
			Emu_Cycles(1)
			cpu.reg.pc += 1
			cpu.destIsMem = true
		}
		case .HL_SPR: {
			cpu.fetchedData = u16(Bus_Read(cpu.reg.pc))
			Emu_Cycles(1)
			cpu.reg.pc += 1
		}
		case .D8: {
			cpu.fetchedData = u16(Bus_Read(cpu.reg.pc))
			Emu_Cycles(1)
			cpu.reg.pc += 1
		}
		case .R_A16: {
			lo := Bus_Read(cpu.reg.pc)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(2)
			cpu.reg.pc += 2
			addr := u16(lo) | (u16(hi) << 8)
			cpu.fetchedData = u16(Bus_Read(addr))
			Emu_Cycles(1)
		}
		case .A16_R: {
			lo := Bus_Read(cpu.reg.pc)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(2)
			cpu.reg.pc += 2
			cpu.memDest = u16(lo) | (u16(hi) << 8)
			cpu.destIsMem = true
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
		}
		case .D16_R: {
			lo := Bus_Read(cpu.reg.pc)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(2)
			cpu.reg.pc += 2
			cpu.memDest = u16(lo) | (u16(hi) << 8)
			cpu.destIsMem = true
			cpu.fetchedData = read_reg(cpu.currInst.reg2)
		}
		case .MR_D8: {
			cpu.fetchedData = u16(Bus_Read(cpu.reg.pc))
			Emu_Cycles(1)
			cpu.reg.pc += 1
			cpu.memDest = read_reg(cpu.currInst.reg1)
			cpu.destIsMem = true
		}
		case .MR: {
			cpu.fetchedData = u16(Bus_Read(read_reg(cpu.currInst.reg1)))
			Emu_Cycles(1)
			cpu.memDest = read_reg(cpu.currInst.reg1)
			cpu.destIsMem = true
		}
		case: {
			fmt.println("Unknown AddrMode:", cpu.currInst.mode)
			os.exit(1)
		}
	}
}

@(private="file")
read_reg :: proc(type: RegType) -> u16 {
	switch type {
		case .A: return u16(cpu.reg.a)
		case .F: return u16(cpu.reg.f)
		case .B: return u16(cpu.reg.b)
		case .C: return u16(cpu.reg.c)
		case .D: return u16(cpu.reg.d)
		case .E: return u16(cpu.reg.e)
		case .H: return u16(cpu.reg.h)
		case .L: return u16(cpu.reg.l)

		case .AF: return u16(cpu.reg.f) | (u16(cpu.reg.a) << 8)
		case .BC: return u16(cpu.reg.c) | (u16(cpu.reg.b) << 8)
		case .DE: return u16(cpu.reg.e) | (u16(cpu.reg.d) << 8)
		case .HL: return u16(cpu.reg.l) | (u16(cpu.reg.h) << 8)

		case .PC: return cpu.reg.pc
		case .SP: return cpu.reg.sp

		case .NONE: return 0
		case: return 0
	}
}

@(private="file")
set_reg :: proc(type: RegType, val: u16) {
	switch type {
		case .A: cpu.reg.a = u8(val & 0xFF)
		case .F: cpu.reg.f = u8(val & 0xFF)
		case .B: cpu.reg.b = u8(val & 0xFF)
		case .C: cpu.reg.c = u8(val & 0xFF)
		case .D: cpu.reg.d = u8(val & 0xFF)
		case .E: cpu.reg.e = u8(val & 0xFF)
		case .H: cpu.reg.h = u8(val & 0xFF)
		case .L: cpu.reg.l = u8(val & 0xFF)

		case .AF: cpu.reg.a = u8((val & 0xFF00) >> 8); cpu.reg.f = u8(val & 0xFF)
		case .BC: cpu.reg.b = u8((val & 0xFF00) >> 8); cpu.reg.c = u8(val & 0xFF)
		case .DE: cpu.reg.d = u8((val & 0xFF00) >> 8); cpu.reg.e = u8(val & 0xFF)
		case .HL: cpu.reg.h = u8((val & 0xFF00) >> 8); cpu.reg.l = u8(val & 0xFF)

		case .PC: cpu.reg.pc = val
		case .SP: cpu.reg.sp = val

		case .NONE: break
	}
}

@(private="file")
set_flags :: proc(z, n, h, c: i8) {
	if -1 != z {
		cpu.reg.f = u8(set_bit(uint(cpu.reg.f), 7, z != 0))
	}
	if -1 != n {
		cpu.reg.f = u8(set_bit(uint(cpu.reg.f), 6, n != 0))
	}
	if -1 != h {
		cpu.reg.f = u8(set_bit(uint(cpu.reg.f), 5, h != 0))
	}
	if -1 != c {
		cpu.reg.f = u8(set_bit(uint(cpu.reg.f), 4, c != 0))
	}
}

@(private="file")
handle_proc :: proc() -> (ok: bool) {
	#partial switch cpu.currInst.type {
		case .NONE: {
			fmt.println("INVALID INSTRUCTION")
			os.exit(1)
		}
		case .NOP: {
			break
		}
		case .LD: {
			if cpu.destIsMem {
				if is_16bit(cpu.currInst.reg1) {
					Bus_Write16(cpu.memDest, cpu.fetchedData)
				} else {
					Bus_Write(cpu.memDest, u8(cpu.fetchedData & 0xFF))
				}
				Emu_Cycles(1)
				break
			}

			if AddrMode.HL_SPR == cpu.currInst.mode {
				reg2 := read_reg(cpu.currInst.reg2)
				hFlag: i8 = (reg2 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				cFlag: i8 = (reg2 & 0xFF) + (cpu.fetchedData & 0xFF) >= 0x100
				set_flags(0, 0, hFlag, cFlag)
				set_reg(cpu.currInst.reg1, u16(i32(reg2) + i32(cpu.fetchedData)))
			}

			set_reg(cpu.currInst.reg1, cpu.fetchedData)
		}
		case .LDH: {
			if RegType.A == cpu.currInst.reg1 {
				set_reg(cpu.currInst.reg1, u16(Bus_Read(0xFF00 | cpu.fetchedData)))
			} else {
				Bus_Write(cpu.memDest, cpu.reg.a)
			}
			Emu_Cycles(1)
		}
		case .JP: {
			goto_addr(cpu.fetchedData, false)
		}
		case .JR: {
			rel := i8(cpu.fetchedData & 0xFF)
			goto_addr(u16(i32(cpu.reg.pc) + i32(rel)), false)
		}
		case .RETI:
			cpu.isIntMstOn = true
			fallthrough
		case .RET: {
			if CondType.NONE != cpu.currInst.cond {
				Emu_Cycles(1)
			}
			if check_cond() {
				lo := stack_pop()
				hi := stack_pop()
				cpu.reg.pc = (u16(hi) << 8) | u16(lo)
				Emu_Cycles(3)
			}
		}
		case .CALL: {
			goto_addr(cpu.fetchedData, true)
		}
		case .RST: {
			goto_addr(u16(cpu.currInst.param), true)
		}
		case .XOR: {
			cpu.reg.a ~= u8(cpu.fetchedData & 0xFF)
			set_flags(0 == cpu.reg.a, 0, 0, 0)
		}
		case .DI: {
			cpu.isIntMstOn = false
		}
		case .POP: {
			lo := stack_pop()
			hi := stack_pop()
			Emu_Cycles(2)
			n := (u16(hi) << 8) | u16(lo)
			if RegType.AF == cpu.currInst.reg1 {
				set_reg(RegType.AF, n & 0xFFF0)
			} else {
				set_reg(cpu.currInst.reg1, n)
			}
		}
		case .PUSH: {
			hi := u8((read_reg(cpu.currInst.reg1) >> 8) & 0xFF)
			lo := u8(read_reg(cpu.currInst.reg2) & 0xFF)
			stack_push(hi)
			stack_push(lo)
			Emu_Cycles(2)
		}
		case .INC: {
			val := read_reg(cpu.currInst.reg1) + 1
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
			}
			if RegType.HL == cpu.currInst.reg1 && AddrMode.MR == cpu.currInst.mode {
				hlReg := read_reg(RegType.HL)
				val = u16(Bus_Read(hlReg) + 1) & 0xFF
				Bus_Write(hlReg, u8(val))
			} else {
				set_reg(cpu.currInst.reg1, val)
				val = read_reg(cpu.currInst.reg1)
			}
			if 0x03 == (cpu.currOp & 0x03) {
				break
			}
			set_flags(0 == val, 0, (val & 0x0F) == 0, -1)
		}
		case .DEC: {
			val := read_reg(cpu.currInst.reg1) - 1
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
			}
			if RegType.HL == cpu.currInst.reg1 && AddrMode.MR == cpu.currInst.mode {
				hlReg := read_reg(RegType.HL)
				val = u16(Bus_Read(hlReg) - 1) & 0xFF
				Bus_Write(hlReg, u8(val))
			} else {
				set_reg(cpu.currInst.reg1, val)
				val = read_reg(cpu.currInst.reg1)
			}
			if 0x0B == (cpu.currOp & 0x0B) {
				break
			}
			set_flags(0 == val, 1, (val & 0x0F) == 0x0F, -1)
		}
		case .ADD: {
			reg1 := read_reg(cpu.currInst.reg1)
			val := u32(reg1) + u32(cpu.fetchedData)
			if RegType.SP == cpu.currInst.reg1 {
				val = u32(i32(reg1) + i32(cpu.fetchedData))
			}
			z, h, c: i8
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
				z = -1
				h = (reg1 & 0xFFF) + (cpu.fetchedData & 0xFFF) >= 0x1000
				c = u32(reg1) + u32(cpu.fetchedData) >= 0x10000
			} else {
				z = 0 == val & 0xFF
				h = (reg1 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				c = (reg1 & 0xFF) + (cpu.fetchedData & 0xFF) >= 0x100
			}
			if RegType.SP == cpu.currInst.reg1 {
				z = 0
				h = (reg1 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				c = (reg1 & 0xFF) + (cpu.fetchedData & 0xFF) >= 0x100
			}
			set_reg(cpu.currInst.reg1, u16(val & 0xFFFF))
			set_flags(z, 0, h, c)
		}
		case .ADC: {
			u := cpu.fetchedData
			a := u16(cpu.reg.a)
			c := u16(get_carry_flag(cpu.reg.f))
			cpu.reg.a = u8((a + u + c) & 0xFF)
			set_flags(0 == cpu.reg.a, 0,
				(a & 0xF) + (u & 0xF) + c > 0xF,
				a + u + c > 0xFF)
		}
		case .SUB: {
			reg1 := read_reg(cpu.currInst.reg1)
			val := reg1 + cpu.fetchedData
			z := 0 == val
			h := (reg1 & 0xF) - (cpu.fetchedData & 0xF) < 0
			c := reg1 - cpu.fetchedData < 0
			set_reg(cpu.currInst.reg1, val)
			set_flags(i8(z), 1, i8(h), i8(c))
		}
		case .SBC: {
			reg1 := i32(read_reg(cpu.currInst.reg1))
			carry := i32(get_carry_flag(cpu.reg.f))
			val := cpu.fetchedData + u16(carry)
			z := 0 == reg1 - i32(val)
			h := (reg1 & 0xF) - i32(cpu.fetchedData & 0xF) - carry < 0
			c := reg1 - i32(cpu.fetchedData) - carry < 0
			set_reg(cpu.currInst.reg1, u16(reg1 - i32(val)))
			set_flags(i8(z), 1, i8(h), i8(c))
		}
		case: return false
	}

	return true
}

@(private="file")
goto_addr :: proc(addr: u16, pushPC: bool) {
	if !check_cond() {
		return
	}

	if pushPC {
		stack_push16(cpu.reg.pc)
		Emu_Cycles(2)
	}

	cpu.reg.pc = addr
	Emu_Cycles(1)
}

@(private="file")
check_cond :: proc() -> (canJump: bool) {
	#partial switch cpu.currInst.cond {
		case .NONE: return true
		case .C: return get_carry_flag(cpu.reg.f)
		case .NC: return !get_carry_flag(cpu.reg.f)
		case .Z: return get_zero_flag(cpu.reg.f)
		case .NZ: return !get_zero_flag(cpu.reg.f)
	}

	return false
}

@(private="file")
get_zero_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 7)
}

@(private="file")
get_carry_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 4)
}

@(private="file")
stack_push :: #force_inline proc(data: u8) {
	cpu.reg.sp -= 1
	Bus_Write(cpu.reg.sp, data)
}

@(private="file")
stack_push16 :: #force_inline proc(data: u16) {
	stack_push(u8((data >> 8) & 0xFF))
	stack_push(u8(data & 0xFF))
}

@(private="file")
stack_pop :: proc() -> u8 {
	cpu.reg.sp += 1
	return Bus_Read(cpu.reg.sp - 1)
}

@(private="file")
stack_pop16 :: proc() -> u16 {
	lo := stack_pop()
	hi := stack_pop()
	return (u16(hi) << 8) | u16(lo)
}

@(private="file")
is_16bit :: #force_inline proc(type: RegType) -> bool {
	return type >= RegType.AF
}
