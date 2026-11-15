extends Node3D
const Art=preload("res://scenes/b/art.gd")
const Equipo=preload("res://scenes/b/modelos_equipo.gd")
const RoverNasa=preload("res://scenes/b/rover_nasa.gd")
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
var arm_trabajo=Vector3.ZERO  ## posición del brazo extendido sobre la roca
var obra_tile: Variant=null  ## casilla de la obra que el rover construye ahora (null si no construye)
var chispas: CPUParticles3D  ## chispas de soldadura en la obra
var luz_soldadura: OmniLight3D  ## destello azulado del arco de soldadura
const ESCALA_COMPANERO := 0.8  ## el compañero (robot de apoyo inventado) mide ≈ 1 m: la mitad del rover
const ESCALA_ESTACION := 1.8  ## la estación mide 10,6 m de lado: ocupa 3 × 3 casillas (estacion_radio del mapa) y triplica al rover
var base_props: Node3D  ## escenografía de la base (modelos del equipo de diseño) detrás de la estación
var base_tile=Vector2i(999,999)
var tip_offset := .355  ## rad: la punta del brazo queda a la derecha del frente del rover (el rover de la NASA lo calcula de su modelo)
var alcance := 1.73  ## m: del centro del rover a la punta del brazo
var radio_rueda := .43  ## m
var rover_real := false  ## true si el rover es el modelo oficial de la NASA (escala real 1:1)
var animation_clock=0.0
var flight=0.0
var paused=false
var safe=false
var landed=false
var _ruta_nueva=false  ## el primer tramo de una ruta arranca suave (sin salto de velocidad)
var _giro_antes=0.0  ## rumbo del cuadro anterior (para el balanceo al girar)
var antenna_top=Vector3(0,1.9,0)  ## punta de la antena respecto a la estación (de aquí sale la animación de transmisión)
var landing_clock=0.0
var landing_active=false
var companion_enabled=true
var drone_enabled=true
var dust_ground: Callable
signal landing_finished
func _ready() -> void:
 rover=RoverNasa.crear()
 rover_real=rover!=null
 if rover_real:
  tip_offset=float(rover.get_meta("tip_offset"));alcance=float(rover.get_meta("alcance"));radio_rueda=float(rover.get_meta("radio_rueda"))
 else:
  rover=preload("res://scenes/b/assets/models/rover.tscn").instantiate();Art.optimize_rover(rover)
 add_child(rover)
 parts={"visual":rover.get_node("RoverVisual"),"wheels":[]}
 for key in ["arm","solar","rtg","drill","radar","spectrometer","meteo","head"]:parts[key]=rover.find_child(key,true,false)
 for i in range(6):parts.wheels.append(rover.find_child("Wheel%d"%i,true,false))
 preload("res://scenes/b/world_art.gd").contact_shadow(rover,2.4 if rover_real else 1.45)
 station=preload("res://scenes/b/assets/models/station.tscn").instantiate();Art.optimize_station(station);add_child(station);station.position=Vector3(7,0,6);station.scale=Vector3.ONE*ESCALA_ESTACION
 antenna_levels=[]
 for i in range(1,4):antenna_levels.append(station.get_node("AntennaLevel%d"%i))
 set_antenna(1)
 link=preload("res://scenes/b/transmission_fx.gd").new();link.rover=rover;add_child(link)
 scanner=Art.ring(rover,3.2 if rover_real else 1.8,Vector3(0,.12,0),Color("97cbc2"));scanner.visible=false
 _crear_dron()
 companion=preload("res://scenes/b/assets/models/companion.tscn").instantiate();Art.optimize_companion(companion);add_child(companion);companion.scale=Vector3.ONE*ESCALA_COMPANERO
 companion_parts={"body":companion.get_node("Body")}
 dust=Art.dust(self,130,Vector3(20,3,20));dust.position.y=2
 drilling=Art.dust(rover,30,Vector3(.2,.15,.2));drilling.position=Vector3(.6,.3,-1.5)
 drilling.lifetime=.4;drilling.initial_velocity_min=.4;drilling.initial_velocity_max=1.2;drilling.gravity=Vector3(0,-1,0)
 arm_home=parts.arm.position;arm_trabajo=arm_home+(Vector3(0,-.12,-.55) if rover_real else Vector3.ZERO)
 var beam_mat=StandardMaterial3D.new();beam_mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;beam_mat.albedo_color=Color(.59,.8,.76,.8);beam_mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;beam_mat.no_depth_test=true
 work_beam=MeshInstance3D.new();var cyl=CylinderMesh.new();cyl.top_radius=.04;cyl.bottom_radius=.04;cyl.radial_segments=6;work_beam.mesh=cyl;work_beam.material_override=beam_mat;work_beam.visible=false;add_child(work_beam)
 work_ring=Art.ring(self,1.6,Vector3.ZERO,Color("f2c070"));work_ring.visible=false;work_ring.material_override=_glow(Color(.95,.75,.44,.9))
 work_column=MeshInstance3D.new();var col=CylinderMesh.new();col.top_radius=.08;col.bottom_radius=.7;col.height=4.0;col.radial_segments=10;work_column.mesh=col;work_column.material_override=_glow(Color(.95,.75,.44,.22));work_column.visible=false;add_child(work_column)
 drilling.direction=Vector3(0,1,0);drilling.spread=55;drilling.gravity=Vector3(0,-5,0);drilling.lifetime=.9;drilling.amount=48
 drilling.initial_velocity_min=1.4;drilling.initial_velocity_max=3.0;drilling.scale_amount_min=1.4;drilling.scale_amount_max=2.6
 _crear_soldadura()
 crane=Node3D.new();crane.name="SkyCrane";add_child(crane)
 Art.box(crane,Vector3(3.4,.3,2.4),Vector3.ZERO,Art.DARK)
 for x in [-1.3,1.3]:
  for z in [-.8,.8]:Art.cylinder(crane,.18,.4,Vector3(x,-.3,z),Art.ORANGE,.27)
 for x in [-.6,.6]:Art.rod(crane,Vector3(x,0,0),Vector3(x,-7.6,0),.02,Art.IVORY)  # el arnés real mide 7,6 m
 Art.merged(crane)
 crane.visible=false
