package gbemu

import "core:fmt"
import "core:mem"

import sdl "vendor:sdl2"

LINES_PER_FRAME :: 154
TICKS_PER_LINE :: 456
RES_X :: 160
RES_Y :: 144

OAMEntry :: struct {
	y, x, tileInd, flags: u8,
}

PPUState :: struct {
	oamRam: [40]OAMEntry,
	vram: [0x2000]u8,

	lineSprites: [dynamic]OAMEntry,
	fetchedEntries: [3]OAMEntry,
	fetchedEntriesCount: u8,

	windowLine: u8,

	frame, lineTicks: u32,
	videoBuf: [RES_X * RES_Y]u32
}

FetchState :: enum {
	TILE, DATA0, DATA1, IDLE, PUSH
}

PixelQueueState :: struct {
	fetchState: FetchState,
	pixelQueue: [dynamic]u32,
	lineX, pushedX, fetchX: u8,
	bgwFetchData: [3]u8,
	fetchEntryData: [6]u8,
	mapY, mapX, tileY, queueX: u8
}

ppu: PPUState

@(private="file")
queue: PixelQueueState

PPU_Init :: proc() {
	ppu.lineSprites = make([dynamic]OAMEntry)
	queue.pixelQueue = make([dynamic]u32)

	LCD_Init()
	LCD_SetMode(.OAM)
}

PPU_Release :: proc() {
	delete(ppu.lineSprites)
	delete(queue.pixelQueue)
}

PPU_Tick :: proc() {
	ppu.lineTicks += 1
	switch LCD_GetMode() {
		case .OAM: {
			if ppu.lineTicks >= 80 {
				LCD_SetMode(.TRANSFER)
				queue.fetchState = .TILE
				queue.lineX = 0
				queue.fetchX = 0
				queue.pushedX = 0
				queue.queueX = 0
			}

			if ppu.lineTicks != 1 {
				break
			}

			clear(&ppu.lineSprites)

			height := LCD_ObjHeight()
			for e in ppu.oamRam {
				if len(ppu.lineSprites) >= 10 {
					break
				}

				if 0 == e.x {
					continue
				}

				if e.y > lcd.yCoord + 16 || e.y + height <= lcd.yCoord + 16 {
					continue
				}

				if len(ppu.lineSprites) == 0 || ppu.lineSprites[len(ppu.lineSprites) - 1].x > e.x {
					append(&ppu.lineSprites, e)
				} else {
					for s, i in ppu.lineSprites {
						if s.x > e.x {
							// inject_at(&ppu.lineSprites, i, e)
							append(&ppu.lineSprites, e)
							break
						}
						if len(ppu.lineSprites) - 1 == i {
							append(&ppu.lineSprites, e)
							break
						}
					}
				}

				// inject doesn't work ?
				for i := 0; i < len(ppu.lineSprites) - 1; i += 1 {
					for j := i + 1; j < len(ppu.lineSprites); j += 1 {
						if ppu.lineSprites[i].x > ppu.lineSprites[j].x {
							ppu.lineSprites[i], ppu.lineSprites[j] =
								ppu.lineSprites[j], ppu.lineSprites[i]
						}
					}
				}
			}
		}
		case .TRANSFER: {
			pipeline_process()

			if queue.pushedX < RES_X {
				break
			}

			clear(&queue.pixelQueue)

			LCD_SetMode(.HBLANK)

			if 0 != LCD_StatInt(.HBLANK) {
				Interrupt_Request(.LCD_STAT)
			}
		}
		case .VBLANK: {
			if ppu.lineTicks < TICKS_PER_LINE {
				break
			}

			inc_yc()

			if lcd.yCoord >= LINES_PER_FRAME {
				LCD_SetMode(.OAM)
				lcd.yCoord = 0
				ppu.windowLine = 0
			}

			ppu.lineTicks = 0
		}
		case .HBLANK: {
			if ppu.lineTicks < TICKS_PER_LINE {
				break
			}

			inc_yc()

			if lcd.yCoord < RES_Y {
				LCD_SetMode(.OAM)
				ppu.lineTicks = 0
				break
			}

			LCD_SetMode(.VBLANK)

			Interrupt_Request(.VBLANK)

			if 0 != LCD_StatInt(.VBLANK) {
				Interrupt_Request(.LCD_STAT)
			}

			ppu.frame += 1
			ppu.lineTicks = 0

			@static @rodata targetDelta: u32 = 1000 / 59
			@static prevDelta: u32 = 0
			@static frameCount: u32 = 0
			@static start: u32 = 0

			end := sdl.GetTicks()
			delta := end - prevDelta

			if delta < targetDelta {
				sdl.Delay(targetDelta - delta)
			}

			if end - start > 1000 {
				fmt.printfln("FPS: %d", frameCount)
				start = end
				frameCount = 0
			}

			frameCount += 1
			prevDelta = sdl.GetTicks()
		}
	}
}

