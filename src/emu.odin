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
	header: ^RomHeader,

	ramEnabled, ramBanking: bool,
	bankingMode: u8,

	romBankVal, ramBankVal: u8,

	ramBanks: [16][1024 * 8]u8,

	hasBattery: bool,
	needsSave: bool
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
scale: i32 = 4

@(private="file")
fileData: []u8

defaultColors := [4]u32{ 0xFFFFFFFF, 0xFFAAAAAA, 0xFF555555, 0xFF000000 }

WINDOW_W :: 1024
WINDOW_H :: 768

Emu_Run :: proc(romPath: string) -> (bool, string) {
	if !cart_load(romPath) {
		return false, "Failed to load ROM"
	}

	ok: bool
	fileData, ok = os.read_entire_file("out/zelda.correct")
	if !ok {
		return false, "Failed to read zelda.correct"
	}

	sdl.Init(sdl.INIT_VIDEO)

	sdl.CreateWindowAndRenderer(WINDOW_W, WINDOW_H, sdl.WINDOW_SHOWN, &window, &renderer)
	surface = sdl.CreateRGBSurface(0, WINDOW_W, WINDOW_H, 32,
		0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
	texture = sdl.CreateTexture(renderer,
		sdl.PixelFormatEnum.ARGB8888, sdl.TextureAccess.STREAMING,
		WINDOW_W, WINDOW_H)

	sdl.CreateWindowAndRenderer(16 * 8 * scale, 32 * 8 * scale, sdl.WINDOW_SHOWN,
		&debugWindow, &debugRenderer)
	debugSurface = sdl.CreateRGBSurface(0,
		16 * 8 * scale + 16 * scale, 32 * 8 * scale + 64 * scale, 32,
		0x00FF0000, 0x0000FF00, 0x000000FF, 0xFF000000)
	debugTexture = sdl.CreateTexture(debugRenderer,
		sdl.PixelFormatEnum.ARGB8888, sdl.TextureAccess.STREAMING,
		16 * 8 * scale + 16 * scale, 32 * 8 * scale + 64 * scale)

	sdl.SetWindowPosition(window, 180, 120)

	x, y: i32 = 0, 0
	sdl.GetWindowPosition(window, &x, &y)
	sdl.SetWindowPosition(debugWindow, x + WINDOW_W + 10, y)

	cpuThread := thread.create_and_start(run_cpu)
	for !emu.shouldClose {
		e: sdl.Event
		for sdl.PollEvent(&e) {
			if sdl.EventType.WINDOWEVENT == e.type && sdl.WindowEventID.CLOSE == e.window.event {
				emu.shouldClose = true
			} else if sdl.EventType.KEYDOWN == e.type {
				Input_HandleKey(true, e.key.keysym.sym)
			} else if sdl.EventType.KEYUP == e.type {
				Input_HandleKey(false, e.key.keysym.sym)
			}
		}

		rect := sdl.Rect{w = scale, h = scale}
		for y = 0; y < RES_Y; y += 1 {
			rect.y = y * scale
			for x = 0; x < RES_X; x += 1 {
				rect.x = x * scale
				sdl.FillRect(surface, &rect, ppu.videoBuf[y * RES_X + x])
			}
		}
		sdl.UpdateTexture(texture, nil, surface.pixels, surface.pitch)
		sdl.RenderClear(renderer)
		sdl.RenderCopy(renderer, texture, nil, nil)
		sdl.RenderPresent(renderer)

		@static prevFrame: u32 = 0
		if prevFrame != ppu.frame {
			update_debug()
		}
		prevFrame = ppu.frame
	}

	thread.join(cpuThread)

	return emu.endState, emu.endMsg
}

Emu_Release :: proc() {
	PPU_Release()
	delete(cart.romData)
	delete(fileData)
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
			PPU_Tick()
		}
		DMA_Tick()
	}
}

@(private="file")
update_debug :: proc() {
	screen := sdl.Rect{x = 0, y = 0, w = debugSurface.w, h = debugSurface.h}
	sdl.FillRect(debugSurface, &screen, 0xFF110000)

	addr: u16 = 0x8000
	xp, yp, tile: i32 = 0, 0, 0

	// 384 tiles
	for y: i32 = 0; y < 24; y += 1 {
		for x: i32 = 0; x < 16; x += 1 {
			rect: sdl.Rect
			xd, yd := xp + x * scale, yp + y * scale
			for ty: i32 = 0; ty < 16; ty += 2 {
				b1 := Bus_Read(addr + u16(tile * 16 + ty))
				b2 := Bus_Read(addr + u16(tile * 16 + ty) + 1)
				for bit: i8 = 7; bit >= 0; bit -= 1 {
					hi := u8(0 != b1 & (1 << u8(bit))) << 1
					lo := u8(0 != b2 & (1 << u8(bit)))
					rect.x = xd + i32(7 - bit) * scale
					rect.y = yd + ty / 2 * scale
					rect.w = scale
					rect.h = scale
					sdl.FillRect(debugSurface, &rect, defaultColors[hi | lo])
				}
			}
			xp += 8 * scale
			tile += 1
		}
		yp += 8 * scale
		xp = 0
	}

	sdl.UpdateTexture(debugTexture, nil, debugSurface.pixels, debugSurface.pitch)
	sdl.RenderClear(debugRenderer)
	sdl.RenderCopy(debugRenderer, debugTexture, nil, nil)
	sdl.RenderPresent(debugRenderer)
}

