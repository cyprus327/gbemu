package gbemu

import "core:os"
import "core:fmt"
import "core:mem"

import sdl "vendor:sdl2"

EmuState :: struct {
	isPaused, isRunning: bool,
	ticks: u64
}

CartState :: struct {
	filename: string,
	romData: []u8,
	header: ^RomHeader
}

RomHeader :: struct {
	entry: [4]u8,
	logo:  [0x30]u8, // 48

	title: [16]byte, // sizeof(rune) == 4 ????
	newLicenseeCode: u16,
	sgbFlag: u8,
	type: u8,
	romSize: u8,
	ramSize: u8,
	destCode: u8,
	licenseeCode: u8,
	version: u8,
	checksum: u8,
	globalChecksum: u16
}

emu: EmuState
cart: CartState

Emu_Run :: proc(romPath: string) -> (bool, string) {
	if !load_cartridge(romPath) {
		return false, "Failed to load ROM"
	}

	sdl.Init(sdl.INIT_VIDEO)

	CPU_Init()

	emu.isRunning = true
	for emu.isRunning {
		if emu.isPaused {
			sdl.Delay(16)
			continue
		}

		if !CPU_Step() {
			return false, "CPU stopped"
		}

		emu.ticks += 1

		// if emu.ticks >= 30 {
		// 	return true, "Timed out"
		// }
	}

	return true, "Ended successfully"
}

Emu_Cycles :: proc(numCycles: u32) {

}

@(private="file")
load_cartridge :: proc(filename: string) -> bool {
	data: []u8; ok: bool
	if data, ok = os.read_entire_file(filename); !ok {
		return false
	}

	cart.filename = filename

	cart.romData = make([]u8, len(data))
	copy(cart.romData[:], data[:])

	fmt.printfln("Opened: %s, Size: %d", filename, len(data))

	cart.header = cast(^RomHeader)(&cart.romData[0x100])
	cart.header.title[15] = 0

	fmt.printfln("  Cartridge loaded")
	fmt.printfln("  Title    : %s", cart.header.title)
	fmt.printfln("  Type     : %2.2X (%s)", cart.header.type, get_cart_type_name())
	fmt.printfln("  ROM Size : %d KB", int(32 << cart.header.romSize))
	fmt.printfln("  RAM Size : %2.2X", cart.header.ramSize)
	fmt.printfln("  LIC Code : %2.2X (%s)", cart.header.licenseeCode, get_cart_lic_name())
	fmt.printfln("  ROM Vers : %2.2X", cart.header.version)

	x: u16 = 0
	for i := 0x0134; i <= 0x014C; i += 1 {
		x = x - u16(cart.romData[i] - 1)
	}

	fmt.printfln("  Checksum : %2.2X (%s)", cart.header.checksum, (x & 0xFF) != 0 ? "PASS" : "FAIL")

	return true
}

get_cart_type_name :: proc() -> string {
	return "UNIMPLEMENTED"
}

get_cart_lic_name :: proc() -> string {
	return "UNIMPLEMENTED"
}
