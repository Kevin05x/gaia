extends Node3D
var camera: Camera3D
var enabled=true
var dragging=false
var focus_point=Vector3.ZERO
var zoom_target=27.0
func _ready() -> void:
 rotation_degrees.y=45
 camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL
 camera.size=zoom_target;camera.position=Vector3(0,24,24);camera.far=180
 add_child(camera);camera.look_at(global_position);camera.current=true
func _process(delta: float) -> void:
 camera.size=lerpf(camera.size,zoom_target,minf(1,delta*10))
 if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT): dragging=false
func center_on(point: Vector3) -> void:
 position=Vector3(point.x,0,point.z)
func _unhandled_input(e: InputEvent) -> void:
 if not enabled:return
 if e is InputEventMouseButton:
  if e.button_index==MOUSE_BUTTON_RIGHT:dragging=e.pressed
  if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_UP:zoom_target=clampf(zoom_target-2,13,45)
  if e.pressed and e.button_index==MOUSE_BUTTON_WHEEL_DOWN:zoom_target=clampf(zoom_target+2,13,45)
 if e is InputEventMouseMotion and dragging:
  var right=global_basis.x;var back=Vector3(-right.z,0,right.x)
  position+=(-right*e.relative.x-back*e.relative.y)*camera.size/800
  position.x=clampf(position.x,-16,16);position.z=clampf(position.z,-16,16)
 if e is InputEventKey and e.pressed and not e.echo:
  if e.physical_keycode==KEY_Q:rotate_y(PI/8)
  if e.physical_keycode==KEY_E:rotate_y(-PI/8)
