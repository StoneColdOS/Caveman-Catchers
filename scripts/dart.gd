extends Node3D
## A tranq dart. Flies straight, puts the first caveman it hits to sleep.

const Util := preload("res://scripts/util.gd")

const SPEED := 32.0
const MAX_RANGE := 30.0

var direction := Vector3.FORWARD
var travelled := 0.0


func _ready() -> void:
	var body := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.05
	c.height = 0.35
	c.radial_segments = 5
	body.mesh = c
	body.material_override = Util.mat(Color(1.0, 0.85, 0.2), true)
	body.rotation.x = -PI / 2.0  # point along -Z, the way look_at faces
	add_child(body)
	look_at(global_position + direction)


func _physics_process(delta: float) -> void:
	var step := direction * SPEED * delta
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step,
		Util.LAYER_WORLD | Util.LAYER_CAVEMAN)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		if hit.collider.has_method("tranq"):
			hit.collider.tranq()
		_stop()
		return
	global_position += step
	travelled += step.length()
	if travelled > MAX_RANGE:
		queue_free()


func _stop() -> void:
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(queue_free)
