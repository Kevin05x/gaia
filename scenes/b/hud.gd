extends CanvasLayer
const UI=preload("res://scenes/b/ui_style.gd")
signal command(command: String,payload: Dictionary)
signal locale_changed(locale: String)
signal preferences_changed(volume: float,muted: bool,quality: bool)
var root: Control
var stats: Dictionary={}
var buttons: Dictionary={}
var snapshot: Dictionary={}
var target_id=""
var target_label: Label
var target_status: Label
var status: Label
var mission_title: Label
var mission_brief: Label
var objective: Label
var objective_bar: ProgressBar
var goals: Label
var map: Control
var hour_text: Label
var link_text: Label
var link_bar: Control
var mode: Label
var pause_button: Button
var landing: Control
var landing_text: Label
var action_bar: ProgressBar
var settings: Control
var notice: Label
var left_panel: Control
var review_panel: Control
var volume=.65
var muted=false
var quality=true
var recent_notice=""
var notice_until=0.0
var active_seconds=0.0
var active_total=0.0
var language="es"
var inspection=false
func _ready() -> void:
 build()
func build() -> void:
 if is_instance_valid(root):
  remove_child(root);root.queue_free()
 buttons.clear();stats.clear()
 root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.theme=UI.theme();add_child(root)
 var header=PanelContainer.new();root.add_child(header);header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE);header.offset_left=20;header.offset_right=-20;header.offset_top=16;header.offset_bottom=118
 var top=HBoxContainer.new();top.add_theme_constant_override("separation",26);header.add_child(top)
 var brand=VBoxContainer.new();brand.custom_minimum_size.x=190;top.add_child(brand)
 UI.label(brand,"G A I A",28,UI.ORANGE);UI.label(brand,tr("SUBTITLE"),11,UI.MUTED)
 for key in ["ENERGY","DATA","SENT"]:
  var col=VBoxContainer.new();col.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(col)
  UI.label(col,tr(key),11,UI.MUTED)
  stats[key]=UI.label(col,"—",18)
  var bar=ProgressBar.new();bar.custom_minimum_size.y=5;bar.show_percentage=false;col.add_child(bar);stats[key+"_BAR"]=bar
  if key=="ENERGY":stats["POWER"]=UI.label(col,"",11,UI.MUTED)
 var clock=VBoxContainer.new();clock.custom_minimum_size.x=180;top.add_child(clock)
 hour_text=UI.label(clock,"",16);UI.label(clock,tr("LOCATION"),11,UI.ORANGE)
 var controls=HBoxContainer.new();top.add_child(controls)
 pause_button=UI.button(controls,tr("PAUSE"),func():emit_command("pause",{"paused":not snapshot.get("paused",false)}))
 UI.button(controls,"...",func():settings.visible=not settings.visible).tooltip_text=tr("SETTINGS")
 # Left: objective and minimap; hidden only on narrow viewports.
 left_panel=VBoxContainer.new();root.add_child(left_panel)
 left_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);left_panel.position=Vector2(20,136);left_panel.size=Vector2(270,550)
 var mission=UI.panel(left_panel)
 mission_title=UI.label(mission,tr("MISSION"),17,UI.ORANGE)
 mission_brief=UI.label(mission,tr("BRIEF"),14);mission_brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 objective=UI.label(mission,"",15)
 objective_bar=ProgressBar.new();objective_bar.show_percentage=false;objective_bar.custom_minimum_size.y=7;mission.add_child(objective_bar)
 goals=UI.label(mission,"",13,UI.MUTED)
 var map_box=UI.panel(left_panel);UI.label(map_box,tr("MAP"),11,UI.MUTED)
 map=preload("res://scenes/b/minimap.gd").new();map_box.add_child(map)
 map.tile_chosen.connect(func(tile: Vector2i):emit_command("move",{"tile":tile}))
 UI.label(map_box,tr("COMPANION_NAME"),10,UI.MUTED)
 # Right operations, scrollable to remain usable at desktop sizes.
 var right=PanelContainer.new();root.add_child(right)
 right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
 right.offset_left=-308;right.offset_right=-20;right.offset_top=136;right.offset_bottom=-138
 var scroll=ScrollContainer.new();scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;right.add_child(scroll)
 var ops=VBoxContainer.new();ops.size_flags_horizontal=Control.SIZE_EXPAND_FILL;ops.add_theme_constant_override("separation",8);scroll.add_child(ops)
 UI.label(ops,tr("TARGET"),11,UI.ORANGE)
 target_label=UI.label(ops,tr("SELECT"),16);target_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 target_status=UI.label(ops,"",12,UI.MUTED)
 buttons["approach"]=UI.button(ops,tr("APPROACH"),func():emit_command("approach",{"target_id":target_id}))
 ops.add_child(HSeparator.new());UI.label(ops,tr("ACTIONS"),11,UI.MUTED)
 for action in ["panorama","spectrometer","drill","radar","drone","companion"]:
  buttons[action]=UI.button(ops,tr(action.to_upper()),_act.bind(action))
 buttons["upgrade"]=UI.button(ops,tr("UPGRADE"),func():emit_command("upgrade"))
 ops.add_child(HSeparator.new())
 stats["MINERAL"]=UI.label(ops,"",13);stats["ANTENNA"]=UI.label(ops,"",13);stats["DUST"]=UI.label(ops,"",13)
 action_bar=ProgressBar.new();action_bar.custom_minimum_size.y=6;action_bar.show_percentage=false;ops.add_child(action_bar)
 # Bottom strip uses containers rather than fixed button locations.
 var bottom=PanelContainer.new();root.add_child(bottom);bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 bottom.offset_left=20;bottom.offset_right=-20;bottom.offset_top=-122;bottom.offset_bottom=-16
 var footer=VBoxContainer.new();bottom.add_child(footer)
 var row=HBoxContainer.new();footer.add_child(row)
 var comms=VBoxContainer.new();comms.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(comms)
 UI.label(comms,tr("WINDOW"),10,UI.MUTED);link_text=UI.label(comms,"",14)
 link_bar=preload("res://scenes/b/timeline.gd").new();comms.add_child(link_bar)
 buttons["transmit"]=UI.button(row,tr("TRANSMIT"),func():emit_command("transmit",{"on":not snapshot.get("transmitting",false)}))
 UI.button(row,tr("GRID"),func():emit_command("grid"))
 UI.button(row,tr("HELP"),func():show_help())
 var info=HBoxContainer.new();footer.add_child(info)
 status=UI.label(info,"",12,UI.GREEN);status.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 mode=UI.label(info,"",10,UI.ORANGE)
 # Toast is non-interactive.
 notice=UI.label(root,"",16,UI.ORANGE);notice.position=Vector2(320,120);notice.mouse_filter=Control.MOUSE_FILTER_IGNORE
 # Landing/pause banner does not obscure the whole map.
 landing=PanelContainer.new();root.add_child(landing);landing.position=Vector2(340,150);landing.custom_minimum_size=Vector2(440,72)
 var land_col=VBoxContainer.new();landing.add_child(land_col);landing_text=UI.label(land_col,tr("LANDING"),20,UI.ORANGE);UI.label(land_col,tr("LANDING_NOTE"),13)
 build_settings();build_review()
 if not snapshot.is_empty():update_snapshot(snapshot)
