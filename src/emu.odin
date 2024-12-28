package gbemu

import "core:os"
import "core:io"
import "core:fmt"
import "core:mem"
import "core:bufio"
import "core:thread"
import "core:strings"
import "core:c/libc"

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
@(private="file") debugWindow: ^sdl.Window
@(private="file") debugRenderer: ^sdl.Renderer
@(private="file") debugTexture: ^sdl.Texture
@(private="file") debugSurface: ^sdl.Surface

@(private="file") @rodata
debugScale: i32 = 4

@(private="file") @rodata
tileColors := []u32{0xFFFFFFFF, 0xFFAAAAAA, 0xFF555555, 0xFF000000}

Emu_Run :: proc(romPath: string) -> (bool, string) {
	if !load_cartridge(romPath) {
		return false, "Failed to load ROM"
	}

	sdl.Init(sdl.INIT_VIDEO)

	sdl.CreateWindowAndRenderer(1024, 768, sdl.WINDOW_SHOWN, &window, &renderer)

	sdl.CreateWindowAndRenderer(16 * 8 * debugScale, 32 * 8 * debugScale, sdl.WINDOW_SHOWN, &debugWindow, &debugRenderer)
	debugSurface = sdl.CreateRGBSurface(0, 16 * 8 * debugScale + 16 * debugScale, 32 * 8 * debugScale + 64 * debugScale, 32,
		0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
	debugTexture = sdl.CreateTexture(debugRenderer, sdl.PixelFormatEnum.ARGB8888, sdl.TextureAccess.STREAMING,
		16 * 8 * debugScale + 16 * debugScale, 32 * 8 * debugScale + 64 * debugScale)

	sdl.SetWindowPosition(window, 180, 120)

	x, y: i32 = 0, 0
	sdl.GetWindowPosition(window, &x, &y)
	sdl.SetWindowPosition(debugWindow, x + 1034, y)

	cpuThread := thread.create_and_start(run_cpu)
	for !emu.shouldClose {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			if sdl.EventType.WINDOWEVENT == e.type && sdl.WindowEventID.CLOSE == e.window.event {
				emu.shouldClose = true
			}
		}

		update_debug()
	}

	thread.join(cpuThread)

	return emu.endState, emu.endMsg
}

Emu_Release :: proc() {
	delete(cart.romData)
	delete(cOutData)
	sdl.FreeSurface(debugSurface)
	sdl.FreeSurface(surface)
	sdl.DestroyTexture(debugTexture)
	sdl.DestroyTexture(texture)
	sdl.DestroyRenderer(debugRenderer)
	sdl.DestroyRenderer(renderer)
	sdl.DestroyWindow(debugWindow)
	sdl.DestroyWindow(window)
}

Emu_Cycles :: proc(numCycles: u32) {
	for cycle in 0..<numCycles {
		for i in 0..<4 {
			emu.ticks += 1
			Timer_Tick()
		}
		DMA_Tick()
	}
}

@(private="file")
update_debug :: proc() {
	screen := sdl.Rect{x = 0, y = 0, w = debugSurface.w, h = debugSurface.h}
	sdl.FillRect(debugSurface, &screen, 0xFF111111)

	addr: u16 = 0x8000
	xp, yp, tile: i32 = 0, 0, 0

	// 384 tiles
	for y: i32 = 0; y < 24; y += 1 {
		for x: i32 = 0; x < 16; x += 1 {
			rect: sdl.Rect
			xd, yd := xp + x * debugScale, yp + y * debugScale
			for ty: i32 = 0; ty < 16; ty += 2 {
				b1 := Bus_Read(addr + u16(tile * 16 + ty))
				b2 := Bus_Read(addr + u16(tile * 16 + ty) + 1)
				for bit: i8 = 7; bit >= 0; bit -= 1 {
					hi := u8(0 != b1 & (1 << u8(bit))) << 1
					lo := u8(0 != b2 & (1 << u8(bit)))
					rect.x = xd + i32(7 - bit) * debugScale
					rect.y = yd + ty / 2 * debugScale
					rect.w = debugScale
					rect.h = debugScale
					sdl.FillRect(debugSurface, &rect, tileColors[hi | lo])
				}
			}
			xp += 8 * debugScale
			tile += 1
		}
		yp += 8 * debugScale
		xp = 0
	}

	sdl.UpdateTexture(debugTexture, nil, debugSurface.pixels, debugSurface.pitch)
	sdl.RenderClear(debugRenderer)
	sdl.RenderCopy(debugRenderer, debugTexture, nil, nil)
	sdl.RenderPresent(debugRenderer)
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

		// if emu.ticks >= 0xA4492 {
		// 	emu.shouldClose = true
		// }

		if emu.shouldClose {
			emu.endState, emu.endMsg = true, "Closed from interrupt"
			return
		}
	}

	emu.endState, emu.endMsg = true, "Ended successfully"
}

@(private="file")
load_cartridge :: proc(filename: string) -> bool {
	ok: bool
	if cart.romData, ok = os.read_entire_file(filename); !ok {
		return false
	}

	// handle, err := os.open(filename)
	// if os.ERROR_NONE != err {
	// 	fmt.println("FAILED OPENING")
	// 	return false
	// }
	// defer os.close(handle)

	// size := int(os.file_size_from_path(filename))
	// cart.romData = make([]u8, size)

	// size, err = os.read_full(handle, cart.romData)
	// if os.ERROR_NONE != err {
	// 	fmt.println("FAILED READ_FULL")
	// 	return false
	// }

	// fmt.println("Read:", size)

	// file := libc.fopen(strings.clone_to_cstring(filename), "rb")
	// if nil == file {
	// 	fmt.println("FAILED FOPEN")
	// 	return false
	// }

	// libc.fseek(file, 0, libc.Whence.END)
	// size := libc.ftell(file)

	// libc.rewind(file)

	// cart.romData = make([]u8, size)
	// libc.fread(raw_data(cart.romData), libc.size_t(size), 1, file)
	// libc.fclose(file)

	// data, ok := os.read_entire_file("out/romData.asdf")
	// if !ok {
	// 	fmt.println("FAILED READING")
	// 	os.exit(1)
	// }
	// defer delete(data)

	// for b, i in data {
	// 	if b != cart.romData[i] {
	// 		read_pause(fmt.aprintf("%d) %02X %02X", i, b, cart.romData[i]))
	// 	}
	// }

	// ok: bool
	// cart.romData, ok = os.read_entire_file("out/romData.asdf")
	// if !ok {
	// 	fmt.println("FAILED TO READ")
	// 	return false
	// }

	cart.filename = filename

	fmt.printfln("Opened: %s, Size: %d", filename, len(cart.romData))

	cart.header = cast(^RomHeader)(&cart.romData[0x100])

	fmt.printfln("  Cartridge loaded")
	fmt.printfln("  Title    : %s", cart.header.title)
	fmt.printfln("  Type     : %2.2X (%s)", cart.header.type, get_cart_type_name())
	fmt.printfln("  ROM Size : %d KB", int(32 << cart.header.romSize))
	fmt.printfln("  RAM Size : %2.2X", cart.header.ramSize)
	fmt.printfln("  LIC Code : %2.2X (%s)", cart.header.licenseeCode, get_cart_lic_name())
	fmt.printfln("  ROM Vers : %2.2X", cart.header.version)

	x: u16 = 0
	for i := 0x0134; i <= 0x014C; i += 1 {
		x -= u16(cart.romData[i] - 1)
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
