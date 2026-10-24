extends Node
# QA fixture only. A replaces this node with its own simulation, not MissionView.
var view: Node3D
var port: Node
var state: Dictionary={}
var selected=""
var moving_tiles: Array=[]
var move_clock=0.0
var busy_clock=0.0
var pending: Dictionary={}
var publish_clock=0.0
var real_clock=0.0
var used_drone_sol=0
const STEP=.65
const COST={"panorama":25.0,"spectrometer":40.0,"drill":120.0,"radar":35.0,"drone":60.0,"companion":15.0}
const DURATION={"panorama":2.5,"spectrometer":3.0,"drill":4.0,"radar":3.0,"drone":8.0,"companion":6.0}
func _ready() -> void:
 view=preload("res://scenes/b/mission.tscn").instantiate();view.inspection=true;add_child(view)
 port=view.get_node("Port");port.connected_backend=true;port.command_requested.connect(command)
 reset()
func reset() -> void:
 state={"phase":"landing","paused":false,"sol":1,"hour":8.0,"rover_tile":Vector2i.ZERO,
 "battery":{"wh":1000.0,"capacity":1000.0,"generation_w":110.0,"load_w":15.0},
 "design":{"power":"solar","comms":"relay","instruments":["panorama","spectrometer","drill","radar","meteo","drone"],"companion":true},
 "data":0.0,"memory_capacity":60.0,"sent":0.0,"goal":100,"mineral":0,"antenna_level":1,
 "dust":.06,"storm":false,"storm_in":2.0,"safe_mode":false,"safe_entries":0,
 "transmitting":false,"link_open":false,"moving":false,"busy":false,"map_revision":Time.get_ticks_usec(),
 "targets":[
 {"id":"JZ-01","tile":Vector2i(2,-2),"type":"rock","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-02","tile":Vector2i(-3,-2),"type":"rock","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-03","tile":Vector2i(5,-4),"type":"rock","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-04","tile":Vector2i(-5,3),"type":"rock","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-05","tile":Vector2i(-2,-6),"type":"buried","revealed":false,"depleted":false,"done":[]},
 {"id":"JZ-06","tile":Vector2i(6,2),"type":"mineral","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-07","tile":Vector2i(-6,-5),"type":"buried","revealed":false,"depleted":false,"done":[]},
 {"id":"JZ-08","tile":Vector2i(1,6),"type":"rock","revealed":true,"depleted":false,"done":[]},
 {"id":"JZ-09","tile":Vector2i(7,-1),"type":"mineral","revealed":false,"depleted":false,"done":[]}],
 "obstacles":[Vector2i(-1,-2),Vector2i(-2,-2),Vector2i(4,-1),Vector2i(4,0),Vector2i(4,1),Vector2i(-3,3),Vector2i(-4,3),Vector2i(0,4),Vector2i(1,4),Vector2i(6,-6)]}
 moving_tiles.clear();pending.clear();busy_clock=0;selected="";real_clock=0;used_drone_sol=0
 view.actors.cancel_actions();view.actors.landed=false;view.actors.landing_active=false
 view.report_view.clear();view.hud.visible=true;view.selected_target="";view.hud.set_target("")
 publish()
func target() -> Dictionary:
 for t in state.targets:
  if t.id==selected:return t
 return {}
