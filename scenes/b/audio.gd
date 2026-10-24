extends Node
## Sonido de la misión. Cada cosa que hace el rover tiene su propio sonido: rodar, taladrar, láser del espectrómetro,
## radar de subsuelo, panorámica de la cámara, dron (arranque y vuelo), compañero, estación meteorológica y transmisión
## (subida del enlace y chorro de datos). Los sonidos se sintetizan con `tools/sintetizar_sonidos.py`.
const WIND := preload("res://scenes/b/assets/audio/wind.wav")
const MOTOR := preload("res://scenes/b/assets/audio/motor.wav")
const RADIO := preload("res://scenes/b/assets/audio/radio.wav")
const CONFIRM := preload("res://scenes/b/assets/audio/confirm.wav")
const LANDING := preload("res://scenes/b/assets/audio/landing.wav")
const UPLINK := preload("res://scenes/b/assets/audio/uplink.wav")
const DRONE_START := preload("res://scenes/b/assets/audio/drone_start.wav")
## Acción -> [sonido en bucle mientras dura, volumen en dB].
const ACCIONES := {
	"drill": [preload("res://scenes/b/assets/audio/drill.wav"), -13.0],
	"spectrometer": [preload("res://scenes/b/assets/audio/laser.wav"), -15.0],
	"radar": [preload("res://scenes/b/assets/audio/radar.wav"), -13.0],
	"panorama": [preload("res://scenes/b/assets/audio/panorama.wav"), -8.0],
	"drone": [preload("res://scenes/b/assets/audio/drone.wav"), -17.0],
	"companion": [preload("res://scenes/b/assets/audio/companion.wav"), -18.0],
	"meteo": [preload("res://scenes/b/assets/audio/meteo.wav"), -18.0],
}
var wind: AudioStreamPlayer
var motor: AudioStreamPlayer
var radio: AudioStreamPlayer
var effect: AudioStreamPlayer
var tool_sound: AudioStreamPlayer
var landing_sound: AudioStreamPlayer
var uplink_sound: AudioStreamPlayer
var start_sound: AudioStreamPlayer
var remaining := 0.0
var paused := false
var volume := .65
var muted := false
var unlocked := false
var action_id := ""  ## acción que está sonando ("" si ninguna)
var _transmitting := false
var _loops: Dictionary = {}


func _ready() -> void:
	wind = player(looped(WIND), -25)
	motor = player(looped(MOTOR), -19)
	radio = player(looped(RADIO), -22)
	effect = player(CONFIRM, -10)
	tool_sound = player(null, -16)
	landing_sound = player(LANDING, -22)
	uplink_sound = player(UPLINK, -12)
	start_sound = player(DRONE_START, -14)


## Copia del sonido con repetición continua: los .wav importados no vienen en bucle.
func looped(base: AudioStreamWAV) -> AudioStreamWAV:
	if _loops.has(base):
		return _loops[base]
	var s: AudioStreamWAV = base.duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = int(s.get_length() * s.mix_rate)
	_loops[base] = s
	return s


func player(stream: AudioStream, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	add_child(p)
	return p


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	wind.play()


func set_volume(value: float, is_muted: bool) -> void:
	volume = clampf(value, 0, 1)
	muted = is_muted
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, .0001)))
	AudioServer.set_bus_mute(0, muted)


func update_state(s: Dictionary, moving: bool) -> void:
	if not unlocked:
		return
	paused = s.get("paused", false)
	tool_sound.stream_paused = paused
	var descent: bool = s.get("phase", "") == "landing"
	if descent and not paused:
		if not landing_sound.playing:
			landing_sound.play()
	else:
		landing_sound.stop()
	if s.get("safe_mode", false) or s.get("phase", "") == "report":
		cancel()
	var silent: bool = s.get("paused", false) or s.get("phase", "") == "report"
	wind.volume_db = -22 if s.get("storm", false) else -32
	wind.stream_paused = silent
	if not wind.playing and not silent:
		wind.play()
	if moving and not silent:
		if not motor.playing:
			motor.play()
	else:
		motor.stop()
	var enviando: bool = s.get("transmitting", false) and not silent
	if enviando:
		if not _transmitting:
			uplink_sound.play()  # el enlace sube: barrido ascendente al abrirse la transmisión
		if not radio.playing:
			radio.play()
	else:
		radio.stop()
	_transmitting = enviando


func ping() -> void:
	if unlocked:
		effect.play()


func _exit_tree() -> void:
	for p in [wind, motor, radio, effect, tool_sound, landing_sound, uplink_sound, start_sound]:
		if is_instance_valid(p):
			p.stop()
			p.stream = null


func start_action(action: Dictionary) -> void:
	unlock()  # la acción nace de un clic del jugador: sirve de gesto para el audio web
	ping()
	remaining = float(action.get("seconds", 0))
	var id := str(action.get("action", ""))
	if unlocked and ACCIONES.has(id):
		action_id = id
		tool_sound.stream = looped(ACCIONES[id][0])
		tool_sound.volume_db = float(ACCIONES[id][1])
		tool_sound.play()
		if id == "drone":
			start_sound.play()


func cancel() -> void:
	remaining = 0
	action_id = ""
	tool_sound.stop()
	start_sound.stop()


func _process(delta: float) -> void:
	if not paused and remaining > 0:
		remaining -= delta
		if remaining <= 0:
			action_id = ""
			tool_sound.stop()
