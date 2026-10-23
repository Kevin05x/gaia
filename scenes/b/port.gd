extends Node
# Boundary owned by B: no simulation, GameState or autoload dependency.
signal command_requested(command: String, payload: Dictionary)
signal snapshot_received(snapshot: Dictionary)
signal report_received(report: Dictionary)
signal action_received(action: Dictionary)
signal rejected(reason_key: String)
signal cancel_received
signal path_received(points: Array, seconds_per_tile: float)
var snapshot: Dictionary={}
var connected_backend=false
func submit(command: String, payload: Dictionary={}) -> void:
 command_requested.emit(command,payload)
func apply_snapshot(value: Dictionary) -> void:
 snapshot=value.duplicate(true)
 snapshot_received.emit(snapshot)
func present_report(value: Dictionary) -> void:
 report_received.emit(value.duplicate(true))
func present_action(value: Dictionary) -> void:
 action_received.emit(value.duplicate(true))
func present_path(tiles: Array, seconds_per_tile: float=.65) -> void:
 path_received.emit(tiles.duplicate(),maxf(.01,seconds_per_tile))
func reject(reason_key: String) -> void:
 rejected.emit(reason_key)

func cancel_presentation() -> void:
 cancel_received.emit()