@(private="file")
check_err :: proc(orig: rawptr, n: int, ptr: uint) -> bool {
	data := &fileData[ptr]
	return 0 != mem.compare_ptrs(orig, data, n)
}

@(private="file")
run_cpu :: proc() {
	CPU_Init()
	PPU_Init()

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

when CPU_DEBUG {
		@static ptr: uint = 0
		hadErr := false

		if check_err(&cpu.reg, size_of(CPURegisters), ptr) {
			hadErr = true
			fmt.println("REGISTERS:\n\t", cpu.reg, "\n\t", (cast(^CPURegisters)&fileData[ptr])^)
		}
		ptr += size_of(CPURegisters)

		if check_err(&cpu.fetchedData, size_of(u16), ptr) {
			hadErr = true
			fmt.println("FETCHED DATA:", cpu.fetchedData, (cast(^u16)&fileData[ptr])^)
		}
		ptr += size_of(u16)

		if check_err(&cpu.memDest, size_of(u16), ptr) {
			hadErr = true
			fmt.println("MEM DEST:", cpu.memDest, (cast(^u16)&fileData[ptr])^)
		}
		ptr += size_of(u16)

		if check_err(&cpu.currOp, size_of(u8), ptr) {
			hadErr = true
			fmt.println("CURR OP:", cpu.currOp, (cast(^u8)&fileData[ptr])^)
		}
		ptr += size_of(u8)

		regVals := [3]u16{
			Bus_Read16(read_reg(.BC)),
			Bus_Read16(read_reg(.DE)),
			Bus_Read16(read_reg(.HL))}
		if check_err(&regVals, size_of(regVals), ptr) {
			hadErr = true
			fmt.println("REG VALS:", regVals, (cast(^([3]u16))&fileData[ptr])^)
		}
		ptr += size_of(regVals)

		if hadErr {
			read_pause(fmt.aprintf(""))
		}
}

		if emu.shouldClose {
			emu.endState, emu.endMsg = true, "Closed from interrupt"
			return
		}
	}

	emu.endState, emu.endMsg = true, "Ended successfully"
}

@(private="file")
cart_load :: proc(filename: string) -> bool {
	ok: bool
	if cart.romData, ok = os.read_entire_file(filename); !ok {
		return false
	}

	// ok: bool
	// if cart.romData, ok = os.read_entire_file("out/zelda.asdf"); !ok {
	// 	return false
	// }

	cart.filename = filename

	fmt.printfln("Opened: %s, Size: %d", filename, len(cart.romData))

	cart.header = cast(^RomHeader)(&cart.romData[0x100])

	fmt.printfln("  Cartridge loaded")
	fmt.printfln("  Title    : %s", cart.header.title)
	fmt.printfln("  Type     : %2.2X (%s)", cart.header.type, "UNIMPLEMENTED")
	fmt.printfln("  ROM Size : %d KB", int(32 << cart.header.romSize))
	fmt.printfln("  RAM Size : %2.2X", cart.header.ramSize)
	fmt.printfln("  LIC Code : %2.2X (%s)", cart.header.licenseeCode, "UNIMPLEMENTED")
	fmt.printfln("  ROM Vers : %2.2X", cart.header.version)

	x: u16 = 0
	for i := 0x0134; i <= 0x014C; i += 1 {
		x -= u16(cart.romData[i] - 1)
	}

	fmt.printfln("  Checksum : %2.2X (%s)", cart.header.checksum, (x & 0xFF) != 0 ? "PASS" : "FAIL")

	cart.ramBankVal = 0
	cart.romBankVal = 1

	cart.hasBattery = 3 == cart.header.type
	if cart.hasBattery {
		cart_load_battery()
	}

	return true
}

cart_is_mbc1 :: #force_inline proc() -> bool {
	return cart.header.type >= 1 && cart.header.type <= 3
}

cart_save_battery :: proc() {

}

cart_load_battery :: proc() {

}
