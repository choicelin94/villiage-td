class_name LpcFacing
extends Object

# Walk sheets are 9 columns by 4 rows. Row order matches the LPC walk.png
# files: 0 up (back), 1 left, 2 down (face toward the camera), 3 right.
# Checked on the eye layer: row 0 has no eyes, row 2 has both eyes, row 1
# eyes sit left of center, row 3 eyes sit right of center.
const FRAME := 128
const COLS := 9
const ROWS := 4

static func row_for(vel: Vector2) -> int:
	if absf(vel.x) >= absf(vel.y):
		return 3 if vel.x >= 0.0 else 1
	return 2 if vel.y > 0.0 else 0

static func region(frame: int, row: int) -> Rect2:
	return Rect2(frame * FRAME, row * FRAME, FRAME, FRAME)
