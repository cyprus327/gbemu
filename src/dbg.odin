package gbemu

import "core:os"
import "core:fmt"

@(private="file")
msg: string = ""

// for blargg tests

Debug_Update :: proc() -> bool {
	if 0x81 == Bus_Read(0xFF02) {
		c := Bus_Read(0xFF01)
		msg = fmt.aprintf("%s'%c'", msg, c)
		Bus_Write(0xFF02, 0)

		return true
		// fmt.printfln("D: %02X, %02X, %s, '%c'", Bus_Read(0xFF01), Bus_Read(0xFF02), msg, c)

		// buf: [8]u8
		// os.read(os.stdin, buf[:])
	}
	return false
}

Debug_Print :: proc() {
	if 0 != len(msg) {
		fmt.printfln("DEBUG: %s", msg)
	}
}
