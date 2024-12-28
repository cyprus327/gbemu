package gbemu

import "core:os"
import "core:io"
import "core:fmt"
import "core:bufio"
import "core:strings"

CPURegisters :: struct {
	a, f, b, c, d, e, h, l: u8,
	pc, sp: u16
}

CPUState :: struct {
	reg: CPURegisters,

	fetchedData: u16,
	memDest: u16,
	destIsMem: bool,
	currOp: u8,
	currInst: ^Instruction,

	isHalted, isStepping: bool,
	intFlags: u8,

	isIntMstOn: bool, // is interrupt master enabled
	enablingIME: bool,
	ieReg: u8
}

TimerState :: struct {
	div: u16,
	tima, tma, tac: u8
}

cpu: CPUState
timer: TimerState

correctOutput: []string
cOutData: []u8

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
	instructions[0xF2] = Instruction{type = .LD, mode = .R_MR,   reg1 = .A, reg2 = .C}
	instructions[0xF8] = Instruction{type = .LD, mode = .HL_SPR, reg1 = .HL, reg2 = .SP}
	instructions[0xF9] = Instruction{type = .LD, mode = .R_R,    reg1 = .SP, reg2 = .HL}
	instructions[0xFA] = Instruction{type = .LD, mode = .R_A16,  reg1 = .A}

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
	instructions[0xE9] = Instruction{type = .JP,  mode = .R,   reg1 = .HL}

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
	instructions[0xC6] = Instruction{type = .ADD, mode = .R_D8, reg1 = .A}
	instructions[0xE8] = Instruction{type = .ADD, mode = .R_D8, reg1 = .SP}

	// ADC
	instructions[0x88] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x89] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x8A] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x8B] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x8C] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x8D] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x8E] = Instruction{type = .ADC, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x8F] = Instruction{type = .ADC, mode = .R_R,  reg1 = .A, reg2 = .A}
	instructions[0xCE] = Instruction{type = .ADC, mode = .R_D8, reg1 = .A}

	// SUB
	instructions[0xD6] = Instruction{type = .SUB, mode = .R_D8, reg1 = .A}
	instructions[0x90] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x91] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x92] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x93] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x94] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x95] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x96] = Instruction{type = .SUB, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x97] = Instruction{type = .SUB, mode = .R_R,  reg1 = .A, reg2 = .A}

	// SBC
	instructions[0xDE] = Instruction{type = .SBC, mode = .R_D8, reg1 = .A}
	instructions[0x98] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0x99] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0x9A] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0x9B] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0x9C] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0x9D] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0x9E] = Instruction{type = .SBC, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0x9F] = Instruction{type = .SBC, mode = .R_R,  reg1 = .A, reg2 = .A}

	// AND
	instructions[0xA0] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0xA1] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0xA2] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0xA3] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0xA4] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0xA5] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0xA6] = Instruction{type = .AND, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0xA7] = Instruction{type = .AND, mode = .R_R,  reg1 = .A, reg2 = .A}
	instructions[0xE6] = Instruction{type = .AND, mode = .R_D8, reg1 = .A}

	// XOR
	instructions[0xA8] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0xA9] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0xAA] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0xAB] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0xAC] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0xAD] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0xAE] = Instruction{type = .XOR, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0xAF] = Instruction{type = .XOR, mode = .R_R,  reg1 = .A, reg2 = .A}
	instructions[0xEE] = Instruction{type = .XOR, mode = .R_D8, reg1 = .A}

	// OR
	instructions[0xB0] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0xB1] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0xB2] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0xB3] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0xB4] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0xB5] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0xB6] = Instruction{type = .OR, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0xB7] = Instruction{type = .OR, mode = .R_R,  reg1 = .A, reg2 = .A}
	instructions[0xF6] = Instruction{type = .OR, mode = .R_D8, reg1 = .A}

	// CP
	instructions[0xB8] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .B}
	instructions[0xB9] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .C}
	instructions[0xBA] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .D}
	instructions[0xBB] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .E}
	instructions[0xBC] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .H}
	instructions[0xBD] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .L}
	instructions[0xBE] = Instruction{type = .CP, mode = .R_MR, reg1 = .A, reg2 = .HL}
	instructions[0xBF] = Instruction{type = .CP, mode = .R_R,  reg1 = .A, reg2 = .A}
	instructions[0xFE] = Instruction{type = .CP, mode = .R_D8, reg1 = .A}

	// CPL
	instructions[0x2F] = Instruction{type = .CPL}

	// RLCA, RRCA, RLA, RRA
	instructions[0x07] = Instruction{type = .RLCA}
	instructions[0x0F] = Instruction{type = .RRCA}
	instructions[0x17] = Instruction{type = .RLA}
	instructions[0x1F] = Instruction{type = .RRA}

	// SCF, CCF
	instructions[0x37] = Instruction{type = .SCF}
	instructions[0x3F] = Instruction{type = .CCF}

	// DAA
	instructions[0x27] = Instruction{type = .DAA}

	// CB
	instructions[0xCB] = Instruction{type = .CB, mode = .D8}

	// DI
	instructions[0xF3] = Instruction{type = .DI}

	// EI
	instructions[0xFB] = Instruction{type = .EI}

	// STOP, HALT
	instructions[0x10] = Instruction{type = .STOP}
	instructions[0x76] = Instruction{type = .HALT}

	// for inst, ind in instructions {
	// 	if inst.type == InstType.NONE {
	// 		read_pause(fmt.aprintf("%02X\n", ind))
	// 	}
	// }

	cpu.reg.pc = 0x100
	cpu.reg.sp = 0xFFFE
	cpu.reg.a = 0x01
	cpu.reg.f = 0xB0
	cpu.reg.b = 0x00
	cpu.reg.c = 0x13
	cpu.reg.d = 0x00
	cpu.reg.e = 0xD8
	cpu.reg.h = 0x01
	cpu.reg.l = 0x4D

	// timer.div = 0xAC00
	timer.div = 0xABCC

	// file, err := os.open("out/c.txt")
	// if 0 != err {
	// 	fmt.println("Failed to read correct output")
	// 	os.exit(1)
	// }
	// defer os.close(file)

	// stream := os.stream_from_handle(file)
	// reader, ok := io.to_reader(stream)
	// if !ok {
	// 	fmt.println("Failed to convert stream to reader")
	// 	os.exit(1)
	// }

	// correctOutputBuf = make([]u8, os.file_size_from_path("out/c.txt"))
	// bufio.reader_init_with_buf(&correctOutput, reader, correctOutputBuf)

	cOutData, ok := os.read_entire_file("out/c.txt")
	if !ok {
		fmt.println("Failed to read c.txt")
		os.exit(1)
	}

	// str := string(cOutData)
	// correctOutput = strings.split_lines(str)
	// for line in 0..<5 {
	// 	fmt.println(correctOutput[line])
	// }
}

