# Minimal QR code encoder for the lobby's join link: byte mode, error correction level M, versions 1–6
# (up to 106 characters). Follows ISO/IEC 18004: Reed–Solomon over GF(256), zigzag placement, masking and
# BCH-coded format bits. encode() returns rows of 0/1 modules; to_image() turns them into a scannable picture.
class_name QrCode
extends RefCounted

# --- Code structure for level M, by version 1–6 ---
const TOTAL_CODEWORDS: Array[int] = [26, 44, 70, 100, 134, 172]
const BLOCK_COUNTS: Array[int] = [1, 1, 1, 2, 2, 4]
const EC_PER_BLOCK: Array[int] = [10, 16, 26, 18, 24, 16]
const MAX_VERSION: int = 6

# --- Format and encoding constants ---
const LEVEL_M_BITS: int = 0 # Two-bit error-correction level field: L 1, M 0, Q 3, H 2.
const FORMAT_GENERATOR: int = 0x537 # BCH(15, 5) generator for the format bits.
const FORMAT_MASK: int = 0x5412
const FIELD_POLYNOMIAL: int = 0x11D # GF(256) reduction polynomial.
const BYTE_MODE: int = 0b0100
const PAD_BYTES: Array[int] = [0xEC, 0x11]
const PENALTY_RUN: int = 3 # Rule 1: five-in-a-row costs 3, plus 1 per extra module.
const PENALTY_BLOCK: int = 3 # Rule 2: each 2 × 2 single-colour block.
const PENALTY_BALANCE: int = 10 # Rule 4: per 5% away from half dark.

# --- Matrix state while encoding ---
var size: int = 0
var modules: Array[PackedByteArray] = []
var is_function: Array[PackedByteArray] = []

# --- Public helpers ---
static func encode(text: String) -> Array[PackedByteArray]:
	# The smallest version that fits, with the mask that scores best; empty when the text is too long.
	var data: PackedByteArray = text.to_utf8_buffer()
	for version: int in range(1, MAX_VERSION + 1):
		var capacity: int = TOTAL_CODEWORDS[version - 1] - BLOCK_COUNTS[version - 1] * EC_PER_BLOCK[version - 1]
		if 4 + 8 + data.size() * 8 <= capacity * 8:
			var best: Array[PackedByteArray] = []
			var best_penalty: int = -1
			for mask: int in range(8):
				var code := QrCode.new()
				code._build(data, version, mask)
				var penalty: int = code._penalty()
				if best_penalty < 0 or penalty < best_penalty:
					best = code.modules
					best_penalty = penalty
			return best
	return []


static func encode_with(text: String, version: int, mask: int) -> Array[PackedByteArray]:
	# A fixed version and mask, used to compare against a reference encoder.
	var code := QrCode.new()
	code._build(text.to_utf8_buffer(), version, mask)
	return code.modules


