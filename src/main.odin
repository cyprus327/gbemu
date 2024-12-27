package gbemu

import "core:fmt"

main :: proc() {
	ok, msg := Emu_Run("roms/11.gb");
	fmt.printfln("%s: %s", ok ? "SUCCESS" : "ERROR", msg)

	Emu_Release()
}
