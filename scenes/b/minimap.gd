extends Control
signal tile_chosen(tile: Vector2i)
var state: Dictionary={}
func _ready() -> void:
 custom_minimum_size=Vector2(210,190);mouse_filter=Control.MOUSE_FILTER_STOP
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("24383d"),true)
 for i in range(1,6):
  draw_line(Vector2(size.x*i/6,0),Vector2(size.x*i/6,size.y),Color("354b4c"))
  draw_line(Vector2(0,size.y*i/6),Vector2(size.x,size.y*i/6),Color("354b4c"))
 for t in state.get("obstacles",[]):draw_rect(Rect2(point(t)-Vector2(3,3),Vector2(6,6)),Color("786d57"))
 for t in state.get("targets",[]):
  if t.get("revealed",false):draw_circle(point(t.tile),3,Color("aacdb2") if not t.get("depleted",false) else Color("6e7772"))
 draw_rect(Rect2(point(state.get("station_tile",Vector2i(3,3)))-Vector2(4,4),Vector2(8,8)),Color("dfae77"))
 draw_circle(point(state.get("rover_tile",Vector2i.ZERO)),5,Color("f1ead6"))
func point(tile: Vector2i) -> Vector2:
 return Vector2((tile.x+11)/22.0*size.x,(tile.y+11)/22.0*size.y)
func _gui_input(e: InputEvent) -> void:
 if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
  tile_chosen.emit(Vector2i(roundi(e.position.x/size.x*22-11),roundi(e.position.y/size.y*22-11)))
  accept_event()
