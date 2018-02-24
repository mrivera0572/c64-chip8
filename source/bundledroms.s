.include "defines.s"

.export bundle_start

.import connect4_enabled_keys
.import connect4_keymap
.import default_keymap
.import hidden_enabled_keys
.import hidden_keymap
.import tank_enabled_keys
.import tank_keymap
.import tetris_enabled_keys
.import tetris_keymap
.import tictac_enabled_keys
.import tictac_keymap

.macpack cbm

.segment "BUNDLE"

.macro bundle filename, title, enabled_key_mask, keymap_addr, key_repeat
		.local @end
		.word @end
		scrcode title
		.repeat (title_length - .strlen(title))
			.byte 0
		.endrep
		.ifnblank enabled_key_mask
		    .word enabled_key_mask
		.else
		    .word $ffff ; all keys enabled
		.endif
		.ifnblank keymap_addr
		    .addr keymap_addr
		.else
		    .addr default_keymap
		.endif
		.ifnblank key_repeat
		    .byte $ff
        .else
            .byte 0
        .endif

		.incbin filename
@end:
.endmacro

bundle_start:
		bundle "roms/15PUZZLE", "15 puzzle"
		bundle "roms/BLINKY", "blinky"
		bundle "roms/BLITZ", "blitz"
		bundle "roms/BRIX", "brix"
		bundle "roms/CONNECT4", "connect 4", connect4_enabled_keys, connect4_keymap
		bundle "roms/GUESS", "guess"
		bundle "roms/HIDDEN", "hidden", hidden_enabled_keys, hidden_keymap
		bundle "roms/INVADERS", "invaders"
		bundle "roms/KALEID", "kaleid", , , $ff
		bundle "roms/MAZE", "maze"
		bundle "roms/MERLIN", "merlin"
		bundle "roms/MISSILE", "missile"
		bundle "roms/PONG", "pong"
		bundle "roms/PONG2", "pong 2"
		bundle "roms/PUZZLE", "puzzle"
		bundle "roms/SYZYGY", "syzygy"
		bundle "roms/TANK", "tank", tank_enabled_keys, tank_keymap, $ff
		bundle "roms/TETRIS", "tetris", tetris_enabled_keys, tetris_keymap
		bundle "roms/TICTAC", "tictac", tictac_enabled_keys, tictac_keymap
		bundle "roms/UFO", "ufo"
		bundle "roms/VBRIX", "vbrix"
		bundle "roms/VERS", "vers"
		bundle "roms/WIPEOFF", "wipeoff"
