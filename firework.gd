extends Node2D

var alive = false
var viewport_size
var start_point
var end_point
var propagation_vec

var cur_step = 0
const STEPS = 20

func _ready():
	$InitTimer.wait_time = rand_range(0, 2)
	$InitTimer.start()

func init():
	randomize()
	viewport_size = get_viewport_rect().size
	start_point = Vector2(rand_range(0, 1) * viewport_size.x, viewport_size.y)
	end_point = Vector2(rand_range(0.2, 0.8) * viewport_size.x, rand_range(0.3, 0.7) * viewport_size.y)
	propagation_vec = (end_point - start_point) / STEPS
	position = start_point
	cur_step = 0
	$Trail.visible = true
	$Trail.emitting = true
	$Trail.restart()
	$Explosion.visible = false
	$Explosion.emitting = false
	alive = true

func _process(delta):
	if not alive:
		return
	position = position + propagation_vec
	cur_step = cur_step + 1
	if cur_step >= STEPS:
		explode()
		$CreationTimer.start()

func explode():
	alive = false
	$Trail.emitting = false
	$Trail.visible = false
	$Explosion.visible = true
	$Explosion.emitting = true
	$Explosion.restart()

func _on_CreationTimer_timeout():
	init()

func _on_InitTimer_timeout():
	init()