CPU_Step :: proc() -> bool {
	if cpu.isHalted {
		Emu_Cycles(1)
		if 0 != cpu.intFlags {
			cpu.isHalted = false
		}
	}

	if cpu.isHalted {
		return true
	}

	startPC := cpu.reg.pc

	fetch_inst()
	Emu_Cycles(1)
	fetch_data()

	z := cpu.reg.f & (1 << 7) != 0 ? 'Z' : '-'
	n := cpu.reg.f & (1 << 6) != 0 ? 'N' : '-'
	h := cpu.reg.f & (1 << 5) != 0 ? 'H' : '-'
	c := cpu.reg.f & (1 << 4) != 0 ? 'C' : '-'
	fmt.printfln("%08X - %04X: %-12s (%02X %02X %02X), F: %c%c%c%c, A: %02X, BC: %02X%02X, DE: %02X%02X, HL: %02X%02X",
        emu.ticks, startPC, Inst_ToString(cpu.currInst^), cpu.currOp,
        Bus_Read(startPC + 1), Bus_Read(startPC + 2),
        z, n, h, c,
        cpu.reg.a, cpu.reg.b, cpu.reg.c, cpu.reg.d, cpu.reg.e, cpu.reg.h, cpu.reg.l
    )

    /*
	@static count: u32 = 0
	str := correctOutput[count]
	count += 1

	offset := 0
	hadErr := false
	errStr := make([]u8, len(str))
	defer delete(errStr)
	for i in 0..<len(str) {
		errStr[i] = ' '
	}

	split := strings.split(str, "|")

	check := fmt.aprintf("%08X", emu.ticks)
	if split[0] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%04X", startPC)
	if split[1] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%02X%02X%02X", cpu.currOp, Bus_Read(startPC + 1), Bus_Read(startPC + 2))
	if split[2] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%c%c%c%c", z, n, h, c)
	if split[3] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%02X", cpu.reg.a)
	if split[4] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%02X%02X", cpu.reg.b, cpu.reg.c)
	if split[5] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%02X%02X", cpu.reg.d, cpu.reg.e)
	if split[6] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	offset += len(check) + 1
	check = fmt.aprintf("%02X%02X", cpu.reg.h, cpu.reg.l)
	if split[7] != check {
		for i := offset + 1; i < offset + len(check) - 1; i += 1 {
			errStr[i] = '-'
		}
		errStr[offset] = '^'
		errStr[offset + len(check) - 1] = '^'
		hadErr = true
	}
	if hadErr {
		read_pause(fmt.aprintfln("%s\n%s", str, errStr))
	}
    // */

    if InstType.NONE == cpu.currInst.type || !handle_proc() {
		fmt.printfln("Unknown instruction: %04X, %02X (%s)", startPC, cpu.currOp, cpu.currInst.type)
		return false
	}

	Debug_Update()
	Debug_Print()

	if cpu.isIntMstOn {
		Interrupt_HandleAll()
		cpu.enablingIME = false
	}

	if cpu.enablingIME {
		cpu.isIntMstOn = true
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
			Emu_Cycles(1)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(1)
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
			if RegType.C == cpu.currInst.reg2 {
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
			Emu_Cycles(1)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(1)
			cpu.reg.pc += 2
			addr := u16(lo) | (u16(hi) << 8)
			cpu.fetchedData = u16(Bus_Read(addr))
			Emu_Cycles(1)
		}
		case .D16_R: fallthrough
		case .A16_R: {
			lo := Bus_Read(cpu.reg.pc)
			Emu_Cycles(1)
			hi := Bus_Read(cpu.reg.pc + 1)
			Emu_Cycles(1)
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
read_reg8 :: proc(type: RegType) -> u8 {
	#partial switch type {
		case .A: return cpu.reg.a
		case .F: return cpu.reg.f
		case .B: return cpu.reg.b
		case .C: return cpu.reg.c
		case .D: return cpu.reg.d
		case .E: return cpu.reg.e
		case .H: return cpu.reg.h
		case .L: return cpu.reg.l
		case .HL: return Bus_Read(read_reg(RegType.HL))
		case:
			no_impl("invalid read_reg8")
			os.exit(1);
	}
}

set_reg8 :: proc(type: RegType, val: u8) {
	#partial switch type {
		case .A: cpu.reg.a = val
		case .F: cpu.reg.f = val
		case .B: cpu.reg.b = val
		case .C: cpu.reg.c = val
		case .D: cpu.reg.d = val
		case .E: cpu.reg.e = val
		case .H: cpu.reg.h = val
		case .L: cpu.reg.l = val
		case .HL: Bus_Write(read_reg(RegType.HL), val)
		case:
			no_impl(fmt.aprintf("invalid set_reg8, type: %s, val: %02X", type, val))
			os.exit(1)
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
		case .STOP: {
			fmt.println("STOP")
			return false
		}
		case .CB: {
			@static @rodata
			regTypes := []RegType{ .B, .C, .D, .E, .H, .L, .HL, .A }
			reg := regTypes[cpu.fetchedData & 0b111]
			bit := (cpu.fetchedData >> 3) & 0b111
			bitOp := (cpu.fetchedData >> 6) & 0b11

			if RegType.HL == reg {
				Emu_Cycles(2)
			}
			Emu_Cycles(1)

			regVal := read_reg8(reg)

			switch bitOp {
				case 1: // BIT
					set_flags(0 == (regVal & (1 << bit)), 0, 1, -1)
					return true
				case 2: // RST
					regVal &= ~(1 << bit)
					set_reg8(reg, regVal)
					return true
				case 3: // SET
					regVal |= (1 << bit)
					set_reg8(reg, regVal)
					return true
			}

			c := get_c_flag(cpu.reg.f)
			switch bit {
				case 0: // RLC
					setC: i8 = 0
					res := u8((regVal << 1) & 0xFF)
					if 0 != regVal & (1 << 7) {
						res |= 1
						setC = 1
					}
					set_reg8(reg, res)
					set_flags(0 == res, 0, 0, setC)
				case 1: // RRC
					old := regVal
					regVal >>= 1
					regVal |= (old << 7)
					set_reg8(reg, regVal)
					set_flags(0 == regVal, 0, 0, i8(old & 1))
				case 2: // RL
					old := regVal
					regVal <<= 1
					regVal |= (c ? 1 : 0)
					set_reg8(reg, regVal)
					set_flags(0 == regVal, 0, 0, 0 != (old & 0x80))
				case 3: // RR
					old := regVal
					regVal >>= 1
					regVal |= (c ? 1 : 0) << 7
					set_reg8(reg, regVal)
					set_flags(0 == regVal, 0, 0, i8(old & 1))
				case 4: // SLA
					old := regVal
					regVal <<= 1
					set_reg8(reg, regVal)
					set_flags(0 == regVal, 0, 0, 0 != (old & 0x80))
				case 5: // SRA
					u: u8 = u8(i8(regVal) >> 1)
					set_reg8(reg, u)
					set_flags(0 == u, 0, 0, i8(regVal & 1))
				case 6: // SWAP
					regVal = ((regVal & 0xF0) >> 4) | ((regVal & 0x0F) << 4)
					set_reg8(reg, regVal)
					set_flags(0 == regVal, 0, 0, 0)
				case 7: // SRL
					u := regVal >> 1
					set_reg8(reg, u)
					set_flags(0 == u, 0, 0, i8(regVal & 1))
			}
		}
		case .RLCA: {
			u := cpu.reg.a
			c := (u >> 7) & 1
			u = (u << 1) | c
			cpu.reg.a = u
			set_flags(0, 0, 0, i8(c))
		}
		case .RRCA: {
			u := cpu.reg.a & 1
			cpu.reg.a >>= 1
			cpu.reg.a |= (u << 7)
			set_flags(0, 0, 0, i8(u))
		}
		case .RLA: {
			u := cpu.reg.a
			c := (u >> 7) & 1
			cpu.reg.a = (u << 1) | u8(get_c_flag(cpu.reg.f))
			set_flags(0, 0, 0, i8(c))
		}
		case .RRA: {
			c := cpu.reg.a & 1
			cpu.reg.a >>= 1
			cpu.reg.a |= u8((get_c_flag(cpu.reg.f) ? 1 : 0) << 7)
			set_flags(0, 0, 0, i8(c))
		}
		case .DAA: {
			u, c, f: u8 = 0, 0, cpu.reg.f
			if get_h_flag(f) || (!get_n_flag(f) && (cpu.reg.a & 0xF) > 9) {
				u = 6
			}
			if get_c_flag(f) || (!get_n_flag(f) && cpu.reg.a > 0x99) {
				u |= 0x60
				c = 1
			}
			cpu.reg.a = get_n_flag(f) ? u8(i16(cpu.reg.a) - i16(u)) : cpu.reg.a + u
			set_flags(0 == cpu.reg.a, -1, 0, i8(c))
		}
		case .CPL: {
			cpu.reg.a = ~cpu.reg.a
			set_flags(-1, 1, 1, -1)
		}
		case .SCF: {
			set_flags(-1, 0, 0, 1)
		}
		case .CCF: {
			set_flags(-1, 0, 0, i8((get_c_flag(cpu.reg.f) ? 1 : 0) ~ 1))
		}
		case .HALT: {
			fmt.println("HALTED")
			cpu.isHalted = true
		}
		case .LD: {
			if cpu.destIsMem {
				if is_16bit(cpu.currInst.reg2) {
					Bus_Write16(cpu.memDest, cpu.fetchedData)
					Emu_Cycles(1)
				} else {
					Bus_Write(cpu.memDest, u8(cpu.fetchedData))
				}
				Emu_Cycles(1)
				break
			}

			if AddrMode.HL_SPR == cpu.currInst.mode {
				reg2 := read_reg(cpu.currInst.reg2)
				hFlag: u8 = (reg2 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				cFlag: u8 = (reg2 & 0xFF) + (cpu.fetchedData & 0xFF) >= 0x100
				set_flags(0, 0, 0 != hFlag, 0 != cFlag)
				set_reg(cpu.currInst.reg1, u16(i32(reg2) + i32(i8(cpu.fetchedData))))
				break
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
				lo := Stack_Pop()
				Emu_Cycles(1)
				hi := Stack_Pop()
				Emu_Cycles(1)
				cpu.reg.pc = (u16(hi) << 8) | u16(lo)
				Emu_Cycles(1)
			}
		}
		case .CALL: {
			goto_addr(cpu.fetchedData, true)
		}
		case .RST: {
			goto_addr(u16(cpu.currInst.param), true)
		}
		case .AND: {
			cpu.reg.a &= u8(cpu.fetchedData)
			set_flags(0 == cpu.reg.a, 0, 1, 0)
		}
		case .XOR: {
			cpu.reg.a ~= u8(cpu.fetchedData & 0xFF)
			set_flags(0 == cpu.reg.a, 0, 0, 0)
		}
		case .OR: {
			cpu.reg.a |= u8(cpu.fetchedData & 0xFF)
			set_flags(0 == cpu.reg.a, 0, 0, 0)
		}
		case .CP: {
			n := i32(cpu.reg.a) - i32(cpu.fetchedData)
			set_flags(0 == n, 1, i32(cpu.reg.a & 0xF) - i32(cpu.fetchedData & 0xF) < 0, n < 0)
		}
		case .DI: {
			cpu.isIntMstOn = false
		}
		case .EI: {
			cpu.enablingIME = true
		}
		case .POP: {
			lo := Stack_Pop()
			Emu_Cycles(1)
			hi := Stack_Pop()
			Emu_Cycles(1)
			n := (u16(hi) << 8) | u16(lo)
			set_reg(cpu.currInst.reg1, RegType.AF == cpu.currInst.reg1 ? n & 0xFFF0 : n)
		}
		case .PUSH: {
			hi := u8((read_reg(cpu.currInst.reg1) >> 8) & 0xFF)
			lo := u8(read_reg(cpu.currInst.reg1) & 0xFF)
			Emu_Cycles(1)
			Stack_Push(hi)
			Emu_Cycles(1)
			Stack_Push(lo)
			Emu_Cycles(1)
		}
		case .INC: {
			val := read_reg(cpu.currInst.reg1) + 1
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
			}
			if RegType.HL == cpu.currInst.reg1 && AddrMode.MR == cpu.currInst.mode {
				hlReg := read_reg(RegType.HL)
				val = u16(Bus_Read(hlReg)) + 1
				val &= 0xFF
				Bus_Write(hlReg, u8(val))
			} else {
				set_reg(cpu.currInst.reg1, val)
				val = read_reg(cpu.currInst.reg1)
			}
			if 0x3 == (cpu.currOp & 0x3) {
				break
			}
			set_flags(0 == val, 0, 0 == (val & 0xF), -1)
		}
		case .DEC: {
			r1Orig := read_reg(cpu.currInst.reg1)
			val := read_reg(cpu.currInst.reg1) - 1
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
			}
			if RegType.HL == cpu.currInst.reg1 && AddrMode.MR == cpu.currInst.mode {
				hlReg := read_reg(RegType.HL)
				val = u16(Bus_Read(hlReg)) - 1
				Bus_Write(hlReg, u8(val))
			} else {
				set_reg(cpu.currInst.reg1, val)
				val = read_reg(cpu.currInst.reg1)
			}
			if 0xB == (cpu.currOp & 0xB) {
				break
			}
			set_flags(0 == val, 1, 0xF == (val & 0xF), -1)
		}
		case .ADD: {
			reg1 := read_reg(cpu.currInst.reg1)
			val := u32(reg1) + u32(cpu.fetchedData)
			if RegType.SP == cpu.currInst.reg1 {
				val = u32(i32(reg1) + i32(i8(cpu.fetchedData)))
			}
			z, h, c: i8
			if is_16bit(cpu.currInst.reg1) {
				Emu_Cycles(1)
				z = -1
				h = (reg1 & 0xFFF) + (cpu.fetchedData & 0xFFF) >= 0x1000
				c = u32(reg1) + u32(cpu.fetchedData) >= 0x10000
			} else {
				z = 0 == (val & 0xFF)
				h = (reg1 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				c = i32(reg1 & 0xFF) + i32(cpu.fetchedData & 0xFF) >= 0x100
			}
			if RegType.SP == cpu.currInst.reg1 {
				z = 0
				h = (reg1 & 0x0F) + (cpu.fetchedData & 0x0F) >= 0x010
				c = i32(reg1 & 0xFF) + i32(cpu.fetchedData & 0xFF) >= 0x100
			}
			set_reg(cpu.currInst.reg1, u16(val & 0xFFFF))
			set_flags(z, 0, h, c)
		}
		case .ADC: {
			u := cpu.fetchedData
			a := u16(cpu.reg.a)
			c := u16(get_c_flag(cpu.reg.f))
			cpu.reg.a = u8((a + u + c) & 0xFF)
			set_flags(0 == cpu.reg.a, 0,
				(a & 0xF) + (u & 0xF) + c > 0xF,
				a + u + c > 0xFF)
		}
		case .SUB: {
			reg1 := read_reg(cpu.currInst.reg1)
			val := reg1 - cpu.fetchedData
			z := 0 == val
			h := (i32(reg1) & 0xF) - (i32(cpu.fetchedData) & 0xF) < 0
			c := i32(reg1) - i32(cpu.fetchedData) < 0
			set_reg(cpu.currInst.reg1, val)
			set_flags(i8(z), 1, i8(h), i8(c))
		}
		case .SBC: {
			reg1 := read_reg(cpu.currInst.reg1)
			carry := i32(get_c_flag(cpu.reg.f))
			val := u8(cpu.fetchedData + u16(carry))
			z := 0 == reg1 - u16(val)
			h := (i32(reg1) & 0xF) - (i32(cpu.fetchedData) & 0xF) - carry < 0
			c := i32(reg1) - i32(cpu.fetchedData) - carry < 0
			set_reg(cpu.currInst.reg1, reg1 - u16(val))
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
		Stack_Push16(cpu.reg.pc)
		Emu_Cycles(2)
	}

	cpu.reg.pc = addr
	Emu_Cycles(1)
}

@(private="file")
check_cond :: proc() -> (canJump: bool) {
	#partial switch cpu.currInst.cond {
		case .NONE: return true
		case .C: return get_c_flag(cpu.reg.f)
		case .NC: return !get_c_flag(cpu.reg.f)
		case .Z: return get_z_flag(cpu.reg.f)
		case .NZ: return !get_z_flag(cpu.reg.f)
	}

	return false
}

@(private="file")
get_z_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 7)
}

