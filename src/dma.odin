package gbemu

import "core:fmt"

DMAState :: struct {
	b, val, startDelay: u8,
	isActive: bool
}

dma: DMAState

DMA_Start :: proc(start: u8) {
	dma.startDelay = 2
	dma.val = start
	dma.b = 0
	dma.isActive = true
}

DMA_Tick :: proc() {
	if !dma.isActive {
		return
	}

	if 0 != dma.startDelay {
		dma.startDelay -= 1
		return
	}

	PPU_OAMWrite(u16(dma.b), Bus_Read(u16(dma.val) * 0x100 + u16(dma.b)))
	dma.b += 1
	dma.isActive = dma.b < 0xA0
}
