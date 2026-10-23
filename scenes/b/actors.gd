extends Node3D
const Art=preload("res://scenes/b/art.gd")
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
var link: MeshInstance3D
var scanner: MeshInstance3D
var route: Array=[]
var segment_start=Vector3.ZERO
var segment_time=0.0
var seconds_per_tile=.65
var active_action: Dictionary={}
var animation_clock=0.0
var flight=0.0
var paused=false
var safe=false
var landed=false
var landing_clock=0.0
var landing_active=false
var companion_enabled=true
var drone_enabled=true
var dust_ground: Callable
signal landing_finished
func _ready() -> void:
 rover=preload("res://scenes/b/assets/models/rover.tscn").instantiate();add_child(rover)
 parts={"visual":rover.get_node("RoverVisual"),"wheels":[]}
 for key in ["arm","solar","rtg","drill","radar","spectrometer","meteo","head"]:parts[key]=rover.find_child(key,true,false)
 for i in range(6):parts.wheels.append(rover.find_child("Wheel%d"%i,true,false))
 station=preload("res://scenes/b/assets/models/station.tscn").instantiate();add_child(station);station.position=Vector3(7,0,6)
 antenna_levels=[]
 for i in range(1,4):antenna_levels.append(station.get_node("AntennaLevel%d"%i))
 set_antenna(1)
 link=Art.ring(station,1.25,Vector3(0,1.7,0),Color("83bba9"));link.visible=false
 scanner=Art.ring(rover,1.8,Vector3(0,.12,0),Color("97cbc2"));scanner.visible=false
 drone=preload("res://scenes/b/assets/models/drone.tscn").instantiate();add_child(drone)
 rotor_parts={"rotors":[drone.get_node("Rotor0"),drone.get_node("Rotor1")]}
 companion=preload("res://scenes/b/assets/models/companion.tscn").instantiate();add_child(companion)
 companion_parts={"body":companion.get_node("Body")}
 dust=Art.dust(self,130,Vector3(20,3,20));dust.position.y=2
 drilling=Art.dust(rover,30,Vector3(.12,.1,.12));drilling.position=Vector3(.6,.3,-1.5)
 drilling.lifetime=.4;drilling.initial_velocity_min=.4;drilling.initial_velocity_max=1.2;drilling.gravity=Vector3(0,-1,0)
 crane=Node3D.new();crane.name="SkyCrane";add_child(crane)
 Art.box(crane,Vector3(3.4,.3,2.4),Vector3.ZERO,Art.DARK)
 for x in [-1.3,1.3]:
  for z in [-.8,.8]:Art.cylinder(crane,.18,.4,Vector3(x,-.3,z),Art.ORANGE,.27)
 for x in [-.6,.6]:Art.rod(crane,Vector3(x,0,0),Vector3(x,-2.5,0),.015,Art.IVORY)
 crane.visible=false
func at_tile(tile: Vector2i) -> Vector3:
 var p=Vector3(tile.x*2.0,0,tile.y*2.0)
 if dust_ground.is_valid():p.y=dust_ground.call(p.x,p.z)
 return p
func apply_state(s: Dictionary) -> void:
 paused=s.get("paused",false);safe=s.get("safe_mode",false)
 if s.get("teleport",false):cancel_actions()
 station.position=at_tile(s.get("station_tile",Vector2i(3,3)))
 var design: Dictionary=s.get("design",{})
 var instruments: Array=design.get("instruments",[])
 parts.solar.visible=design.get("power","solar")=="solar";parts.rtg.visible=not parts.solar.visible
 for id in ["drill","radar","spectrometer","meteo"]:parts[id].visible=id in instruments
 drone_enabled="drone" in instruments;companion_enabled=design.get("companion",true)
 drone.visible=drone_enabled;companion.visible=companion_enabled
 set_antenna(int(s.get("antenna_level",1)))
 dust.emitting=s.get("storm",false)
 link.visible=s.get("transmitting",false)
 if (route.is_empty() or safe) and not landing_active:
  rover.position=at_tile(s.get("rover_tile",Vector2i.ZERO))
 if safe:route.clear();active_action.clear()
func set_antenna(level: int) -> void:
 for i in range(antenna_levels.size()):antenna_levels[i].visible=i==clampi(level-1,0,2)
func follow_path(tiles: Array, seconds: float) -> void:
 route=tiles.duplicate();seconds_per_tile=maxf(.01,seconds);segment_time=0;segment_start=rover.position
func start_action(a: Dictionary) -> void:
 active_action=a.duplicate(true);active_action["elapsed"]=0.0
func start_landing() -> void:
 landing_active=true;landing_clock=0;landed=false;crane.visible=true
func cancel_actions() -> void:
 route.clear();active_action.clear();drilling.emitting=false
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
  var dir=target-segment_start
  if dir.length_squared()>.01:rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-dir.x,-dir.z),minf(1,delta*8))
  for wheel in parts.wheels:wheel.rotate_x(old.distance_to(rover.position)/.36)
  if segment_time>=seconds_per_tile:
   route.pop_front();segment_start=target;segment_time=0
 if not active_action.is_empty():
  active_action.elapsed+=delta
  var action=str(active_action.get("action",""))
  drilling.emitting=action=="drill"
  parts.arm.rotation.x=sin(animation_clock*8)*.12 if action in ["drill","spectrometer"] else 0
  if active_action.elapsed>=float(active_action.get("seconds",2.0)):
   active_action.clear();drilling.emitting=false;parts.arm.rotation=Vector3.ZERO
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
 if link.visible:
  link.scale=Vector3.ONE*(1+fmod(animation_clock*.6,1));link.rotation.y+=delta