func availability(action: String) -> Dictionary:
 var reason=""
 var t=target()
 if state.phase!="operations":reason="LANDING" if state.phase=="landing" else "MISSION_END"
 elif state.paused:reason="PAUSED"
 elif state.safe_mode:reason="SAFE"
 elif state.moving:reason="MOVING"
 elif state.busy:reason="BUSY"
 elif action in ["approach","spectrometer","drill"] and t.is_empty():reason="NO_TARGET"
 elif action in COST and action not in ["companion"] and action not in state.design.instruments:reason="NO_INSTRUMENT"
 elif action in COST and state.battery.wh<float(COST[action]):reason="LOW_ENERGY"
 elif action in ["spectrometer","drill"] and maxi(absi(state.rover_tile.x-t.tile.x),absi(state.rover_tile.y-t.tile.y))>1:reason="TOO_FAR"
 elif action in ["spectrometer","drill"] and action in t.get("done",[]):reason="DEPLETED"
 elif action in ["spectrometer","drill"] and state.data+(15 if action=="drill" else 8)>state.memory_capacity:reason="MEMORY_FULL"
 elif action=="drone" and state.storm:reason="WEATHER"
 elif action=="drone" and (state.hour<6 or state.hour>18):reason="NIGHT"
 elif action=="drone" and used_drone_sol==state.sol:reason="FLIGHT_USED"
 elif action=="upgrade" and state.antenna_level>=3:reason="MAX_LEVEL"
 elif action=="upgrade" and state.mineral<3:reason="NO_MINERAL"
 elif action=="transmit" and not state.transmitting and not state.link_open:reason="NO_LINK"
 elif action=="transmit" and not state.transmitting and state.data<=0:reason="NO_DATA"
 return {"enabled":reason.is_empty(),"reason":reason}
func publish() -> void:
 state.moving=not moving_tiles.is_empty();state.busy=not pending.is_empty()
 state.link_open=(state.hour>=6 and state.hour<18) if state.design.comms=="direct" else ((state.hour>=8 and state.hour<11) or (state.hour>=17 and state.hour<20))
 if not state.link_open:state.transmitting=false
 var actions={}
 for action in ["approach","panorama","spectrometer","drill","radar","drone","companion","upgrade","transmit"]:actions[action]=availability(action)
 state.available_actions=actions
 state.comms_windows=[[6,18]] if state.design.comms=="direct" else [[8,11],[17,20]]
 port.apply_snapshot(state)
func command(cmd: String,p: Dictionary) -> void:
 match cmd:
  "landing_finished":state.phase="operations";view.hud.show_notice("READY")
  "select":selected=p.get("target_id","")
  "move":
   if state.phase=="operations" and not state.paused and not state.safe_mode and not state.busy and not state.moving:move(p.get("tile",Vector2i.ZERO))
  "approach":
   if not check("approach"):return
   var t=target();var best: Vector2i=state.rover_tile;var dist=100000
   for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
    var tile: Vector2i=t.tile+d
    if tile in state.obstacles:continue
    var v=state.rover_tile.distance_squared_to(tile)
    if v<dist:dist=v;best=tile
   move(best)
  "act":
   selected=p.get("target_id",selected)
   var action=str(p.get("action",""))
   if not COST.has(action) or not check(action):return
   state.battery.wh-=COST[action];pending={"action":action,"target_id":selected,"seconds":DURATION[action]};busy_clock=0
   port.present_action(pending)
   if action=="drone":used_drone_sol=state.sol
  "transmit":
   if p.get("on",false) and not check("transmit"):return
   state.transmitting=p.get("on",false)
  "upgrade":
   if not check("upgrade"):return
   state.mineral-=3;state.antenna_level+=1;view.audio.ping()
  "pause":state.paused=p.get("paused",false)
  "redesign":reset();return
  "review":review(str(p.get("scenario","")));return
 publish()
func check(action: String) -> bool:
 var available=availability(action)
 if not available.enabled:port.reject(available.reason);return false
 return true
func move(destination: Vector2i) -> void:
 if absi(destination.x)>11 or absi(destination.y)>11 or destination in state.obstacles:return
 var grid=AStarGrid2D.new();grid.region=Rect2i(-11,-11,23,23);grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
 for tile in state.obstacles:grid.set_point_solid(tile,true)
 var path=grid.get_id_path(state.rover_tile,destination)
 if path.size()<2:return
 path.pop_front()
 var cost=path.size()*18.0
 if state.battery.wh<cost:port.reject("LOW_ENERGY");return
 state.battery.wh-=cost;moving_tiles.assign(path);move_clock=0;port.present_path(path,STEP)
