package gbemu

import "core:fmt"
import "core:strings"

AddrMode :: enum {
    IMP,
    R_D16,
    R_R,
    MR_R,
    R,
    R_D8,
    R_MR,
    R_HLI,
    R_HLD,
    HLI_R,
    HLD_R,
    R_A8,
    A8_R,
    HL_SPR,
    D16,
    D8,
    D16_R,
    MR_D8,
    MR,
    A16_R,
    R_A16
}

RegType :: enum {
	NONE,
	A, F, B, C, D, E, H, L,
    AF, BC, DE, HL,
    SP, PC
}

InstType :: enum {
	NONE,
    NOP,
    LD,
    INC,
    DEC,
    RLCA,
    ADD,
    RRCA,
    STOP,
    RLA,
    JR,
    RRA,
    DAA,
    CPL,
    SCF,
    CCF,
    HALT,
    ADC,
    SUB,
    SBC,
    AND,
    XOR,
    OR,
    CP,
    POP,
    JP,
    PUSH,
    RET,
    CB,
    CALL,
    RETI,
    LDH,
    JPHL,
    DI,
    EI,
    RST,
    ERR,
    RLC,
    RRC,
    RL,
    RR,
    SLA,
    SRA,
    SWAP,
    SRL,
    BIT,
    RES,
    SET
}

CondType :: enum {
	NONE, NZ, Z, NC, C
}

Instruction :: struct {
	type: InstType,
	mode: AddrMode,
	reg1, reg2: RegType,
	cond: CondType,
	param: u8
}

instructions: [0x100]Instruction

Inst_ToString :: proc(inst: Instruction) -> string {
	n := fmt.aprintf("%s", inst.type)
	switch inst.mode {
		case .IMP:
			return n
		case .R_D16: fallthrough
		case .R_A16:
			return fmt.aprintf("%s %s, $%04X", n, inst.reg1, cpu.fetchedData)
		case .R:
			return fmt.aprintf("%s %s", n, inst.reg1)
		case .R_R:
			return fmt.aprintf("%s %s, %s", n, inst.reg1, inst.reg2)
		case .MR_R:
			return fmt.aprintf("%s (%s)%s", n, inst.reg1, inst.reg2)
		case .MR:
			return fmt.aprintf("%s (%s)", n, inst.reg1)
		case .R_MR:
			return fmt.aprintf("%s %s(%s)", n, inst.reg1, inst.reg2)
		case .R_D8: fallthrough
		case .R_A8:
			return fmt.aprintf("%s %s, $%02X", n, inst.reg1, cpu.fetchedData & 0xFF)
		case .R_HLI:
			return fmt.aprintf("%s %s(%s+)", n, inst.reg1, inst.reg2)
		case .R_HLD:
			return fmt.aprintf("%s %s(%s-)", n, inst.reg1, inst.reg2)
		case .HLI_R:
			return fmt.aprintf("%s (%s+)%s", n, inst.reg1, inst.reg2)
		case .HLD_R:
			return fmt.aprintf("%s (%s-)%s", n, inst.reg1, inst.reg2)
		case .A8_R:
			return fmt.aprintf("%s $%02X, %s", n, Bus_Read(cpu.reg.pc - 1), inst.reg2)
		case .HL_SPR:
			return fmt.aprintf("%s (%s), SP+%d", n, inst.reg1, cpu.fetchedData & 0xFF)
		case .D8:
			return fmt.aprintf("%s $%02X", n, cpu.fetchedData & 0xFF)
		case .D16:
			return fmt.aprintf("%s $%04X", n, cpu.fetchedData)
		case .MR_D8:
			return fmt.aprintf("%s (%s)$%02X", n, inst.reg1, cpu.fetchedData & 0xFF)
		case .D16_R: fallthrough
		case .A16_R:
			return fmt.aprintf("%s $%04X, %s", n, cpu.fetchedData, inst.reg2)
	}
	return "INVALID INSTRUCTION (UNKNOWN MODE)"
}
