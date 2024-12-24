package gbemu

import "core:os"
import "core:fmt"
import "core:mem"
import "core:thread"

import sdl "vendor:sdl2"

EmuState :: struct {
	isPaused, isRunning, shouldClose: bool,
	ticks: u64,

	endState: bool,
	endMsg: string
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

@(private="file") window: ^sdl.Window
@(private="file") renderer: ^sdl.Renderer
@(private="file") texture: ^sdl.Texture
@(private="file") surface: ^sdl.Surface

Emu_Run :: proc(romPath: string) -> (bool, string) {
	if !load_cartridge(romPath) {
		return false, "Failed to load ROM"
	}

	sdl.Init(sdl.INIT_VIDEO)
	sdl.CreateWindowAndRenderer(1024, 768, sdl.WINDOW_SHOWN, &window, &renderer)

	cpuThread := thread.create_and_start(run_cpu)
	for !emu.shouldClose {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			if sdl.EventType.WINDOWEVENT == e.type && sdl.WindowEventID.CLOSE == e.window.event {
				emu.shouldClose = true
			}
		}
	}

	thread.join(cpuThread)

	return emu.endState, emu.endMsg
}

Emu_Release :: proc() {
	delete(cart.romData)
	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(window)
}

Emu_Cycles :: proc(numCycles: u32) {

}

@(private="file")
run_cpu :: proc() {
	CPU_Init()

	emu.isRunning = true
	for emu.isRunning {
		if emu.isPaused {
			sdl.Delay(16)
			continue
		}

		if !CPU_Step() {
			emu.endState, emu.endMsg = false, "CPU stopped"
			return
		}

		emu.ticks += 1

		if emu.shouldClose {
			emu.endState, emu.endMsg = true, "Closed from interrupt"
			return
		}
	}

	emu.endState, emu.endMsg = true, "Ended successfully"
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
