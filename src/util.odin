package gbemu

import "core:os"
import "core:fmt"

bit :: #force_inline proc(a, n: uint) -> bool {
	return (a & (1 << n)) != 0
}

set_bit :: #force_inline proc(a, n: uint, on: bool) -> uint {
	return on ? a | (1 << n) : a & ~(1 << n)
}

reverse :: #force_inline proc(n: u16) -> u16 {
	return ((n & 0xFF00) >> 8) | ((n & 0x00FF) << 8)
}

no_impl :: #force_inline proc(msg: string) {
	fmt.fprintfln(os.stderr, "NOT IMPLEMENTED: %s", msg)
	// os.exit(1)
}

read_pause :: proc(msg: string) {
	fmt.print(msg)
	buf: [32]u8
	os.read(os.stdin, buf[:])
	if 'q' == buf[0] {
		os.exit(0)
	}
}
