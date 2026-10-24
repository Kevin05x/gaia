extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,description: String) -> void:
 if not ok:failures.append(description);push_error(description)
func run() -> void:
 var host=load("res://scenes/b/review.tscn").instantiate();root.add_child(host)
 var escape=InputEventKey.new();escape.physical_keycode=KEY_ESCAPE;escape.pressed=true
 host.view.hud._unhandled_input(escape)
 check(not host.state.paused,"Landing blocks pause shortcut")
 await create_timer(6).timeout
 check(host.state.phase=="operations","EDL unlocks operations")
 var view=host.view;var port=host.port
 check(view.actors.parts.wheels.size()==6,"Six animated wheels")
 check(view.actors.parts.solar.visible and not view.actors.parts.rtg.visible,"Solar design")
 host.command("review",{"scenario":"rtg"})
 check(not view.actors.parts.solar.visible and view.actors.parts.rtg.visible,"RTG swap")
 check(not view.actors.parts.drill.visible and not view.actors.drone.visible,"Absent instruments hidden")
 check(view.hud.buttons.drill.disabled,"Absent drill disabled")
 host.command("review",{"scenario":"solar"})
 host.command("select",{"target_id":"JZ-01"});view.selected_target="JZ-01";view.hud.set_target("JZ-01")
 host.command("approach",{"target_id":"JZ-01"})
 check(not host.moving_tiles.is_empty(),"Approach route starts")
 await create_timer(4).timeout
 check(host.moving_tiles.is_empty(),"Route completes")
 check(view.actors.rover.position.distance_to(view.actors.at_tile(host.state.rover_tile))<.1,"Visual position matches backend")
 host.command("act",{"target_id":"JZ-01","action":"drill"})
 check(host.state.busy,"Drill accepted")
 await create_timer(4.3).timeout
 check(host.state.data>=15,"Science returns from provider")
 check(not view.actors.drilling.emitting,"Drill effect stops")
 host.command("transmit",{"on":true})
 await create_timer(3).timeout
 check(host.state.sent>0,"Transmission reflected")
 host.command("act",{"target_id":"","action":"companion"})
 await create_timer(6.3).timeout
 check(host.state.mineral>=3,"Companion action completes")
 host.command("upgrade",{})
 check(view.actors.antenna_levels[1].visible,"Confirmed level two antenna")
 host.state.mineral=3;host.command("upgrade",{})
 check(view.actors.antenna_levels[2].visible,"Confirmed level three antenna")
 host.command("pause",{"paused":true})
 var hour=host.state.hour
 await create_timer(.4).timeout
 check(host.state.hour==hour and view.actors.paused,"Pause propagates")
 host.command("pause",{"paused":false})
 host.command("review",{"scenario":"storm"})
 check(view.actors.dust.emitting,"Storm particles")
 host.command("review",{"scenario":"safe"})
 check(not view.rig.enabled and view.hud.buttons.drill.disabled,"Safe mode blocks controls")
 host.command("review",{"scenario":"safe"})
 view.change_locale("en")
 check(view.hud.buttons.drill.text=="Drill & sample","English UI rebuild")
 view.change_locale("es")
 host.command("review",{"scenario":"win"})
 check(not view.report_view.report.is_empty() and not view.hud.visible,"Report consumes backend result")
 check(view.report_view.report.stars==3,"Stars passed from provider")
 port.submit("redesign")
 check(host.state.phase=="landing" and view.hud.visible,"Redesign resets view")
 await create_timer(6).timeout
 check(host.state.phase=="operations","Restart landing completes")
 # Main scene can also be loaded without any backend or autoload.
 var independent=load("res://scenes/b/mission.tscn").instantiate();root.add_child(independent)
 check(independent.port.snapshot.is_empty(),"No fake state in production view")
 port.present_action({"action":"drill","seconds":5})
 port.cancel_presentation()
 check(view.actors.active_action.is_empty(),"Backend cancellation clears effects")
 independent.queue_free();host.queue_free();await process_frame;await process_frame
 if failures.is_empty():print("INTEGRATION PASS: lifecycle, models, movement, actions, comms, antennas, pause, safe mode, ES/EN, report, redesign, independent scene")
 quit(0 if failures.is_empty() else 1)
