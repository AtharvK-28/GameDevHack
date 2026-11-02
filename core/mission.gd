# The Sabotage Showdown's mission (decision 158): a list of steps the crew must finish in order, where the usual
# round is a quota they can fill in any order. Each step is shut until the one before it is done, so the ghost
# always knows what the crew has to do next and can stand in the way of exactly that.
# Arena-agnostic: it holds the steps and the gate between them. Each arena's props report their own step done.
class_name Mission
extends Node

signal step_done(id: String, index: int)
signal finished # Every step done: the crew has won the round.

# --- State ---
var steps: Array[Dictionary] = [] # Copies of Balance.MISSION_STEPS, each with "done".
var done_count: int = 0


func _init(from: Array[Dictionary] = []) -> void:
	for step: Dictionary in from:
		steps.append({"id": step.id, "short": step.short, "text": step.text, "done": false})


# --- Progress ---
func is_open(id: String) -> bool:
	# A step may be worked on only when it is the next one not yet done.
	return index_of(id) == done_count


func is_done(id: String) -> bool:
	var index: int = index_of(id)
	return index >= 0 and steps[index].done


func complete(id: String) -> bool:
	# Steps can only be finished in order; anything out of turn is refused, so no prop can skip the sequence.
	if not is_open(id):
		return false
	var index: int = index_of(id)
	steps[index].done = true
	done_count += 1
	print("Mission step %d of %d done: %s" % [done_count, steps.size(), steps[index].short])
	step_done.emit(id, index)
	if done_count == steps.size():
		finished.emit()
	return true


func index_of(id: String) -> int:
	for index: int in steps.size():
		if steps[index].id == id:
			return index
	return -1


func is_finished() -> bool:
	return done_count == steps.size() and not steps.is_empty()


# --- What the HUD and the phones say ---
func current() -> Dictionary:
	return steps[done_count] if done_count < steps.size() else {}


func hud_text() -> String:
	if is_finished():
		return "MISSION COMPLETE"
	var step: Dictionary = current()
	return "%d/%d  %s" % [done_count + 1, steps.size(), step.get("short", "")]


func phone_text() -> String:
	var step: Dictionary = current()
	return "Mission complete. Get clear!" if is_finished() else String(step.get("text", ""))


func state() -> Dictionary:
	# Sent to every phone so the crew can see the whole list, with the step they are on.
	var rows: Array[Dictionary] = []
	for step: Dictionary in steps:
		rows.append({"short": step.short, "done": step.done})
	return {"steps": rows, "at": done_count, "text": phone_text()}
