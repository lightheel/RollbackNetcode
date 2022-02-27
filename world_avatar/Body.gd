extends Sprite


func _ready():
	pass

# ******************************************************************************

var direction := 0 setget set_direction
func set_direction(dir):
	direction = dir
	frame_coords.y = direction

var playing := false
var walking := false
var gliding := false
var speed_scale := 0.0

var limiter = RateLimiter.new(.1)

func _physics_process(delta):
	if walking:
		if !limiter.check_time(delta):
			return

		var frame = frame_coords.x

		frame += 1
		if frame >= 6:
			frame = 0

		frame_coords.x = frame
		return

	if gliding:
		frame_coords.x = 0
		return

	frame_coords.x = 6
