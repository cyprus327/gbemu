package gbemu

import sdl "vendor:sdl2"

GamepadState :: struct {
	start, select, a, b, up, down, left, right: bool,
	buttonSelect, dirSelect: bool
}

input: GamepadState

Input_HandleKey :: proc(down: bool, key: sdl.Keycode) {
	#partial switch key {
		case .N: input.a = down
		case .M: input.b = down
		case .RETURN: input.start = down
		case .SPACE: input.select = down
		case .W: input.up = down
		case .S: input.down = down
		case .A: input.left = down
		case .D: input.right = down
	}
}

Input_SetSelect :: proc(val: u8) {
	input.buttonSelect = 0 != val & 0x20
	input.dirSelect = 0 != val & 0x10
}

Input_GetOutput :: proc() -> u8 {
	output: u8 = 0xCF
	if !input.buttonSelect { // 0 == select
		if input.start {
			output &= 0b11110111
		}
		if input.select {
			output &= 0b11111011
		}
		if input.a {
			output &= 0b11111110
		}
		if input.b {
			output &= 0b11111101
		}
	}
	if !input.dirSelect {
		if input.right {
			output &= 0b11111110
		}
		if input.left {
			output &= 0b11111101
		}
		if input.up {
			output &= 0b11111011
		}
		if input.down {
			output &= 0b11110111
		}
	}
	return output
}
