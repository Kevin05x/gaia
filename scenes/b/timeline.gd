extends Control
var hour=8.0
var windows: Array=[]
func _ready() -> void:custom_minimum_size=Vector2(200,16)
func _draw() -> void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("25353d"))
 draw_rect(Rect2(Vector2(size.x*6/24,0),Vector2(size.x*12/24,size.y)),Color("48504a"))
 for w in windows:
  draw_rect(Rect2(Vector2(size.x*float(w[0])/24,3),Vector2(size.x*(float(w[1])-float(w[0]))/24,size.y-6)),Color("83b7a3"))
 var x=clampf(hour/24*size.x,2,size.x-2)
 draw_line(Vector2(x,0),Vector2(x,size.y),Color("f2debf"),3)
