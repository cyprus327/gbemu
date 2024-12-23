package gbemu

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:strings"

main :: proc() {
	ok, msg := Emu_Run("roms/tetris.gb");
	fmt.println(msg)

	delete(cart.romData)
}