func build_settings() -> void:
 settings=PanelContainer.new();root.add_child(settings);settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
 settings.offset_left=-250;settings.offset_right=250;settings.offset_top=-220;settings.offset_bottom=220
 var col=VBoxContainer.new();settings.add_child(col);col.add_theme_constant_override("separation",12)
 UI.label(col,tr("SETTINGS"),24,UI.ORANGE)
 var lang=HBoxContainer.new();col.add_child(lang);UI.label(lang,tr("LANGUAGE"),16)
 UI.button(lang,"ES",func():locale_changed.emit("es"));UI.button(lang,"EN",func():locale_changed.emit("en"))
 UI.label(col,tr("VOLUME"),14)
 var slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.01;slider.value=volume;col.add_child(slider)
 var sound_toggle=CheckButton.new();sound_toggle.text=tr("SOUND");sound_toggle.button_pressed=not muted;col.add_child(sound_toggle)
 var quality_toggle=CheckButton.new();quality_toggle.text=tr("QUALITY");quality_toggle.button_pressed=quality;col.add_child(quality_toggle)
 slider.value_changed.connect(func(value: float):volume=value;preferences_changed.emit(volume,muted,quality))
 sound_toggle.toggled.connect(func(on: bool):muted=not on;preferences_changed.emit(volume,muted,quality))
 quality_toggle.toggled.connect(func(on: bool):quality=on;preferences_changed.emit(volume,muted,quality))
 UI.label(col,tr("SAVED_SETTINGS"),12,UI.MUTED)
 UI.button(col,tr("CLOSE"),func():settings.hide());settings.hide()