func at_tile(tile: Vector2i) -> Vector3:
 var p=Vector3(tile.x*Escala.TILE,0,tile.y*Escala.TILE)
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
 obra_tile=_obra_del_rover(s)
var _otros_rovers: Dictionary = {}  ## id -> rover de otro jugador (multijugador en red)
## Los rovers de los demás jugadores (el propio lo mueve apply_state): se colocan en su casilla, mirando hacia donde van.
func apply_others(s: Dictionary) -> void:
 var mine: int=int(s.get("rover_id",0))
 var vistos: Array=[]
 for r in s.get("rovers",[]):
  var id: int=int(r.get("id",0))
  if mine==0 or id==mine:continue
  vistos.append(id)
  if not _otros_rovers.has(id):
   var n: Node3D=RoverNasa.crear()
   if n==null:n=preload("res://scenes/b/assets/models/rover.tscn").instantiate()
   add_child(n)
   _otros_rovers[id]=n
   # El nombre del jugador, flotando sobre su rover (se ve desde cualquier ángulo y a través de las rocas).
   var etiqueta:=Label3D.new()
   etiqueta.text=str(Red.sala.nombres.get(id,"")) if Red.sala!=null else ""
   etiqueta.billboard=BaseMaterial3D.BILLBOARD_ENABLED
   etiqueta.no_depth_test=true
   etiqueta.pixel_size=0.012
   etiqueta.font_size=56
   etiqueta.outline_size=14
   etiqueta.modulate=Color("9AD7C6")
   etiqueta.position=Vector3(0,3.4,0)
   n.add_child(etiqueta)
   # Mismo diseño que el propio: panel solar o generador nuclear, e instrumentos montados.
   var diseno: Dictionary=s.get("design",{})
   var solar: Node3D=n.find_child("solar",true,false)
   var rtg: Node3D=n.find_child("rtg",true,false)
   if solar!=null:solar.visible=diseno.get("power","solar")=="solar"
   if rtg!=null:rtg.visible=diseno.get("power","solar")!="solar"
   for pieza in ["drill","radar","spectrometer","meteo"]:
    var nodo_pieza: Node3D=n.find_child(pieza,true,false)
    if nodo_pieza!=null:nodo_pieza.visible=pieza in diseno.get("instruments",[])
  var nodo: Node3D=_otros_rovers[id]
  var destino: Vector3=at_tile(Vector2i(r.get("tile",Vector2i.ZERO)))
  var d: Vector3=destino-nodo.position
  if d.length()>.05 and d.length()<8.0:nodo.rotation.y=atan2(-d.x,-d.z)
  nodo.position=nodo.position.lerp(destino,.35) if d.length()<8.0 else destino
 for id in _otros_rovers.keys():
  if not vistos.has(id):
   (_otros_rovers[id] as Node3D).queue_free()
   _otros_rovers.erase(id)
