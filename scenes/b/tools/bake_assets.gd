extends SceneTree
const Art=preload("res://scenes/b/art.gd")
func _initialize() -> void:run.call_deferred()
func owner_children(node: Node,owner_root: Node) -> void:
 for child in node.get_children():
  child.owner=owner_root;owner_children(child,owner_root)
func save_scene(node: Node3D,name: String) -> void:
 owner_children(node,node)
 var scene=PackedScene.new();assert(scene.pack(node)==OK)
 assert(ResourceSaver.save(scene,"res://scenes/b/assets/models/"+name+".tscn")==OK)
 if name!="sector_preview":
  var doc=GLTFDocument.new();var state=GLTFState.new()
  assert(doc.append_from_scene(node,state)==OK)
  assert(doc.write_to_filesystem(state,"res://scenes/b/assets/models/"+name+".glb")==OK)
func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://scenes/b/assets/models")
 var rover=Node3D.new();rover.name="Rover"
 var parts=Art.rover(rover)
 for key in parts:
  if key=="wheels":
   for i in range(parts.wheels.size()):parts.wheels[i].name="Wheel%d"%i
  elif key!="visual":parts[key].name=key
 save_scene(rover,"rover")
 var station=Node3D.new();station.name="Station";Art.station(station);save_scene(station,"station")
 var drone=Node3D.new();drone.name="Drone";var rotors=Art.drone(drone).rotors
 for i in range(rotors.size()):rotors[i].name="Rotor%d"%i
 save_scene(drone,"drone")
 var companion=Node3D.new();companion.name="Companion";Art.companion(companion).body.name="Body";save_scene(companion,"companion")
 var preview=Node3D.new();preview.name="EditorPreview";root.add_child(preview)
 var ground=load("res://scenes/b/terrain.gd").new();preview.add_child(ground)
 ground.configure([{"id":"JZ01","tile":Vector2i(2,-2),"type":"rock","revealed":true},{"id":"JZ02","tile":Vector2i(-3,-2),"type":"mineral","revealed":true}], [Vector2i(-1,-2),Vector2i(4,0)])
 ground.set_script(null)
 for model in [rover,station,drone,companion]:preview.add_child(model)
 station.position=Vector3(7,0,6);drone.position=Vector3(-2,1,1);companion.position=Vector3(2,0,1)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-30,0);preview.add_child(light)
 save_scene(preview,"sector_preview")
 preview.queue_free();await process_frame
 print("BAKE PASS: original TSCN and GLB assets")
 quit()
