extends Node3D
## Cámara en perspectiva elevada que sigue al rover (vista del mockup: rover protagonista, estación al fondo).
## Orientación fija por defecto; Q/E giran por pasos de 45°; la rueda acerca o aleja dentro de límites.
const PITCH_DEG := 17.0
const ZOOM_MIN := 9.0
const ZOOM_MAX := 38.0
const ZOOM_DEFAULT := 20.0
const STEP := PI / 4.0

var camera: Camera3D
var enabled := true
var follow: Node3D  ## normalmente el rover
var yaw := deg_to_rad(45.0)  ## mira hacia la estación (noroeste) al empezar
var zoom_target := ZOOM_DEFAULT
var _yaw := yaw
var _distance := ZOOM_DEFAULT
var _focus := Vector3.ZERO


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 40.0
	camera.near = 0.15
	camera.far = 420.0
	add_child(camera)
	camera.current = true
	_apply()


func _process(delta: float) -> void:
	if follow != null and is_instance_valid(follow):
		var objetivo := follow.global_position
		_focus = _focus.lerp(objetivo, 1.0 - exp(-delta * 6.0))
	_yaw = lerp_angle(_yaw, yaw, 1.0 - exp(-delta * 9.0))
	_distance = lerpf(_distance, zoom_target, 1.0 - exp(-delta * 10.0))
	_apply()


func _apply() -> void:
	global_position = _focus
	var pitch := deg_to_rad(PITCH_DEG + (_distance - ZOOM_DEFAULT) * 0.6)
	var offset := Vector3(sin(_yaw) * cos(pitch), sin(pitch), cos(_yaw) * cos(pitch)) * _distance
	camera.global_position = _focus + offset
	camera.look_at(_focus + Vector3(0, 0.9, 0), Vector3.UP)


func center_on(point: Vector3) -> void:
	_focus = point
	_apply()


func _unhandled_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_target = clampf(zoom_target - 1.5, ZOOM_MIN, ZOOM_MAX)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_target = clampf(zoom_target + 1.5, ZOOM_MIN, ZOOM_MAX)
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_Q:
			yaw += STEP
		elif e.physical_keycode == KEY_E:
			yaw -= STEP