func _process(delta: float) -> void:
 if state.is_empty() or state.paused or state.phase!="operations":return
 real_clock+=delta;state.hour+=delta*.035
 if state.hour>=24:
  state.hour-=24;state.sol+=1
  if "meteo" in state.design.instruments:state.data=minf(state.memory_capacity,state.data+2)
 if state.sol>=7:finish(false);return
 if state.sol>=3 and state.sol<4:state.storm=true
 elif state.sol>=4:state.storm=false
 state.storm_in=maxf(0,3-state.sol-state.hour/24.0)
 var solar=state.design.power=="solar"
 var gen=140*maxf(0,sin((state.hour-6)/24*TAU))*(1-state.dust)*(.15 if state.storm else 1) if solar else 110.0
 var load=15.0+(30.0 if solar else 10.0) if state.hour<6 or state.hour>18 else 15.0
 state.battery.generation_w=gen;state.battery.load_w=load
 state.battery.wh=clampf(state.battery.wh+(gen-load)*delta*.035,0,state.battery.capacity)
 if state.battery.wh<=0 and not state.safe_mode:
  state.safe_mode=true;state.safe_entries+=1;moving_tiles.clear();pending.clear();state.transmitting=false;view.actors.cancel_actions()
  if state.safe_entries>=2:finish(false);return
 if state.safe_mode and state.battery.wh>=state.battery.capacity*.25:state.safe_mode=false
 if not moving_tiles.is_empty():
  move_clock+=delta
  if move_clock>=STEP:move_clock-=STEP;state.rover_tile=moving_tiles.pop_front()
 if not pending.is_empty():
  busy_clock+=delta
  if busy_clock>=pending.seconds:complete_action()
 if state.transmitting and state.link_open and not state.safe_mode:
  var amount=minf(state.data,delta*(6 if state.design.comms=="relay" else 1)*state.antenna_level)
  amount=minf(amount,state.battery.wh/(1 if state.design.comms=="relay" else 3))
  state.data-=amount;state.sent+=amount;state.battery.wh-=amount*(1 if state.design.comms=="relay" else 3)
  if state.data<=0:state.transmitting=false
  if state.sent>=state.goal:finish(true);return
 publish_clock+=delta
 if publish_clock>=.15:publish_clock=0;publish()
func complete_action() -> void:
 var action=str(pending.action)
 if action in ["drill","spectrometer"]:
  for t in state.targets:
   if t.id==pending.target_id:
    t.done.append(action);t.depleted="drill" in t.done and "spectrometer" in t.done
    state.data=minf(state.memory_capacity,state.data+(20 if action=="drill" and t.type=="buried" else (15 if action=="drill" else 8)))
    if t.type=="mineral":state.mineral+=1
 elif action in ["radar","panorama","drone"]:
  for t in state.targets:
   if action=="radar" and t.type!="buried":continue
   t.revealed=true
 elif action=="companion":state.mineral+=3
 pending.clear();view.hud.show_notice("ACTION_DONE")
func finish(success: bool) -> void:
 state.phase="report";state.transmitting=false;moving_tiles.clear();pending.clear();publish()
 var causes=["CAUSE_SUCCESS" if success else "CAUSE_FAIL","CAUSE_SOLAR" if state.design.power=="solar" else "CAUSE_RTG","CAUSE_RELAY"]
 if state.safe_entries>0:causes.append("CAUSE_SAFE")
 var stars=(1+int(state.safe_entries==0)+int(state.sol<6)) if success else 0
 port.present_report({"success":success,"stars":stars,"sent":int(state.sent),"goal":state.goal,"sol":state.sol,"causes":causes})
func review(scenario: String) -> void:
 match scenario:
  "solar":state.design.power="solar";state.design.instruments=["panorama","drill","radar","drone","meteo","spectrometer"]
  "rtg":state.design.power="rtg";state.design.instruments=["panorama","spectrometer","meteo"]
  "storm":state.storm=not state.storm
  "night":state.hour=22.0 if state.hour<18 else 9.0
  "safe":state.safe_mode=not state.safe_mode;moving_tiles.clear();pending.clear();view.actors.cancel_actions()
  "win":state.sent=100;finish(true);return
  "lose":finish(false);return
  "reset":reset();return
 publish()
