extends Node3D
const Art=preload("res://scenes/b/art.gd")
const LIMIT=11
var targets: Dictionary={}
var selected=""
var selection: MeshInstance3D
var route_line: MeshInstance3D
var obstacles: Array[Vector2i]=[]
var grid: Node3D
func height_at(x: float,z: float) -> float:
 return sin(x*.17)*cos(z*.13)*.18
func _ready() -> void:
 var rng=RandomNumberGenerator.new();rng.seed=20261023
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for x in range(-28,28,2):
  for z in range(-28,28,2):
   var a=Vector3(x,height_at(x,z),z);var b=Vector3(x+2,height_at(x+2,z),z)
   var c=Vector3(x,height_at(x,z+2),z+2);var d=Vector3(x+2,height_at(x+2,z+2),z+2)
   var shade=rng.randf_range(.9,1.08)
   for p in [a,b,c,b,d,c]:
    st.set_color(Color("a76f50")*shade);st.set_normal(Vector3.UP);st.add_vertex(p)
 var mesh=MeshInstance3D.new();mesh.mesh=st.commit()
 var mat=StandardMaterial3D.new();mat.vertex_color_use_as_albedo=true;mat.roughness=1
 mesh.material_override=mat;add_child(mesh)
 # Rim beyond the playable area, never an invisible obstacle.
 for i in range(44):
  var angle=i*TAU/44;var p=Vector3(cos(angle)*32,1.2,sin(angle)*32)
  var rock=Art.rock(self,p,Vector3(rng.randf_range(4,8),rng.randf_range(3,8),rng.randf_range(3,6)),Color("93664e"))
  rock.rotation.y=angle
 grid=Node3D.new();add_child(grid);grid.visible=false
 for i in range(-LIMIT,LIMIT+1):
  Art.box(grid,Vector3(44,.012,.015),Vector3(0,.25,i*2),Color("cba284"))
  Art.box(grid,Vector3(.015,.012,44),Vector3(i*2,.25,0),Color("cba284"))
 selection=Art.ring(self,1.0,Vector3.ZERO,Color("b9e2ce"));selection.visible=false
func configure(defs: Array, blocked: Array) -> void:
 for n in targets.values():n.queue_free()
 targets.clear()
 for node in get_tree().get_nodes_in_group("b_obstacle"):
  if node.get_parent()==self:node.queue_free()
 obstacles.clear()
 for value in blocked:
  var tile: Vector2i=value;obstacles.append(tile)
  var p=Vector3(tile.x*2,height_at(tile.x*2,tile.y*2)+.45,tile.y*2)
  var stone=Art.rock(self,p,Vector3(1.65,.9,1.5),Color("785747"));stone.add_to_group("b_obstacle")
 for d in defs:
  var id=str(d.id);var tile: Vector2i=d.tile
  var n=Node3D.new();n.name=id;add_child(n);n.position=Vector3(tile.x*2,height_at(tile.x*2,tile.y*2),tile.y*2)
  var kind=str(d.get("type","rock"))
  if kind=="mineral":
   for j in range(4):
    var crystal=Art.cylinder(n,.18,.55+j*.13,Vector3((j%2)*.4,.35,(j/2)*.3),Color("85b3ac"),.01)
    crystal.rotation_degrees.z=j*12-15
  elif kind=="buried":
   Art.cylinder(n,.8,.12,Vector3(0,.06,0),Color("d9b783"))
   for j in range(3):Art.box(n,Vector3(.9,.12,.35),Vector3(0,.15+j*.14,j*.16),Color("9a674f"))
  else:
   var rock=Art.rock(n,Vector3(0,.4,0),Vector3(1.2,.8,1),Color("9d8d74"));rock.rotation.y=.3
   Art.rock(n,Vector3(.5,.2,.3),Vector3(.7,.4,.6),Color("c3a178"))
  var marker=Art.ring(n,.85,Vector3(0,.05,0),Color("bce0c1"));marker.name="Marker"
  n.visible=d.get("revealed",false);targets[id]=n
func update_targets(defs: Array) -> void:
 for d in defs:
  if targets.has(str(d.id)):
   targets[str(d.id)].visible=d.get("revealed",false)
   targets[str(d.id)].get_node("Marker").visible=not d.get("depleted",false)
func select(id: String) -> void:
 selected=id;selection.visible=targets.has(id) and targets[id].visible
 if selection.visible:selection.position=targets[id].position+Vector3(0,.1,0)
func target_at(point: Vector3) -> String:
 for id in targets:
  var n: Node3D=targets[id]
  if n.visible and Vector2(n.position.x-point.x,n.position.z-point.z).length()<1:return id
 return ""
func show_route(tiles: Array) -> void:
 if is_instance_valid(route_line):route_line.queue_free()
 if tiles.is_empty():return
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for tile in tiles:
  var p=Vector3(tile.x*2,height_at(tile.x*2,tile.y*2)+.08,tile.y*2)
  for v in [Vector3(-.13,0,-.13),Vector3(.13,0,-.13),Vector3(-.13,0,.13),Vector3(.13,0,-.13),Vector3(.13,0,.13),Vector3(-.13,0,.13)]:st.add_vertex(p+v)
 st.generate_normals();route_line=MeshInstance3D.new();route_line.mesh=st.commit();route_line.material_override=Art.mat(Color("c4ddba"));add_child(route_line)
