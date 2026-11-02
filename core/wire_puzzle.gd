# The wire puzzle (decision 158): the Mansion mission's third step, played on one mover's phone while they stand
# at the fuse box. Four colours down each side, shuffled, joined by tapping one then its match. It is deliberately
# short, five to eight seconds for a competent thumb, because the whole point is the moment it creates: a player
# looking at their hands instead of the big screen, standing still, with the ghost loose behind them.
# Walking away from the box drops the puzzle and loses the joins, so it cannot be solved from safety.
class_name WirePuzzle
extends RefCounted

# --- State ---
var left: Array[int] = [] # Colour index down the left side, top to bottom.
var right: Array[int] = [] # The same colours, shuffled, down the right.
var joined: Array[int] = [] # For each left pin, the right pin it is wired to, or -1.
var slot: int = -1 # The mover playing it.
var open: bool = false


func start(for_slot: int, round_seed: int) -> void:
	# Seeded from the round, so a restart gives the same puzzle and a rerun of a check is repeatable.
	var random := RandomNumberGenerator.new()
	random.seed = round_seed + Balance.MISSION_WIRE_SEED_OFFSET
	left.clear()
	right.clear()
	joined.clear()
	for index: int in Balance.MISSION_WIRE_PAIRS:
		left.append(index)
		right.append(index)
		joined.append(-1)
	_shuffle(left, random)
	_shuffle(right, random)
	slot = for_slot
	open = true


func stop() -> void:
	open = false
	slot = -1


func join(left_pin: int, right_pin: int) -> bool:
	# A join sticks only when the two pins are the same colour and neither is already wired.
	if not open or left_pin < 0 or left_pin >= left.size() or right_pin < 0 or right_pin >= right.size():
		return false
	if joined[left_pin] != -1 or right_pin in joined:
		return false
	if left[left_pin] != right[right_pin]:
		return false
	joined[left_pin] = right_pin
	return true


func is_solved() -> bool:
	return open and not joined.has(-1)


func state() -> Dictionary:
	# What the phone draws: the two columns of colours and the joins made so far.
	var colours: Array[String] = Balance.MISSION_WIRE_COLOURS
	var left_colours: Array[String] = []
	var right_colours: Array[String] = []
	for index: int in left.size():
		left_colours.append(colours[left[index] % colours.size()])
		right_colours.append(colours[right[index] % colours.size()])
	return {"left": left_colours, "right": right_colours, "joined": joined.duplicate()}


func _shuffle(order: Array[int], random: RandomNumberGenerator) -> void:
	for index: int in range(order.size() - 1, 0, -1):
		var pick: int = random.randi_range(0, index)
		var held: int = order[index]
		order[index] = order[pick]
		order[pick] = held