@(private="file")
pipeline_process :: proc() {
	queue.mapY = lcd.yCoord + lcd.scrollY
	queue.mapX = queue.fetchX + lcd.scrollX
	queue.tileY = (queue.mapY % 8) * 2

	if 0 == ppu.lineTicks & 1 {
		switch queue.fetchState {
			case .TILE: {
				ppu.fetchedEntriesCount = 0

				if 0 != LCD_BgwEnable() {
					a := u16(LCD_BgMapArea()) + u16(queue.mapX / 8) + u16(queue.mapY / 8) * 32
					queue.bgwFetchData[0] = Bus_Read(a)

					if 0x8800 == LCD_BgwDataArea() {
						queue.bgwFetchData[0] += 128
					}

					// load window tile
					if is_window_visible() &&
							queue.fetchX + 7 >= lcd.winX &&
							queue.fetchX < lcd.winX + RES_Y + 7 &&
							lcd.yCoord >= lcd.winY &&
							lcd.yCoord < lcd.winY + RES_X {
						tileY := ppu.windowLine / 8
						a = LCD_WinMapArea() + (u16(queue.fetchX) + 7 - u16(lcd.winX)) / 8 + u16(tileY) * 32
						queue.bgwFetchData[0] = Bus_Read(a)
						if 0x8800 == LCD_BgwDataArea() {
							queue.bgwFetchData[0] += 128
						}
					}
				}

				if 0 != LCD_ObjEnable() && len(ppu.lineSprites) > 0 {
					// load sprites
					for e in ppu.lineSprites {
						x := e.x - 8 + (lcd.scrollX % 8)
						if ((x >= queue.fetchX && x < queue.fetchX + 8) ||
							 (x + 8 >= queue.fetchX && x + 8 < queue.fetchX + 8)) {
							ppu.fetchedEntries[ppu.fetchedEntriesCount] = e
							ppu.fetchedEntriesCount += 1
						}

						if ppu.fetchedEntriesCount >= 3 {
							break
						}
					}
				}

				queue.fetchState = .DATA0
				queue.fetchX += 8
			}
			case .DATA0: {
				a := LCD_BgwDataArea() + u16(queue.bgwFetchData[0]) * 16 + u16(queue.tileY)
				queue.bgwFetchData[1] = Bus_Read(a)

				load_sprite_data(0)

				queue.fetchState = .DATA1
			}
			case .DATA1: {
				a := LCD_BgwDataArea() + u16(queue.bgwFetchData[0]) * 16 + u16(queue.tileY) + 1
				queue.bgwFetchData[2] = Bus_Read(a)

				load_sprite_data(1)

				queue.fetchState = .IDLE
			}
			case .IDLE: {
				queue.fetchState = .PUSH
			}
			case .PUSH: {
				if queue_add() {
					queue.fetchState = .TILE
				}
			}
		}
	}

	if len(queue.pixelQueue) <= 8 {
		return
	}

	data := pop_front(&queue.pixelQueue)
	if queue.lineX >= lcd.scrollX % 8 {
		ppu.videoBuf[u32(lcd.yCoord) * RES_X + u32(queue.pushedX)] = data
		queue.pushedX += 1
	}
	queue.lineX += 1
}

@(private="file")
load_sprite_data :: proc(mode: u8) {
	height := LCD_ObjHeight()
	for i in 0..<ppu.fetchedEntriesCount {
		tileY := 2 * (lcd.yCoord + 16 - ppu.fetchedEntries[i].y)
		if 0 != get_flag_yflip(ppu.fetchedEntries[i]) {
			tileY = height * 2 - 2 - tileY
		}

		tileInd := ppu.fetchedEntries[i].tileInd
		if 16 == height {
			tileInd &= 0b11111110
		}

		addr := 0x8000 + u16(tileInd) * 16 + u16(tileY) + u16(mode)
		queue.fetchEntryData[i * 2 + mode] = Bus_Read(addr)
	}
}

@(private="file")
queue_add :: proc() -> bool {
	if len(queue.pixelQueue) > 8 {
		return false
	}

	if i32(queue.fetchX) - (8 - i32(lcd.scrollX % 8)) < 0 {
		return true
	}

	for i in 0..<8 {
		bit := 7 - u8(i)
		hi := u8(0 != queue.bgwFetchData[2] & (1 << bit)) << 1
		lo := u8(0 != queue.bgwFetchData[1] & (1 << bit))
		bgColor := hi | lo

		col := 0 != LCD_BgwEnable() ? bgColors[hi | lo] : bgColors[0]

		if 0 != LCD_ObjEnable() {
			for e: u8 = 0; e < ppu.fetchedEntriesCount; e += 1 {
				x := ppu.fetchedEntries[e].x - 8 + (lcd.scrollX % 8)
				if x + 8 < queue.queueX {
					continue
				}

				offset := queue.queueX - x
				if offset > 7 {
					continue
				}

				bit := 0 != get_flag_xflip(ppu.fetchedEntries[e]) ? offset : 7 - offset

				lo = 0 != queue.fetchEntryData[e * 2] & (1 << bit)
				hi = u8(0 != queue.fetchEntryData[e * 2 + 1] & (1 << bit)) << 1

				if 0 == hi | lo {
					continue // transparent
				}

				if 0 == get_flag_bgp(ppu.fetchedEntries[e]) || 0 == bgColor {
					pn := 0 != get_flag_palette_num(ppu.fetchedEntries[e])
					col = pn ? sp2Colors[hi | lo] : sp1Colors[hi | lo]
					if 0 != hi | lo {
						break
					}
				}
			}
		}

		append(&queue.pixelQueue, col)
		queue.queueX += 1
	}

	return true
}

@(private="file")
inc_yc :: proc() {
	if is_window_visible() && lcd.yCoord >= lcd.winY && lcd.yCoord < lcd.winY + RES_Y {
		ppu.windowLine += 1
	}

	lcd.yCoord += 1

	if lcd.yCoord != lcd.yCmp {
		LCD_SetYC(false)
		return
	}

	LCD_SetYC(true)
	if 0 != LCD_StatInt(.LYC) {
		Interrupt_Request(.LCD_STAT)
	}
}

@(private="file")
is_window_visible :: #force_inline proc() -> bool {
	return 0 != LCD_WinEnable() && lcd.winX <= 166 && lcd.winY < RES_Y
}

PPU_OAMWrite :: proc(addr: u16, val: u8) {
	addr := addr
	if addr >= 0xFE00 {
		addr -= 0xFE00
	}
	bytes := mem.any_to_bytes(ppu.oamRam)
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
