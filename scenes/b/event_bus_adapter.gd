extends Node
# Optional adapter for the document's original EventBus. Owned by B.
# A must first supply a full snapshot with available_actions and map definitions.
var port: Node
var bus: Node
var connections: Array=[]
var current: Dictionary={}
func bind(target_port: Node,event_bus: Node,initial_snapshot: Dictionary) -> void:
 unbind();port=target_port;bus=event_bus;current=initial_snapshot.duplicate(true)
 connect_if("snapshot_changed",_snapshot)
 connect_if("sol_advanced",_sol)
 connect_if("battery_changed",_battery)
 connect_if("data_changed",_data)
 connect_if("storm_changed",_storm)
 connect_if("storm_warned",_warning)
 connect_if("safe_mode",_safe)
 connect_if("rover_path",_path)
 connect_if("action_started",_action)
 connect_if("target_revealed",_reveal)
 connect_if("mission_ended",_report)
 connect_if("command_rejected",_reject)
 port.command_requested.connect(_command);port.connected_backend=true
 if not current.is_empty():port.apply_snapshot(current)
func connect_if(signal_name: String,callback: Callable) -> void:
 if bus.has_signal(signal_name):bus.connect(signal_name,callback);connections.append([signal_name,callback])
func unbind() -> void:
 if is_instance_valid(bus):
  for c in connections:
   if bus.is_connected(c[0],c[1]):bus.disconnect(c[0],c[1])
 connections.clear()
 if is_instance_valid(port) and port.command_requested.is_connected(_command):port.command_requested.disconnect(_command)
func _exit_tree() -> void:unbind()
func send(name: String,args: Array=[]) -> void:
 if not is_instance_valid(bus) or not bus.has_signal(name):port.reject("WAIT");return
 bus.callv("emit_signal",[name]+args)
func _command(cmd: String,p: Dictionary) -> void:
 match cmd:
  "move":send("cmd_move_rover",[p.tile])
  "approach":send("cmd_approach_target",[p.target_id])
  "select":send("cmd_select_target",[p.target_id])
  "act":send("cmd_act",[p.get("target_id",""),p.action])
  "transmit":send("cmd_transmit",[p.on])
  "upgrade":send("cmd_upgrade_antenna")
  "pause":send("cmd_pause",[p.paused])
  "redesign":send("cmd_redesign")
  "landing_finished":send("cmd_landing_finished")
func _snapshot(s: Dictionary) -> void:current=s.duplicate(true);port.apply_snapshot(current)
func flush() -> void:
 if not current.is_empty():port.apply_snapshot(current)
func _sol(sol: int,hour: float) -> void:current.sol=sol;current.hour=hour;flush()
func _battery(wh: float,capacity: float,generation: float,load_w: float) -> void:
 current.battery={"wh":wh,"capacity":capacity,"generation_w":generation,"load_w":load_w};flush()
func _data(board: float,sent: float) -> void:current.data=board;current.sent=sent;flush()
func _storm(active: bool,dust: float) -> void:current.storm=active;current.dust=dust;flush()
func _warning(left: float) -> void:current.storm_in=left;flush()
func _safe(active: bool) -> void:current.safe_mode=active;flush()
func _path(tiles: Array[Vector2i]) -> void:port.present_path(tiles,float(current.get("seconds_per_tile",.65)))
func _action(id: String,action: String,seconds: float) -> void:port.present_action({"target_id":id,"action":action,"seconds":seconds})
func _reveal(id: String) -> void:
 for t in current.get("targets",[]):
  if t.id==id:t.revealed=true
 flush()
func _report(value: Dictionary) -> void:current.phase="report";flush();port.present_report(value)
func _reject(key: String) -> void:port.reject(key)
