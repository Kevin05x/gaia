extends Node3D
const Art=preload("res://scenes/b/art.gd")
const Equipo=preload("res://scenes/b/modelos_equipo.gd")
var rover: Node3D
var drone: Node3D
var companion: Node3D
var station: Node3D
var crane: Node3D
var parts: Dictionary
var rotor_parts: Dictionary
var companion_parts: Dictionary
var antenna_levels: Array
var dust: CPUParticles3D
var drilling: CPUParticles3D
var link: Node3D
var scanner: MeshInstance3D
var route: Array=[]
var segment_start=Vector3.ZERO
var segment_time=0.0
var seconds_per_tile=.65
var active_action: Dictionary={}
var work_target=Vector3.ZERO  ## punto del mineral donde se trabaja (mundo)
var work_beam: MeshInstance3D
var work_ring: MeshInstance3D
var work_column: MeshInstance3D
var arm_home=Vector3.ZERO
var base_props: Node3D  ## escenografía de la base (modelos del equipo de diseño) detrás de la estación
var base_tile=Vector2i(999,999)
const TIP_OFFSET := .355  ## rad: la punta del brazo queda a la derecha del frente del rover
var animation_clock=0.0
var flight=0.0
var paused=false
var safe=false
var landed=false
var antenna_top=Vector3(0,1.9,0)  ## punta de la antena respecto a la estación (de aquí sale la animación de transmisión)
var landing_clock=0.0
var landing_active=false
var companion_enabled=true
var drone_enabled=true
var dust_ground: Callable
signal landing_finished
func _ready() -> void:
 rover=preload("res://scenes/b/assets/models/rover.tscn").instantiate();Art.optimize_rover(rover);add_child(rover)
 parts={"visual":rover.get_node("RoverVisual"),"wheels":[]}
 for key in ["arm","solar","rtg","drill","radar","spectrometer","meteo","head"]:parts[key]=rover.find_child(key,true,false)
 for i in range(6):parts.wheels.append(rover.find_child("Wheel%d"%i,true,false))
 preload("res://scenes/b/world_art.gd").contact_shadow(rover,1.45)
 station=preload("res://scenes/b/assets/models/station.tscn").instantiate();Art.optimize_station(station);add_child(station);station.position=Vector3(7,0,6)
 antenna_levels=[]
 for i in range(1,4):antenna_levels.append(station.get_node("AntennaLevel%d"%i))
 set_antenna(1)
 link=preload("res://scenes/b/transmission_fx.gd").new();link.rover=rover;add_child(link)
 scanner=Art.ring(rover,1.8,Vector3(0,.12,0),Color("97cbc2"));scanner.visible=false
 drone=preload("res://scenes/b/assets/models/drone.tscn").instantiate();Art.optimize_drone(drone);add_child(drone)
 rotor_parts={"rotors":[drone.get_node("Rotor0"),drone.get_node("Rotor1")]}
 companion=preload("res://scenes/b/assets/models/companion.tscn").instantiate();Art.optimize_companion(companion);add_child(companion)
 companion_parts={"body":companion.get_node("Body")}
 dust=Art.dust(self,130,Vector3(20,3,20));dust.position.y=2
 drilling=Art.dust(rover,30,Vector3(.12,.1,.12));drilling.position=Vector3(.6,.3,-1.5)
 drilling.lifetime=.4;drilling.initial_velocity_min=.4;drilling.initial_velocity_max=1.2;drilling.gravity=Vector3(0,-1,0)
 arm_home=parts.arm.position
 var beam_mat=StandardMaterial3D.new();beam_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;beam_mat.albedo_color=Color(.59,.8,.76,.8);beam_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;beam_mat.no_depth_test=true
 work_beam=MeshInstance3D.new();var cyl=CylinderMesh.new();cyl.top_radius=.04;cyl.bottom_radius=.04;cyl.radial_segments=6;work_beam.mesh=cyl;work_beam.material_override=beam_mat;work_beam.visible=false;add_child(work_beam)
 work_ring=Art.ring(self,.8,Vector3.ZERO,Color("f2c070"));work_ring.visible=false;work_ring.material_override=_glow(Color(.95,.75,.44,.9))
 work_column=MeshInstance3D.new();var col=CylinderMesh.new();col.top_radius=.05;col.bottom_radius=.35;col.height=2.2;col.radial_segments=10;work_column.mesh=col;work_column.material_override=_glow(Color(.95,.75,.44,.22));work_column.visible=false;add_child(work_column)
 drilling.direction=Vector3(0,1,0);drilling.spread=55;drilling.gravity=Vector3(0,-5,0);drilling.lifetime=.9;drilling.amount=48
 drilling.initial_velocity_min=1.4;drilling.initial_velocity_max=3.0;drilling.scale_amount_min=1.4;drilling.scale_amount_max=2.6
 crane=Node3D.new();crane.name="SkyCrane";add_child(crane)
 Art.box(crane,Vector3(3.4,.3,2.4),Vector3.ZERO,Art.DARK)
 for x in [-1.3,1.3]:
  for z in [-.8,.8]:Art.cylinder(crane,.18,.4,Vector3(x,-.3,z),Art.ORANGE,.27)
 for x in [-.6,.6]:Art.rod(crane,Vector3(x,0,0),Vector3(x,-2.5,0),.015,Art.IVORY)
 Art.merged(crane)
 crane.visible=false
