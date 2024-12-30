package gbemu

import "core:fmt"

main :: proc() {
	ok, msg := Emu_Run("roms/dmg-acid2.gb");
	fmt.printfln("%s: %s", ok ? "SUCCESS" : "ERROR", msg)

	Emu_Release()
}
