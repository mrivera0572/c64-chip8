.include "common.s"

.export build_screen_margins
.export clear_screen
.export draw_sprite
.export init_graphics_tables
.export update_screen_color
.exportzp collision_flag

.import guest_screen_color_origin
.import guest_screen_origin
.import host_screen
.importzp guest_ram_page
.importzp reg_i
.importzp zp0
.importzp zp1
.importzp zp2
.importzp zp3
.importzp zp4
.importzp zp5
.importzp zp6
.importzp zp7

.zeropage

collision_flag:     .res 1
sprite_buffer:      .res 5          ; staging area for drawing a row for a sprite
row_base_ptr:       .res 2          ; physical screen address of row being drawn
sprite_source_ptr:  .res 2          ; physical address of source for sprite bitmap data

.segment "INITCODE"

.proc build_screen_margins
            ;; set character of margins to 15
            store16 zp0, (host_screen + 40 * guest_screen_offset_y)
            lda #16
            sta zp2
            jsr @go
            ;; set color ram of margins to 0
            store16 zp0, (COLOR_RAM + 40 * guest_screen_offset_y)
            lda #chrome_bgcolor
            sta zp2
@go:        ldx #guest_screen_physical_height
@loop:      lda zp2
            ldy #guest_screen_offset_x - 1
@1:         sta (zp0), y
            dey
            bpl @1
            ldy #39
@2:         sta (zp0), y
            dey
            cpy #(guest_screen_physical_width + guest_screen_offset_x)
            bpl @2
            clc
            lda #40
            adc zp0
            sta zp0
            lda #0
            adc zp1
            sta zp1
            dex
            bne @loop
            rts
.endproc

.proc init_graphics_tables
            store16 zp0, guest_screen_origin

            ldx #0
@1:         clc
            lda zp0
            sta screen_row_table_low, x
            adc #40
            sta zp0
            lda zp1
            sta screen_row_table_high, x
            adc #0
            sta zp1
            inx
            cpx #16
            bne @1

            rts
.endproc

.code

.proc clear_screen
            lda #0
            ldy #guest_screen_physical_width - 1
@loop:      .repeat guest_screen_physical_height, i
                sta guest_screen_origin + 40 * i, y
            .endrepeat
            dey
            bpl @loop
            rts
.endproc

.proc update_screen_color
            ldy #guest_screen_physical_width - 1
@loop:      .repeat guest_screen_physical_height, i
                sta guest_screen_color_origin + 40 * i, y
            .endrepeat
            dey
            bpl @loop
            rts
.endproc

.macro top_even
            tax
            lsr a
            lsr a
            lsr a
            lsr a
            and #12
            sta sprite_buffer + 0
            txa
            lsr a
            lsr a
            and #12
            sta sprite_buffer + 1
            txa
            and #12
            sta sprite_buffer + 2
            txa
            asl a
            asl a
            and #12
            sta sprite_buffer + 3
.endmacro

.macro bottom_even
            tax
            rol a
            rol a
            rol a
            and #3
            ora sprite_buffer + 0
            sta sprite_buffer + 0
            txa
            lsr a
            lsr a
            lsr a
            lsr a
            and #3
            ora sprite_buffer + 1
            sta sprite_buffer + 1
            txa
            lsr a
            lsr a
            and #3
            ora sprite_buffer + 2
            sta sprite_buffer + 2
            txa
            and #3
            ora sprite_buffer + 3
            sta sprite_buffer + 3
.endmacro

.macro clear_even
            lda #0
            sta sprite_buffer + 0
            sta sprite_buffer + 1
            sta sprite_buffer + 2
            sta sprite_buffer + 3
.endmacro

.macro clear_odd
            clear_even
            sta sprite_buffer + 4
.endmacro

.macro top_odd
            tax
            rol a
            rol a
            rol a
            rol a
            and #4
            sta sprite_buffer + 0
            txa
            lsr a
            lsr a
            lsr a
            and #12
            sta sprite_buffer + 1
            txa
            lsr a
            and #12
            sta sprite_buffer + 2
            txa
            asl a
            and #12
            sta sprite_buffer + 3
            txa
            asl a
            asl a
            asl a
            and #8
            sta sprite_buffer + 4
.endmacro

.macro bottom_odd
            tax
            rol a
            rol a
            and #1
            ora sprite_buffer + 0
            sta sprite_buffer + 0
            txa
            rol a
            rol a
            rol a
            rol a
            and #3
            ora sprite_buffer + 1
            sta sprite_buffer + 1
            txa
            lsr a
            lsr a
            lsr a
            and #3
            ora sprite_buffer + 2
            sta sprite_buffer + 2
            txa
            lsr a
            and #3
            ora sprite_buffer + 3
            sta sprite_buffer + 3
            txa
            asl a
            and #2
            ora sprite_buffer + 4
            sta sprite_buffer + 4
.endmacro

param_physical_row = zp2
param_right_column = zp3
param_is_bottom_half = zp4
param_rows_left = zp5
param_sprite_width = zp6