func at_tile(tile: Vector2i) -> Vector3:
 var p=Vector3(tile.x*2.0,0,tile.y*2.0)
 if dust_ground.is_valid():p.y=dust_ground.call(p.x,p.z)
 return p
func apply_state(s: Dictionary) -> void:
 paused=s.get("paused",false);safe=s.get("safe_mode",false)
 if s.get("teleport",false):cancel_actions()
 station.position=at_tile(s.get("station_tile",Vector2i(3,3)))
 if s.has("buildings"):_clear_base_props()  # con base real, los edificios los dibuja buildings.gd
 else:_place_base_props(s.get("station_tile",Vector2i(3,3)))
 var design: Dictionary=s.get("design",{})
 var instruments: Array=design.get("instruments",[])
 parts.solar.visible=design.get("power","solar")=="solar";parts.rtg.visible=not parts.solar.visible
 for id in ["drill","radar","spectrometer","meteo"]:parts[id].visible=id in instruments
 drone_enabled="drone" in instruments;companion_enabled=design.get("companion",true)
 drone.visible=drone_enabled;companion.visible=companion_enabled
 set_antenna(int(s.get("antenna_level",1)))
 dust.emitting=s.get("storm",false)
 link.active=s.get("transmitting",false);link.set_process(not paused)
 if (route.is_empty() or safe) and not landing_active:
  rover.position=at_tile(s.get("rover_tile",Vector2i.ZERO))
 if safe:route.clear();active_action.clear()
func set_antenna(level: int) -> void:
 for i in range(antenna_levels.size()):antenna_levels[i].visible=i==clampi(level-1,0,2)
 antenna_top=Vector3(0,[1.9,2.5,2.9][clampi(level-1,0,2)],0)
func follow_path(tiles: Array, seconds: float) -> void:
 route=tiles.duplicate();seconds_per_tile=maxf(.01,seconds);segment_time=0;segment_start=rover.position
func start_action(a: Dictionary) -> void:
 active_action=a.duplicate(true);active_action["elapsed"]=0.0
func start_landing() -> void:
 landing_active=true;landing_clock=0;landed=false;crane.visible=true
func cancel_actions() -> void:
 route.clear();active_action.clear();drilling.emitting=false;_end_work()
func _process(delta: float) -> void:
 if paused:return
 animation_clock+=delta
 if landing_active:
  landing_clock+=delta
  var p=clampf(landing_clock/4,0,1)
  rover.position=at_tile(Vector2i.ZERO)+Vector3(0,(1-p)*10,0)
  crane.position=rover.position+Vector3(0,2.5,0)
  if landing_clock>=4:
   crane.position=Vector3((landing_clock-4)*8,2.5+(landing_clock-4)*8,0)
  if landing_clock>=5.5:
   landing_active=false;landed=true;crane.visible=false;landing_finished.emit()
 if not route.is_empty() and not safe and not landing_active:
  segment_time+=delta
  var target=at_tile(route[0]);var old=rover.position
  rover.position=segment_start.lerp(target,clampf(segment_time/seconds_per_tile,0,1))
  if dust_ground.is_valid():rover.position.y=dust_ground.call(rover.position.x,rover.position.z)
  var dir=target-segment_start
  if dir.length_squared()>.01:rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-dir.x,-dir.z),minf(1,delta*8))
  for wheel in parts.wheels:wheel.rotate_x(old.distance_to(rover.position)/.43)
  if segment_time>=seconds_per_tile:
   route.pop_front();segment_start=target;segment_time=0
 if not active_action.is_empty():
  active_action.elapsed+=delta
  var action=str(active_action.get("action",""))
  var aims=action in ["drill","spectrometer"]
  if aims and active_action.has("tile"):_work_on_target(action,delta)
  else:
   drilling.emitting=action=="drill"
   parts.arm.rotation.x=sin(animation_clock*8)*.12 if aims else 0
  if active_action.elapsed>=float(active_action.get("seconds",2.0)):
   active_action.clear();drilling.emitting=false;_end_work()
 elif work_beam.visible or parts.visual.position!=Vector3.ZERO:_end_work()
 var scanning=not active_action.is_empty() and active_action.get("action") in ["radar","panorama"]
 scanner.visible=scanning
 if scanning:
  scanner.scale=Vector3.ONE*(.5+fmod(animation_clock*.5,1.2))
  parts.head.rotation.y=sin(animation_clock)*.6
 else:parts.head.rotation.y=0
 var flying=not active_action.is_empty() and active_action.get("action")=="drone"
 flight=move_toward(flight,1.0 if flying else 0.0,delta*.5)
 drone.position=rover.position+Vector3(-1.7+sin(animation_clock)*flight*3,.65+flight*3,1.4+cos(animation_clock)*flight*3)
 for i in range(rotor_parts.rotors.size()):rotor_parts.rotors[i].rotate_y(delta*(5+flight*40)*(1 if i==0 else -1))
 var companion_target=rover.position+Vector3(1.8,0,1.4)
 if not active_action.is_empty() and active_action.get("action")=="companion":companion_target+=Vector3(sin(animation_clock)*2,0,cos(animation_clock)*2)
 companion.position=companion.position.move_toward(companion_target,delta*2)
 companion.position.y=(dust_ground.call(companion.position.x,companion.position.z) if dust_ground.is_valid() else 0)+absf(sin(animation_clock*3))*.05
 dust.position=Vector3(rover.position.x,2,rover.position.z)
 link.base=station.global_position+antenna_top