## Obra con rover: la obra en curso (no un muro, que se imprime solo) junto a la que está el rover quieto, o null.
func _obra_del_rover(s: Dictionary) -> Variant:
 if s.get("moving",false) or safe:return null
 var aqui: Vector2i=s.get("rover_tile",Vector2i.ZERO)
 for b in s.get("buildings",[]):
  if not b.get("building",false) or b.get("waiting_rover",false) or MurosView.es_muro(str(b.get("type",""))):continue
  var d: Vector2i=Vector2i(b.get("tile",Vector2i.ZERO))-aqui
  if maxi(absi(d.x),absi(d.y))<=1:return Vector2i(b.get("tile",Vector2i.ZERO))
 return null
## Chispas y destello de soldadura (ocultos hasta que el rover construye).
func _crear_soldadura() -> void:
 chispas=CPUParticles3D.new();chispas.name="Chispas";chispas.emitting=false;chispas.amount=40;chispas.lifetime=.55
 chispas.explosiveness=.15;chispas.direction=Vector3(0,1,0);chispas.spread=70;chispas.gravity=Vector3(0,-6.0,0)
 chispas.initial_velocity_min=1.6;chispas.initial_velocity_max=3.6;chispas.local_coords=false
 chispas.scale_amount_min=.6;chispas.scale_amount_max=1.2
 var gota=SphereMesh.new();gota.radius=.025;gota.height=.05;gota.radial_segments=4;gota.rings=2
 var mat=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.vertex_color_use_as_albedo=true
 gota.material=mat;chispas.mesh=gota
 var rampa=Gradient.new();rampa.set_color(0,Color(1,.97,.85));rampa.set_color(1,Color(1,.42,.08,0))
 chispas.color_ramp=rampa
 chispas.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(chispas)
 luz_soldadura=OmniLight3D.new();luz_soldadura.name="LuzSoldadura";luz_soldadura.light_color=Color(.72,.86,1.0)
 luz_soldadura.omni_range=7.0;luz_soldadura.shadow_enabled=false;luz_soldadura.visible=false
 add_child(luz_soldadura)
## El rover se gira hacia la obra, extiende el brazo y suelda: chispas y un destello que parpadea en la pared de la obra.
func _soldar(delta: float) -> void:
 var centro=at_tile(obra_tile)
 var to=centro-rover.position
 var flat=Vector3(to.x,0,to.z)
 if flat.length_squared()>.01:rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-flat.x,-flat.z)+tip_offset,minf(1,delta*4))
 parts.arm.position=parts.arm.position.move_toward(arm_trabajo,delta*1.2)
 parts.arm.rotation.x=-.12+sin(animation_clock*7)*.06
 # Punto de soldadura: en la cara de la obra que mira al rover, a media altura, y se desplaza despacio.
 var cara=centro-flat.normalized()*1.5 if flat.length_squared()>.01 else centro
 var lado=Vector3(-flat.z,0,flat.x).normalized()*sin(animation_clock*.7)*.6 if flat.length_squared()>.01 else Vector3.ZERO
 var punto=cara+lado+Vector3(0,.8+.35*sin(animation_clock*.45),0)
 chispas.global_position=punto;chispas.emitting=true
 luz_soldadura.visible=true;luz_soldadura.global_position=punto-flat.normalized()*.3
 luz_soldadura.light_energy=1.4+randf()*2.2 if fmod(animation_clock,0.9)<0.75 else 0.2
## Dron: el helicóptero Ingenuity real de la NASA a escala 1:1 (1,2 m de rotor a rotor, 0,5 m de alto). Si falta el modelo,
## el dron de bloques del equipo (escala similar).
func _crear_dron() -> void:
 var ruta="res://assets/nasa/modelos/ingenuity.glb"
 var rotores: Array=[]
 if ResourceLoader.exists(ruta):
  drone=Node3D.new();drone.name="Ingenuity"
  drone.add_child((load(ruta) as PackedScene).instantiate())
  for nombre in ["rotors_01","rotors_02"]:
   var r=drone.find_child(nombre,true,false)
   if r!=null:rotores.append(r)
 if rotores.size()<2:
  if drone!=null:drone.queue_free()
  drone=preload("res://scenes/b/assets/models/drone.tscn").instantiate();Art.optimize_drone(drone)
  rotores=[drone.get_node("Rotor0"),drone.get_node("Rotor1")]
  drone.scale=Vector3.ONE*.45
 add_child(drone)
 rotor_parts={"rotors":rotores}