;; blit - copies from sprite_buffer to screen
;; Input:
;;
;;   row_base_ptr - physical screen address of column 0 of row
;;   param_right_column - physical column offset of _right-most_  pixel to copy; must be 0 <= y < 32
;;   requires normalized data in sprite_buffer (i.e., only values from $0 - $f)
;; Output:
;;   collision_flag will contain nonzero if collision
.macro blit sprite_width
            .local @loop, @no_collision, @no_wrap, @stash

            ldx #(sprite_width - 1)
            ldy param_right_column
@loop:
            lda (row_base_ptr), y
            sta @stash + 1
            and sprite_buffer, x
            beq @no_collision
            sta collision_flag
@no_collision:
@stash:     lda #0
            eor sprite_buffer, x
            sta (row_base_ptr), y
            dey
            bpl @no_wrap
            ldy #31             ; wrap around to the right side of the screen
@no_wrap:   dex
            bpl @loop
.endmacro

;; sprite_source_ptr:            source data for sprite
;; param_physical_row:           physical row (0 - 15); used as index into screen_row_table
;; param_right_column:           physical column offset of _right-most_  pixel to copy; must be 0 <= y < 32
;; param_is_bottom_half:         zero if drawing top half, non-zero if bottom half
;; param_rows_left:              number of logical rows to draw
.macro make_draw_sprite strategy, sprite_width

@src_ptr = zp7

            lda #0
            sta @src_ptr

            lda param_is_bottom_half
            beq @top_half

@initial_bottom_half:

            .ident(.concat("clear_", strategy))

            jmp @bottom_half

@top_half:
            ldy @src_ptr
            lda (sprite_source_ptr), y
            inc @src_ptr

            .ident(.concat("top_", strategy))

            dec param_rows_left
            beq @no_bottom_half

@bottom_half:
            ldy @src_ptr
            lda (sprite_source_ptr), y
            inc @src_ptr

            .ident(.concat("bottom_", strategy))

            ldy param_physical_row
            lda screen_row_table_low, y
            sta row_base_ptr
            lda screen_row_table_high, y
            sta row_base_ptr + 1
            iny
            tya
            and #15                             ; wrap around to the top
            sta param_physical_row

            blit sprite_width
            dec param_rows_left
            beq @no_rows_left

            jmp @top_half

@no_bottom_half:
            ldy param_physical_row
            lda screen_row_table_low, y
            sta row_base_ptr
            lda screen_row_table_high, y
            sta row_base_ptr + 1
            blit sprite_width

@no_rows_left:
            rts

.endmacro

;; sprite_source_ptr:            source data for sprite
;; param_physical_row:           physical row (0 - 15); used as index into screen_row_table
;; param_right_column:           physical column offset of _right-most_  pixel to copy; must be 0 <= y < 32
;; param_is_bottom_half:         zero if drawing top half, non-zero if bottom half
;; param_rows_left:              number of logical rows to draw
.proc draw_even_sprite
            make_draw_sprite "even", 4
.endproc

.proc draw_odd_sprite
            make_draw_sprite "odd", 5
.endproc

;; X:      X coordinate
;; Y:      Y coordinate
;; A:      height
;; reg_i:  points to sprite
.proc draw_sprite
            sta @stash1 + 1                     ; temporary stash
            lda #0
            sta collision_flag

            ;; X = X % 64
            txa
            and #63
            tax

            ;; Y = Y % 32
            tya
            and #31
            tay

            ;; A = A & 15
@stash1:    lda #0
            and #15

            ;; check A > 0
            beq @invalid    ; 0 height

            ;; param_rows_left = height
            sta param_rows_left

            ;; source_ptr = *reg_i
            lda reg_i
            sta sprite_source_ptr
            lda reg_i + 1
            map_to_host
            sta sprite_source_ptr + 1

            ;; will source_ptr overflow ram?
            cmp #(guest_ram_page + $f)
            bne @source_ptr_ok

            clc
            lda sprite_source_ptr
            adc param_rows_left
            bcc @source_ptr_ok

            ;; if so, height exceeds ram by A bytes
            ;; height -= a
            clc
            sbc param_rows_left
            eor #$ff
            sta param_rows_left

@source_ptr_ok:

            ;; is Y even?
            tya
            and #1
            sta param_is_bottom_half
            tya
            lsr a
            sta param_physical_row

            ;; determine strategy depending on if X is even or odd
            txa
            lsr a
            bcc @x_even
            bcs @x_odd
@invalid:
            rts

@x_odd:
            ;; A contains physical_col 0..31
            adc #3          ; right-most physical column = A + 4  (adding 3 since carry is set)
            and #31         ; wrap
            sta param_right_column

            ;; ready - draw the sprite
            jmp draw_odd_sprite

@x_even:
            ;; A contains physical_col 0..31
            adc #3          ;; right-most physical column = A + 3  (carry is clear)
            and #31         ;; wrap
            sta param_right_column

            ;; ready - draw the sprite
            jmp draw_even_sprite
.endproc

.segment "LOW"

screen_row_table_low:   .res 16
screen_row_table_high:  .res 16