func build_review() -> void:
 review_panel=PanelContainer.new();root.add_child(review_panel);review_panel.position=Vector2(330,200);review_panel.custom_minimum_size=Vector2(520,400)
 var col=VBoxContainer.new();review_panel.add_child(col)
 UI.label(col,tr("REVIEW_TITLE"),18,UI.ORANGE)
 var note=UI.label(col,tr("REVIEW_NOTE"),13);note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 for scenario in ["solar","rtg","storm","night","safe","win","lose","reset"]:
  UI.button(col,tr("R_"+scenario.to_upper()),func():emit_command("review",{"scenario":scenario}))
 UI.button(col,tr("CLOSE"),func():review_panel.hide());review_panel.hide()
func emit_command(key: String,payload: Dictionary={}) -> void:
 command.emit(key,payload)
func _act(action: String) -> void:
 emit_command("act",{"target_id":target_id,"action":action})
func set_target(id: String) -> void:
 target_id=id
 if not snapshot.is_empty():update_snapshot(snapshot)
func update_snapshot(s: Dictionary) -> void:
 snapshot=s
 var battery: Dictionary=s.get("battery",{})
 stats.ENERGY.text="%.0f / %.0f Wh"%[battery.get("wh",0),battery.get("capacity",1)]
 stats.POWER.text="+%.0f W / −%.0f W"%[battery.get("generation_w",0),battery.get("load_w",0)]
 stats.ENERGY_BAR.max_value=maxf(1,battery.get("capacity",1));stats.ENERGY_BAR.value=battery.get("wh",0)
 stats.DATA.text="%.0f / %.0f"%[s.get("data",0),s.get("memory_capacity",60)]
 stats.DATA_BAR.max_value=maxf(1,s.get("memory_capacity",60));stats.DATA_BAR.value=s.get("data",0)
 stats.SENT.text="%.0f / %.0f"%[s.get("sent",0),s.get("goal",100)]
 stats.SENT_BAR.max_value=maxf(1,s.get("goal",100));stats.SENT_BAR.value=s.get("sent",0)
 var hour: float=s.get("hour",7.0)
 hour_text.text=tr("SOL")%[s.get("sol",1),int(hour),int(fmod(hour,1)*60)]
 stats.MINERAL.text=tr("MINERAL")+"   "+str(s.get("mineral",0))
 stats.ANTENNA.text=tr("ANTENNA")%s.get("antenna_level",1)
 stats.DUST.text=tr("DUST")%int(s.get("dust",0)*100)
 mission_title.text=tr(str(s.get("chapter_title_key","MISSION")))
 mission_brief.text=tr(str(s.get("brief_key","BRIEF")))
 objective.text=tr("OBJECTIVE")%int(s.get("goal",100));objective_bar.max_value=s.get("goal",100);objective_bar.value=s.get("sent",0)
 goals.text=("[OK] " if s.get("safe_entries",0)==0 else "[--] ")+tr("NO_SAFE")+"\n"+("[OK] " if s.get("sol",1)<6 else "[--] ")+tr("EARLY")
 map.state=s;map.queue_redraw()
 var target: Dictionary={}
 for t in s.get("targets",[]):
  if str(t.id)==target_id:target=t;break
 target_label.text=tr("SELECT") if target.is_empty() else tr({"rock":"ROCK","mineral":"MINERAL_TARGET","buried":"BURIED"}.get(target.get("type","rock"),"ROCK"))+" · "+target_id
 target_status.text="" if target.is_empty() else tr("DEPLETED" if target.get("depleted",false) else "AVAILABLE")
 var blocked=s.get("paused",false) or s.get("safe_mode",false) or s.get("phase","") in ["landing","report"]
 for key in buttons:
  var availability: Dictionary=s.get("available_actions",{}).get(key,{"enabled":false,"reason":"WAIT"})
  buttons[key].disabled=blocked or not availability.get("enabled",false)
  buttons[key].tooltip_text=tr(str(availability.get("reason","")))
  if key in ["drill","spectrometer","approach"] and target.is_empty():buttons[key].disabled=true;buttons[key].tooltip_text=tr("NO_TARGET")
 buttons.transmit.text=tr("STOP_TRANSMIT") if s.get("transmitting",false) else tr("TRANSMIT")
 pause_button.text=tr("RESUME") if s.get("paused",false) else tr("PAUSE")
 pause_button.disabled=s.get("phase","") in ["landing","report"]
 link_text.text=tr("RELAY" if s.get("design",{}).get("comms","relay")=="relay" else "DIRECT")+" · "+tr("OPEN" if s.get("link_open",false) else "CLOSED")
 link_bar.hour=hour;link_bar.windows=s.get("comms_windows",[]);link_bar.queue_redraw()
 var state_key="READY"
 if s.get("moving",false):state_key="MOVING"
 if s.get("busy",false):state_key="BUSY"
 if s.get("storm",false):state_key="STORM"
 if s.get("safe_mode",false):state_key="SAFE"
 if s.get("paused",false):state_key="PAUSED"
 status.text=tr(state_key)
 if s.get("storm_in",-1.0)>0 and state_key=="READY":status.text=tr("STORM_WARNING")%s.storm_in
 mode.text=tr("INSPECTION" if inspection else ("LIVE" if not snapshot.is_empty() else "WAIT"))
 landing.visible=s.get("phase","")=="landing"