func set_antenna(level: int) -> void:
 for i in range(antenna_levels.size()):antenna_levels[i].visible=i==clampi(level-1,0,2)
 antenna_top=Vector3(0,[1.9,2.5,2.9][clampi(level-1,0,2)],0)*ESCALA_ESTACION
func follow_path(tiles: Array, seconds: float) -> void:
 _ruta_nueva=route.is_empty()
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
  rover.position=at_tile(Vector2i.ZERO)+Vector3(0,(1-p)*22,0)
  crane.position=rover.position+Vector3(0,7.6,0)
  if landing_clock>=4:
   crane.position=at_tile(Vector2i.ZERO)+Vector3((landing_clock-4)*10,7.6+(landing_clock-4)*12,0)
  if landing_clock>=5.5:
   landing_active=false;landed=true;crane.visible=false;landing_finished.emit()
 if not route.is_empty() and not safe and not landing_active:
  segment_time+=delta
  var target=at_tile(route[0]);var old=rover.position
  rover.position=segment_start.lerp(target,_avance(clampf(segment_time/seconds_per_tile,0,1)))
  # Suspensión: un leve vaivén al rodar (la simulación no cambia: es solo la carrocería).
  if dust_ground.is_valid():rover.position.y=dust_ground.call(rover.position.x,rover.position.z)+absf(sin(animation_clock*11.0))*.025
  var dir=target-segment_start
  if dir.length_squared()>.01:rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-dir.x,-dir.z),minf(1,delta*8))
  for wheel in parts.wheels:wheel.rotate_x(old.distance_to(rover.position)/radio_rueda)
  if segment_time>=seconds_per_tile:
   route.pop_front();segment_start=target;segment_time=0;_ruta_nueva=false
 _inclinar(delta)
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
 elif obra_tile!=null and route.is_empty() and not safe:_soldar(delta)
 elif work_beam.visible or parts.visual.position!=Vector3.ZERO or chispas.emitting:_end_work()
 var scanning=not active_action.is_empty() and active_action.get("action") in ["radar","panorama"]
 scanner.visible=scanning
 if scanning:
  scanner.scale=Vector3.ONE*(.5+fmod(animation_clock*.5,1.2))
  parts.head.rotation.y=sin(animation_clock)*.6
 else:parts.head.rotation.y=0
 var flying=not active_action.is_empty() and active_action.get("action")=="drone"
 flight=move_toward(flight,1.0 if flying else 0.0,delta*.5)
 drone.position=rover.position+Vector3(-3.4+sin(animation_clock)*flight*6,.9+flight*5,2.8+cos(animation_clock)*flight*6)
 for i in range(rotor_parts.rotors.size()):rotor_parts.rotors[i].global_rotate(Vector3.UP,delta*(5+flight*40)*(1 if i==0 else -1))
 var companion_target=rover.position+Vector3(3.4,0,2.6)
 if not active_action.is_empty() and active_action.get("action")=="companion":companion_target+=Vector3(sin(animation_clock)*4,0,cos(animation_clock)*4)
 companion.position=companion.position.move_toward(companion_target,delta*4)
 companion.position.y=(dust_ground.call(companion.position.x,companion.position.z) if dust_ground.is_valid() else 0)+absf(sin(animation_clock*3))*.05
 dust.position=Vector3(rover.position.x,2,rover.position.z)
 link.base=station.global_position+antenna_top

## Avance dentro de un tramo: arranca suave en el primero, frena en el último y es constante entre medias, con la
## misma velocidad en las uniones (curvas con derivada 0 y 1 en los extremos que tocan).
func _avance(t: float) -> float:
 var primero=_ruta_nueva;var ultimo=route.size()<=1
 if primero and ultimo:return t*t*(3.0-2.0*t)
 if primero:return t*t*(2.0-t)
 if ultimo:return 1.0-(1.0-t)*(1.0-t)*(1.0+t)
 return t

