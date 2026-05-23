class_name FeedbackAudio
extends Node

const POOL_SIZE := 8
const SAMPLE_RATE := 22050

var players: Array[AudioStreamPlayer] = []
var streams := {}
var cooldowns := {}


func _ready() -> void:
	_build_streams()
	for player_index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.volume_db = -9.0
		add_child(player)
		players.append(player)


func update(delta: float) -> void:
	var expired := []
	for sound_id in cooldowns.keys():
		cooldowns[sound_id] = maxf(float(cooldowns[sound_id]) - delta, 0.0)
		if float(cooldowns[sound_id]) <= 0.0:
			expired.append(sound_id)
	for sound_id in expired:
		cooldowns.erase(sound_id)


func play(sound_id: String, cooldown := 0.04) -> void:
	if not streams.has(sound_id):
		return
	if float(cooldowns.get(sound_id, 0.0)) > 0.0:
		return
	var player: AudioStreamPlayer = _available_player()
	if player == null:
		return
	cooldowns[sound_id] = cooldown
	player.stream = streams[sound_id]
	player.pitch_scale = 0.96 + randf() * 0.08
	player.play()


func _build_streams() -> void:
	streams["shoot"] = _make_chirp_stream(780.0, 520.0, 0.035, 0.11)
	streams["hit"] = _make_chirp_stream(260.0, 180.0, 0.035, 0.08)
	streams["pickup"] = _make_chirp_stream(780.0, 1120.0, 0.07, 0.12)
	streams["level"] = _make_chirp_stream(560.0, 980.0, 0.16, 0.18)
	streams["upgrade"] = _make_chirp_stream(620.0, 860.0, 0.11, 0.14)
	streams["power"] = _make_chirp_stream(320.0, 920.0, 0.2, 0.2)
	streams["chest"] = _make_chirp_stream(480.0, 760.0, 0.18, 0.17)
	streams["boom"] = _make_chirp_stream(150.0, 72.0, 0.22, 0.2)


func _available_player() -> AudioStreamPlayer:
	for player in players:
		if not player.playing:
			return player
	return players[0] if not players.is_empty() else null


func _make_chirp_stream(start_frequency: float, end_frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	var sample_count := int(float(SAMPLE_RATE) * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase := 0.0
	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var frequency := lerpf(start_frequency, end_frequency, progress)
		phase += TAU * frequency / float(SAMPLE_RATE)
		var attack := minf(progress / 0.12, 1.0)
		var release := pow(1.0 - progress, 1.35)
		var sample := sin(phase) * attack * release * volume
		_write_s16(data, sample_index * 2, int(clampf(sample * 32767.0, -32768.0, 32767.0)))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream


func _write_s16(data: PackedByteArray, offset: int, sample_value: int) -> void:
	if sample_value < 0:
		sample_value += 65536
	data[offset] = sample_value & 0xff
	data[offset + 1] = (sample_value >> 8) & 0xff
