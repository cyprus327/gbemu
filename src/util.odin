package gbemu

import "core:os"
import "core:fmt"

bit :: proc(a, n: uint) -> bool {
	return (a & (1 << n)) != 0
}

set_bit :: proc(a, n: uint, on: bool) -> uint {
	return on ? a | (1 << n) : a & ~(1 << n)
}

reverse :: proc(n: u16) -> u16 {
	return ((n & 0xFF00) >> 8) | ((n & 0x00FF) << 8)
}

no_impl :: proc(msg: string) {
	fmt.fprintfln(os.stderr, "NOT IMPLEMENTED: %s", msg)
	// os.exit(1)
}