func _end_work() -> void:
 work_beam.visible=false;work_ring.visible=false;work_column.visible=false;drilling.emitting=false
 parts.arm.rotation=Vector3.ZERO;parts.arm.position=arm_home;parts.visual.position=Vector3.ZERO
## El rover se gira hacia el mineral, adelanta un poco el cuerpo si hace falta y el brazo trabaja sobre la roca.
func _work_on_target(action: String, delta: float) -> void:
 var tile=active_action["tile"]
 if tile is Array:tile=Vector2i(int(tile[0]),int(tile[1]))
 work_target=at_tile(tile)
 var to=work_target-rover.position
 var flat=Vector3(to.x,0,to.z)
 if flat.length_squared()>.01:
  rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-flat.x,-flat.z)+TIP_OFFSET,minf(1,delta*5))
  var reach=maxf(0.0,flat.length()-.8-1.73)
  var local_dir=(rover.global_transform.basis.inverse()*flat.normalized())
  parts.visual.position=parts.visual.position.move_toward(local_dir*reach,delta*.8)
 var hit=work_target+Vector3(0,.35,0)
 var t=float(active_action.get("elapsed",0.0))
 parts.arm.rotation.x=-.15+sin(animation_clock*10)*.05
 if action=="drill":
  parts.arm.position=arm_home+Vector3(0,-absf(sin(animation_clock*9))*.1,0)
  drilling.global_position=hit;drilling.emitting=true
  work_beam.visible=false
 else:
  drilling.emitting=false
  var a=parts.spectrometer.global_position
  var mid=(a+hit)*.5
  var len=a.distance_to(hit)
  (work_beam.mesh as CylinderMesh).height=len
  work_beam.global_position=mid
  work_beam.look_at(hit,Vector3.UP)
  work_beam.rotate_object_local(Vector3.RIGHT,PI*.5)
  work_beam.visible=true
 work_ring.visible=true;work_column.visible=true
 work_column.global_position=work_target+Vector3(0,1.1,0)
 work_ring.global_position=Vector3(work_target.x,work_target.y+.08,work_target.z)
 work_ring.scale=Vector3.ONE*(.9+.25*sin(animation_clock*6))

func _glow(color: Color) -> StandardMaterial3D:
 var m=StandardMaterial3D.new();m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;m.albedo_color=color
 m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.no_depth_test=true;m.render_priority=10
 return m

## Hangares, foco, antena y torre de perforación del equipo de diseño: se reparten detrás de la estación (hacia fuera del
## mapa) para que no tapen el camino del rover. Solo decoración; la simulación no los conoce.
func _clear_base_props() -> void:
 if is_instance_valid(base_props):
  remove_child(base_props);base_props.queue_free()
 base_props=null;base_tile=Vector2i(99999,99999)

func _place_base_props(tile: Vector2i) -> void:
 if tile==base_tile:return
 base_tile=tile
 if is_instance_valid(base_props):
  remove_child(base_props);base_props.queue_free()
 if not Equipo.existe("hangar_cuadrado"):return
 base_props=Node3D.new();base_props.name="BaseProps";add_child(base_props)
 var out=Vector2(tile.x,tile.y)
 out=out.normalized() if out.length()>.01 else Vector2(-1,-1).normalized()
 var side=Vector2(-out.y,out.x)
 var origin=at_tile(tile)
 # [modelo, ancho en metros, distancia hacia fuera, desplazamiento lateral]
 for item in [["hangar_cuadrado",4.2,11.0,-7.5],["hangar_roundA",3.4,10.0,6.5],["foco",1.6,5.0,5.0],["anthena_juego",2.6,13.0,-0.5],["taladro",2.4,6.5,-9.0]]:
  var p2=Vector2(origin.x,origin.z)+out*float(item[2])+side*float(item[3])
  var node=Node3D.new();base_props.add_child(node)
  var y=dust_ground.call(p2.x,p2.y) if dust_ground.is_valid() else 0.0
  node.position=Vector3(p2.x,y,p2.y)
  node.rotation.y=atan2(-out.x,-out.y)+PI  # de cara al centro del mapa
  Equipo.poner(node,str(item[0]),float(item[1]))
