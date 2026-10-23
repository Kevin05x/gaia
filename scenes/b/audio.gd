extends Node
var wind: AudioStreamPlayer
var motor: AudioStreamPlayer
var radio: AudioStreamPlayer
var effect: AudioStreamPlayer
var tool_sound: AudioStreamPlayer
var landing_sound: AudioStreamPlayer
var remaining=0.0
var paused=false
var volume=.65
var muted=false
var unlocked=false
func _ready() -> void:
 wind=player(preload("res://scenes/b/assets/audio/wind.wav"),-25)
 motor=player(preload("res://scenes/b/assets/audio/motor.wav"),-28)
 radio=player(preload("res://scenes/b/assets/audio/radio.wav"),-27)
 effect=player(preload("res://scenes/b/assets/audio/confirm.wav"),-10)
 tool_sound=player(preload("res://scenes/b/assets/audio/drill.wav"),-20)
 landing_sound=player(preload("res://scenes/b/assets/audio/landing.wav"),-22)
func player(stream: AudioStream,db: float) -> AudioStreamPlayer:
 var p=AudioStreamPlayer.new();p.stream=stream;p.volume_db=db;add_child(p);return p
func unlock() -> void:
 if unlocked:return
 unlocked=true;wind.play()
func set_volume(value: float,is_muted: bool) -> void:
 volume=clampf(value,0,1);muted=is_muted
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,.0001)))
 AudioServer.set_bus_mute(0,muted)
func update_state(s: Dictionary,moving: bool) -> void:
 if not unlocked:return
 paused=s.get("paused",false)
 tool_sound.stream_paused=paused
 var descent=s.get("phase","")=="landing"
 if descent and not paused:
  if not landing_sound.playing:landing_sound.play()
 else:landing_sound.stop()
 if s.get("safe_mode",false) or s.get("phase","")=="report":remaining=0;tool_sound.stop()
 var silent=s.get("paused",false) or s.get("phase","")=="report"
 wind.volume_db=-22 if s.get("storm",false) else -32
 wind.stream_paused=silent
 if moving and not silent:
  if not motor.playing:motor.play()
 else:motor.stop()
 if s.get("transmitting",false) and not silent:
  if not radio.playing:radio.play()
 else:radio.stop()
func ping() -> void:
 if unlocked:effect.play()
func _exit_tree() -> void:
 for p in [wind,motor,radio,effect,tool_sound,landing_sound]:
  if is_instance_valid(p):p.stop();p.stream=null

func start_action(action: Dictionary) -> void:
 ping()
 remaining=float(action.get("seconds",0))
 if unlocked and action.get("action","")=="drill":tool_sound.play()
func cancel() -> void:
 remaining=0;tool_sound.stop()
func _process(delta: float) -> void:
 if not paused and remaining>0:
  remaining-=delta
  if remaining<=0:tool_sound.stop()
