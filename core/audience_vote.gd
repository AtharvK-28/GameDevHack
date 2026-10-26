# The audience vote: every VOTE_INTERVAL seconds of live play, audience phones get three options for VOTE_SECONDS.
# One vote per phone (the latest counts); the most votes wins, ties go to chaos, and no votes means nothing happens.
# Main carries out the winner. The HUD reads this node's state to draw the vote card.
class_name AudienceVote
extends Node

# --- Vote state ---
var host: Node3D # Main, which applies the winner.
var open: bool = false
var left: float = 0.0 # Seconds until this vote closes.
var next_left: float = Balance.VOTE_INTERVAL # Seconds of live play until the next vote opens.
var votes: Dictionary = {} # Audience pid -> option index.
var winner: int = -1 # The last vote's winning option, shown for VOTE_RESULT_SECONDS.
var result_left: float = 0.0

# --- Setup ---
func _ready() -> void:
	Net.voted.connect(_on_voted)
	Game.changed.connect(_on_game_changed)


func _process(delta: float) -> void:
	result_left = maxf(0.0, result_left - delta)
	if Game.phase != "live" or Net.audience_count() == 0:
		return
	if open:
		left -= delta
		if left <= 0.0:
			close_vote()
		return
	next_left -= delta
	if next_left <= 0.0:
		open_vote()


# --- Opening and closing ---
func open_vote() -> void:
	open = true
	left = Balance.VOTE_SECONDS
	votes.clear()
	Net.send_to_audience({"type": "vote", "open": true, "options": Balance.VOTE_OPTIONS, "left": ceili(left)})
	print("Audience vote open")


func close_vote() -> void:
	open = false
	next_left = Balance.VOTE_INTERVAL
	var counts: Array[int] = tally()
	winner = -1
	var best: int = 0
	for index: int in range(counts.size()):
		var chaos: bool = Balance.VOTE_OPTIONS[index].id == "chaos"
		if counts[index] > best or (counts[index] == best and best > 0 and chaos):
			best = counts[index]
			winner = index
	result_left = Balance.VOTE_RESULT_SECONDS
	var label: String = Balance.VOTE_OPTIONS[winner].label if winner >= 0 else ""
	Net.send_to_audience({"type": "vote", "open": false, "winner": winner, "label": label})
	if winner >= 0:
		print("The audience chose %s" % label)
		host.apply_audience_choice(Balance.VOTE_OPTIONS[winner].id)


func tally() -> Array[int]:
	var counts: Array[int] = []
	counts.resize(Balance.VOTE_OPTIONS.size())
	for option: int in votes.values():
		counts[option] += 1
	return counts


# --- Events ---
func _on_voted(pid: String, option: int) -> void:
	if open:
		votes[pid] = option # Changing your mind is fine; only your latest vote counts.


func _on_game_changed() -> void:
	if Game.phase in ["reveal", "lobby"]:
		open = false
		next_left = Balance.VOTE_INTERVAL
		result_left = 0.0
