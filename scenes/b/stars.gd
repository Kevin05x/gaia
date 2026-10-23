extends Control
var stars=0
func _ready() -> void:custom_minimum_size=Vector2(180,48)
func _draw() -> void:
 for j in range(3):
  var points=PackedVector2Array()
  for i in range(10):
   var angle=i*PI/5-PI/2
   points.append(Vector2(24+j*58,24)+Vector2(cos(angle),sin(angle))*(21 if i%2==0 else 9))
  draw_colored_polygon(points,Color("eaa36d") if j<stars else Color("34474b"))
