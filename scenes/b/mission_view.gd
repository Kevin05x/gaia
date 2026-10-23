extends Node3D
# Public entry point for A: instantiate mission.tscn, use its Port node.
const Art=preload("res://scenes/b/art.gd")
var port: Node
var terrain: Node3D
var actors: Node3D
var rig: Node3D
var hud: CanvasLayer
var report_view: CanvasLayer
var audio: Node
var sun: DirectionalLight3D
var environment: Environment
var state: Dictionary={}
var inspection=false
var language="es"
var volume=.65
var muted=false
var quality=true
var landing_in_progress=false
var selected_target=""
var map_signature=""
static var translations_registered=false
func _ready() -> void:
 var editor_preview=get_node_or_null("EditorPreview")
 if editor_preview!=null:remove_child(editor_preview);editor_preview.queue_free()
 setup_locale()
 port=get_node("Port")
 terrain=preload("res://scenes/b/terrain.gd").new();terrain.name="Terrain";add_child(terrain)
 actors=preload("res://scenes/b/actors.gd").new();actors.name="Actors";add_child(actors);actors.dust_ground=terrain.height_at
 rig=preload("res://scenes/b/camera.gd").new();rig.name="CameraRig";add_child(rig)
 var world=WorldEnvironment.new();environment=Environment.new();world.environment=environment
 environment.background_mode=Environment.BG_COLOR;environment.background_color=Color("6e6257")
 environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.ambient_light_color=Color("c5b69f");environment.ambient_light_energy=.6
 environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 add_child(world)
 sun=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-45,-35,0);sun.light_color=Color("ffe0b5");sun.shadow_enabled=quality;add_child(sun)
 hud=preload("res://scenes/b/hud.gd").new();hud.name="HUD";add_child(hud);hud.inspection=inspection
 hud.command.connect(_command);hud.locale_changed.connect(change_locale);hud.preferences_changed.connect(set_preferences)
 audio=preload("res://scenes/b/audio.gd").new();add_child(audio);audio.set_volume(volume,muted)
 hud.volume=volume;hud.muted=muted;hud.quality=quality;hud.build()
 report_view=preload("res://scenes/b/report.gd").new();report_view.name="Report";add_child(report_view)
 report_view.redesign_requested.connect(func():port.submit("redesign"))
 port.snapshot_received.connect(apply_snapshot)
 port.report_received.connect(_report)
 port.path_received.connect(func(tiles: Array,seconds: float):actors.follow_path(tiles,seconds);terrain.show_route(tiles))
 port.action_received.connect(func(action: Dictionary):actors.start_action(action);hud.start_action(action);audio.start_action(action))
 port.cancel_received.connect(actors.cancel_actions)
 port.cancel_received.connect(audio.cancel)
 port.rejected.connect(func(key: String):hud.show_notice(key))
 actors.landing_finished.connect(func():landing_in_progress=false;port.submit("landing_finished"))
 set_preferences(volume,muted,quality,false)
 if not port.snapshot.is_empty():apply_snapshot(port.snapshot)
 else:hud.show_notice("WAIT")
func setup_locale() -> void:
 if not translations_registered:
  var tables=preload("res://scenes/b/i18n/catalog.gd").TABLES
  for locale in tables:
   var translation=Translation.new();translation.locale=locale
   for key in tables[locale]:translation.add_message(key,tables[locale][key])
   TranslationServer.add_translation(translation)
  translations_registered=true
 var config=ConfigFile.new()
 if config.load("user://b_preferences.cfg")==OK:
  language=config.get_value("ui","language","es");volume=config.get_value("audio","volume",.65)
  muted=config.get_value("audio","muted",false);quality=config.get_value("visual","quality",true)
 TranslationServer.set_locale(language)
func change_locale(locale: String) -> void:
 language=locale;TranslationServer.set_locale(locale);hud.build()
 if not report_view.report.is_empty():report_view.rebuild()
 save_preferences()
func set_preferences(value: float,is_muted: bool,high_quality: bool,save: bool=true) -> void:
 volume=value;muted=is_muted;quality=high_quality
 audio.set_volume(volume,muted);sun.shadow_enabled=quality;actors.dust.amount=130 if quality else 36
 if save:save_preferences()
func save_preferences() -> void:
 var config=ConfigFile.new();config.set_value("ui","language",language)
 config.set_value("audio","volume",volume);config.set_value("audio","muted",muted);config.set_value("visual","quality",quality)
 config.save("user://b_preferences.cfg")
func apply_snapshot(s: Dictionary) -> void:
 state=s.duplicate(true)
 var signature=str(s.get("map_revision",0))
 if map_signature!=signature:
  terrain.configure(s.get("targets",[]),s.get("obstacles",[]));map_signature=signature
 terrain.update_targets(s.get("targets",[]));terrain.select(selected_target)
 actors.apply_state(s);hud.update_snapshot(s)
 var hour: float=s.get("hour",8.0);var daylight=maxf(0,sin((hour-6)/24*TAU))
 sun.rotation_degrees.x=-maxf(4,daylight*75);sun.light_energy=.08+daylight*1.25
 if s.get("storm",false):sun.light_energy*=.55
 environment.ambient_light_energy=.25+daylight*.4
 rig.enabled=not blocked()
 if s.get("phase","")=="landing" and not landing_in_progress and not actors.landed:
  landing_in_progress=true;actors.start_landing()
 if s.get("phase","")=="report":actors.cancel_actions()
 audio.update_state(s,not actors.route.is_empty())
func blocked() -> bool:
 return state.is_empty() or state.get("paused",false) or state.get("safe_mode",false) or state.get("phase","")!="operations"
func _command(command: String,payload: Dictionary) -> void:
 audio.unlock()
 if command=="grid":terrain.grid.visible=not terrain.grid.visible;return
 if command=="act" or command=="approach":payload["target_id"]=selected_target
 port.submit(command,payload)
func _report(value: Dictionary) -> void:
 actors.cancel_actions();rig.enabled=false;hud.visible=false;report_view.show_report(value)
func _process(_delta: float) -> void:
 if is_instance_valid(audio) and not state.is_empty():audio.update_state(state,not actors.route.is_empty())
func _unhandled_input(e: InputEvent) -> void:
 if e is InputEventMouseButton and e.pressed:audio.unlock()
 if e is InputEventKey and e.pressed and not e.echo:
  audio.unlock()
  if e.physical_keycode==KEY_F:rig.center_on(actors.rover.position)
 if blocked() or hud.settings.visible or hud.review_panel.visible:return
 if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT:
  var camera: Camera3D=rig.camera
  var point=Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(e.position),camera.project_ray_normal(e.position))
  if point==null:return
  var target=terrain.target_at(point)
  if not target.is_empty():
   selected_target=target;terrain.select(target);hud.set_target(target);port.submit("select",{"target_id":target})
  else:
   var tile=Vector2i(roundi(point.x/2),roundi(point.z/2))
   if absi(tile.x)<=11 and absi(tile.y)<=11:port.submit("move",{"tile":tile})