@(private="file")
get_n_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 6)
}

@(private="file")
get_h_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 5)
}

@(private="file")
get_c_flag :: #force_inline proc(fReg: u8) -> bool {
	return bit(uint(fReg), 4)
}

Stack_Push :: #force_inline proc(data: u8) {
	cpu.reg.sp -= 1
	Bus_Write(cpu.reg.sp, data)
}

Stack_Push16 :: #force_inline proc(data: u16) {
	Stack_Push(u8((data >> 8) & 0xFF))
	Stack_Push(u8(data & 0xFF))
}

Stack_Pop :: proc() -> u8 {
	cpu.reg.sp += 1
	return Bus_Read(cpu.reg.sp - 1)
}

Stack_Pop16 :: proc() -> u16 {
	lo := Stack_Pop()
	hi := Stack_Pop()
	return (u16(hi) << 8) | u16(lo)
}

@(private="file")
is_16bit :: #force_inline proc(type: RegType) -> bool {
	return type >= RegType.AF
}

Timer_Tick :: proc() {
	prevDiv := timer.div
	timer.div += 1

	shouldUpdate := false
	switch timer.tac & 0b11 {
		case 0:
			shouldUpdate = 0 != (prevDiv & (1 << 9)) && 0 == (timer.div & (1 << 9))
		case 1:
			shouldUpdate = 0 != (prevDiv & (1 << 3)) && 0 == (timer.div & (1 << 3))
		case 2:
			shouldUpdate = 0 != (prevDiv & (1 << 5)) && 0 == (timer.div & (1 << 9))
		case 3:
			shouldUpdate = 0 != (prevDiv & (1 << 7)) && 0 == (timer.div & (1 << 9))
	}

	if shouldUpdate && 0 != timer.tac & (1 << 2) {
		timer.tima += 1
		if 0xFF == timer.tima {
			timer.tima = timer.tma
			Interrupt_Request(InterruptType.TIMER)
		}
	}
}

Timer_Write :: proc(addr: u16, val: u8) {
	switch addr {
		case 0xFF04: timer.div = 0
		case 0xFF05: timer.tima = val
		case 0xFF06: timer.tma = val
		case 0xFF07: timer.tac = val
		case:
			no_impl("timer write")
			// exit(1)
	}
}

Timer_Read :: proc(addr: u16) -> u8 {
	switch addr {
		case 0xFF04: return u8(timer.div >> 8)
		case 0xFF05: return timer.tima
		case 0xFF06: return timer.tma
		case 0xFF07: return timer.tac
		case:
			no_impl("timer read")
			return 0
	}
}