## La carrocería se inclina con la pendiente del suelo (cabeceo y alabeo) y se balancea un poco al girar.
func _inclinar(delta: float) -> void:
 if not dust_ground.is_valid() or landing_active:return
 var y=rover.rotation.y;var p=rover.position
 var f=Vector3(-sin(y),0,-cos(y));var r=Vector3(cos(y),0,-sin(y))
 var h=func(q: Vector3) -> float: return dust_ground.call(q.x,q.z)
 var cabeceo=atan2(h.call(p+f*1.5)-h.call(p-f*1.5),3.0)
 var giro=wrapf(y-_giro_antes,-PI,PI)/maxf(delta,.001);_giro_antes=y
 var alabeo=atan2(h.call(p+r*1.35)-h.call(p-r*1.35),2.7)-clampf(giro*.03,-.06,.06)
 var k=1.0-exp(-delta*8.0)
 rover.rotation.x=lerpf(rover.rotation.x,clampf(cabeceo,-.35,.35),k)
 rover.rotation.z=lerpf(rover.rotation.z,clampf(alabeo,-.3,.3),k)

func _end_work() -> void:
 work_beam.visible=false;work_ring.visible=false;work_column.visible=false;drilling.emitting=false
 chispas.emitting=false;luz_soldadura.visible=false
 parts.arm.rotation=Vector3.ZERO;parts.arm.position=arm_home;parts.visual.position=Vector3.ZERO
## El rover se gira hacia el mineral, adelanta un poco el cuerpo si hace falta y el brazo trabaja sobre la roca.
func _work_on_target(action: String, delta: float) -> void:
 var tile=active_action["tile"]
 if tile is Array:tile=Vector2i(int(tile[0]),int(tile[1]))
 work_target=at_tile(tile)
 var to=work_target-rover.position
 var flat=Vector3(to.x,0,to.z)
 if flat.length_squared()>.01:
  rover.rotation.y=lerp_angle(rover.rotation.y,atan2(-flat.x,-flat.z)+tip_offset,minf(1,delta*5))
  var reach=maxf(0.0,flat.length()-(2.5 if rover_real else .8)-(alcance+(.55 if rover_real else 0.0)))
  var local_dir=(rover.global_transform.basis.inverse()*flat.normalized())
  parts.visual.position=parts.visual.position.move_toward(local_dir*reach,delta*.8)
 var hit=work_target+Vector3(0,.35 if not rover_real else .5,0)
 var t=float(active_action.get("elapsed",0.0))
 parts.arm.rotation.x=-.15+sin(animation_clock*10)*.05
 if action=="drill":
  parts.arm.position=parts.arm.position.move_toward(arm_trabajo+Vector3(0,-absf(sin(animation_clock*9))*.1,0),delta*1.2)
  drilling.global_position=hit;drilling.emitting=true
  work_beam.visible=false
 else:
  drilling.emitting=false
  parts.arm.position=parts.arm.position.move_toward(arm_trabajo,delta*1.2)
  var a=parts.spectrometer.global_position
  var mid=(a+hit)*.5
  var len=a.distance_to(hit)
  (work_beam.mesh as CylinderMesh).height=len
  work_beam.global_position=mid
  work_beam.look_at(hit,Vector3.UP)
  work_beam.rotate_object_local(Vector3.RIGHT,PI*.5)
  work_beam.visible=true
 work_ring.visible=true;work_column.visible=true
 work_column.global_position=work_target+Vector3(0,2.0,0)
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
 for item in [["hangar_cuadrado",3.9,22.0,-15.0,1.9],["hangar_roundA",3.9,20.0,13.0,1.6],["foco",3.2,10.0,10.0,1.0],["anthena_juego",3.8,26.0,-1.0,1.7],["taladro",3.6,13.0,-18.0,1.0]]:
  var p2=Vector2(origin.x,origin.z)+out*float(item[2])+side*float(item[3])
  var node=Node3D.new();base_props.add_child(node)
  var y=dust_ground.call(p2.x,p2.y) if dust_ground.is_valid() else 0.0
  node.position=Vector3(p2.x,y,p2.y)
  node.rotation.y=atan2(-out.x,-out.y)+PI  # de cara al centro del mapa
  Equipo.poner(node,str(item[0]),float(item[1]),Vector3.ZERO,0.0,float(item[4]))