func show_notice(key: String) -> void:
 recent_notice=key;notice_until=Time.get_ticks_msec()/1000.0+4
 notice.text=tr(key)
func start_action(a: Dictionary) -> void:
 active_seconds=0;active_total=maxf(.1,a.get("seconds",1))
func show_help() -> void:
 show_notice("HELP_TEXT")
 notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notice.custom_minimum_size.x=520
func _process(delta: float) -> void:
 if Time.get_ticks_msec()/1000.0>notice_until:notice.text=""
 if not snapshot.get("paused",false):active_seconds+=delta
 action_bar.value=clampf(active_seconds/maxf(.1,active_total)*100,0,100) if active_total>0 else 0
 mode.text=tr("INSPECTION" if inspection else ("LIVE" if not snapshot.is_empty() else "WAIT"))+" · "+tr("FPS")%Engine.get_frames_per_second()
 left_panel.visible=get_viewport().get_visible_rect().size.x>=1100
 get_parent().rig.enabled=not get_parent().blocked() and not settings.visible and not review_panel.visible
func _unhandled_input(e: InputEvent) -> void:
 if e is InputEventKey and e.pressed and not e.echo:
  var hotkeys={KEY_C:"panorama",KEY_V:"radar",KEY_X:"companion",KEY_T:"transmit"}
  if not settings.visible and not review_panel.visible and hotkeys.has(e.physical_keycode):
   var id=hotkeys[e.physical_keycode]
   if not buttons[id].disabled:buttons[id].pressed.emit()
   get_viewport().set_input_as_handled()
  if e.physical_keycode==KEY_F2 and inspection:review_panel.visible=not review_panel.visible;get_viewport().set_input_as_handled()
  if e.physical_keycode==KEY_ESCAPE:
   if settings.visible:settings.hide()
   elif review_panel.visible:review_panel.hide()
   else:emit_command("pause",{"paused":not snapshot.get("paused",false)})
   get_viewport().set_input_as_handled()