static func to_image(matrix: Array[PackedByteArray], module_pixels: int, quiet_modules: int) -> Image:
	# Dark modules on white, with a quiet zone around them so phones can find the code.
	var side: int = (matrix.size() + quiet_modules * 2) * module_pixels
	var image := Image.create(side, side, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	for row: int in range(matrix.size()):
		for column: int in range(matrix.size()):
			if matrix[row][column] == 1:
				var origin: int = quiet_modules * module_pixels
				image.fill_rect(Rect2i(origin + column * module_pixels, origin + row * module_pixels, module_pixels, module_pixels), Color.BLACK)
	return image


# --- Building one symbol ---
func _build(data: PackedByteArray, version: int, mask: int) -> void:
	size = 17 + version * 4
	for row: int in range(size):
		var blank := PackedByteArray()
		blank.resize(size)
		modules.append(blank)
		is_function.append(blank.duplicate())
	_draw_function_patterns(version)
	_draw_codewords(_interleave(_data_codewords(data, version), version))
	_apply_mask(mask)
	_draw_format_bits(mask)


func _data_codewords(data: PackedByteArray, version: int) -> PackedByteArray:
	# Mode, length, the bytes, a terminator, then padding up to the version's data capacity.
	var capacity_bits: int = (TOTAL_CODEWORDS[version - 1] - BLOCK_COUNTS[version - 1] * EC_PER_BLOCK[version - 1]) * 8
	var bits: Array[int] = []
	_append_bits(bits, BYTE_MODE, 4)
	_append_bits(bits, data.size(), 8)
	for value: int in data:
		_append_bits(bits, value, 8)
	_append_bits(bits, 0, mini(4, capacity_bits - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var codewords := PackedByteArray()
	for start: int in range(0, bits.size(), 8):
		var value: int = 0
		for offset: int in range(8):
			value = (value << 1) | bits[start + offset]
		codewords.append(value)
	var pad: int = 0
	while codewords.size() * 8 < capacity_bits:
		codewords.append(PAD_BYTES[pad % 2])
		pad += 1
	return codewords


func _interleave(data: PackedByteArray, version: int) -> PackedByteArray:
	# Split into equal blocks (true for every level-M version up to 6), add each block's error correction,
	# then take one codeword from each block in turn: data first, then error correction.
	var block_count: int = BLOCK_COUNTS[version - 1]
	var ec_length: int = EC_PER_BLOCK[version - 1]
	var data_length: int = data.size() / block_count
	var divisor: PackedByteArray = _rs_divisor(ec_length)
	var data_blocks: Array[PackedByteArray] = []
	var ec_blocks: Array[PackedByteArray] = []
	for block: int in range(block_count):
		var block_data: PackedByteArray = data.slice(block * data_length, (block + 1) * data_length)
		data_blocks.append(block_data)
		ec_blocks.append(_rs_remainder(block_data, divisor))
	var result := PackedByteArray()
	for index: int in range(data_length):
		for block: int in range(block_count):
			result.append(data_blocks[block][index])
	for index: int in range(ec_length):
		for block: int in range(block_count):
			result.append(ec_blocks[block][index])
	return result


# --- Function patterns ---
func _draw_function_patterns(version: int) -> void:
	for index: int in range(size):
		_set_function(6, index, index % 2 == 0)
		_set_function(index, 6, index % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(3, size - 4)
	_draw_finder(size - 4, 3)
	if version >= 2:
		_draw_alignment(size - 7, size - 7) # Versions 2–6 have one, opposite the top-left finder.
	_draw_format_bits(0) # Reserve the format areas; the real bits are drawn after masking.


func _draw_finder(centre_row: int, centre_column: int) -> void:
	# Seven-module square rings, plus the light separator around them.
	for row_offset: int in range(-4, 5):
		for column_offset: int in range(-4, 5):
			var row: int = centre_row + row_offset
			var column: int = centre_column + column_offset
			if row < 0 or row >= size or column < 0 or column >= size:
				continue
			var ring: int = maxi(absi(row_offset), absi(column_offset))
			_set_function(row, column, ring != 2 and ring != 4)


func _draw_alignment(centre_row: int, centre_column: int) -> void:
	for row_offset: int in range(-2, 3):
		for column_offset: int in range(-2, 3):
			_set_function(centre_row + row_offset, centre_column + column_offset, maxi(absi(row_offset), absi(column_offset)) != 1)


func _draw_format_bits(mask: int) -> void:
	# Five data bits (level and mask) plus ten BCH bits, masked, drawn twice.
	var value: int = (LEVEL_M_BITS << 3) | mask
	var remainder: int = value
	for step: int in range(10):
		remainder = (remainder << 1) ^ ((remainder >> 9) * FORMAT_GENERATOR)
	var bits: int = ((value << 10) | remainder) ^ FORMAT_MASK
	for index: int in range(6):
		_set_function(index, 8, _bit(bits, index))
	_set_function(7, 8, _bit(bits, 6))
	_set_function(8, 8, _bit(bits, 7))
	_set_function(8, 7, _bit(bits, 8))
	for index: int in range(9, 15):
		_set_function(8, 14 - index, _bit(bits, index))
	for index: int in range(8):
		_set_function(8, size - 1 - index, _bit(bits, index))
	for index: int in range(8, 15):
		_set_function(size - 15 + index, 8, _bit(bits, index))
	_set_function(size - 8, 8, true) # The dark module.


# --- Data placement and masking ---
func _draw_codewords(codewords: PackedByteArray) -> void:
	# Two-module columns, zigzagging up and down from the bottom right, skipping the vertical timing column.
	var bit_index: int = 0
	var right: int = size - 1
	while right >= 1:
		if right == 6:
			right = 5
		var upward: bool = ((right + 1) & 2) == 0
		for step: int in range(size):
			var row: int = size - 1 - step if upward else step
			for offset: int in range(2):
				var column: int = right - offset
				if is_function[row][column] == 0 and bit_index < codewords.size() * 8:
					modules[row][column] = (codewords[bit_index >> 3] >> (7 - (bit_index & 7))) & 1
					bit_index += 1
		right -= 2


func _apply_mask(mask: int) -> void:
	for row: int in range(size):
		for column: int in range(size):
			if is_function[row][column] == 0 and _mask_hits(mask, row, column):
				modules[row][column] ^= 1


static func _mask_hits(mask: int, row: int, column: int) -> bool:
	match mask:
		0: return (row + column) % 2 == 0
		1: return row % 2 == 0
		2: return column % 3 == 0
		3: return (row + column) % 3 == 0
		4: return (row / 2 + column / 3) % 2 == 0
		5: return (row * column) % 2 + (row * column) % 3 == 0
		6: return ((row * column) % 2 + (row * column) % 3) % 2 == 0
		_: return ((row + column) % 2 + (row * column) % 3) % 2 == 0


func _penalty() -> int:
	# Rules 1, 2 and 4 of the standard's mask scoring; enough to avoid badly blotchy masks.
	var score: int = 0
	for line: int in range(size):
		score += _run_penalty(line, true) + _run_penalty(line, false)
	var dark: int = 0
	for row: int in range(size):
		for column: int in range(size):
			dark += modules[row][column]
			if row < size - 1 and column < size - 1:
				var colour: int = modules[row][column]
				if colour == modules[row][column + 1] and colour == modules[row + 1][column] and colour == modules[row + 1][column + 1]:
					score += PENALTY_BLOCK
	var total: int = size * size
	score += (absi(dark * 20 - total * 10) + total - 1) / total * PENALTY_BALANCE
	return score


func _run_penalty(line: int, horizontal: bool) -> int:
	var score: int = 0
	var run: int = 0
	var colour: int = -1
	for index: int in range(size):
		var value: int = modules[line][index] if horizontal else modules[index][line]
		if value == colour:
			run += 1
			if run == 5:
				score += PENALTY_RUN
			elif run > 5:
				score += 1
		else:
			colour = value
			run = 1
	return score


# --- Reed–Solomon over GF(256) ---
static func _rs_divisor(degree: int) -> PackedByteArray:
	# Coefficients of (x − α⁰)(x − α¹)…(x − α^(degree−1)), highest power first, leading 1 omitted.
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root: int = 1
	for step: int in range(degree):
		for index: int in range(degree):
			result[index] = _gf_multiply(result[index], root)
			if index + 1 < degree:
				result[index] ^= result[index + 1]
		root = _gf_multiply(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for value: int in data:
		var factor: int = value ^ result[0]
		result.remove_at(0)
		result.append(0)
		for index: int in range(result.size()):
			result[index] ^= _gf_multiply(divisor[index], factor)
	return result


static func _gf_multiply(left: int, right: int) -> int:
	var product: int = 0
	for bit: int in range(7, -1, -1):
		product = (product << 1) ^ ((product >> 7) * FIELD_POLYNOMIAL)
		product ^= ((right >> bit) & 1) * left
	return product


# --- Small helpers ---
func _set_function(row: int, column: int, dark: bool) -> void:
	modules[row][column] = 1 if dark else 0
	is_function[row][column] = 1


static func _append_bits(bits: Array[int], value: int, count: int) -> void:
	for shift: int in range(count - 1, -1, -1):
		bits.append((value >> shift) & 1)


static func _bit(value: int, index: int) -> bool:
	return ((value >> index) & 1) == 1
