class_name BattleAudio
extends AudioStreamPlayer

const SAMPLE_RATE := 22050.0
const CUES := {
	&"ui_select": Vector2(720.0, 0.055),
	&"move_step": Vector2(360.0, 0.075),
	&"impact": Vector2(135.0, 0.11),
	&"defeat": Vector2(92.0, 0.22),
	&"phase": Vector2(480.0, 0.09),
	&"resonance": Vector2(960.0, 0.2),
	&"victory": Vector2(660.0, 0.28),
	&"defeat_result": Vector2(110.0, 0.32),
}

var played_cues: Array[StringName] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = SAMPLE_RATE
	generator.buffer_length = 0.5
	stream = generator
	volume_db = -10.0
	play()


func _exit_tree() -> void:
	stop()
	stream = null


func cue_for_event(event_type: StringName, payload: Dictionary = {}) -> StringName:
	match event_type:
		&"unit_selected": return &"ui_select"
		&"unit_moved": return &"move_step"
		&"damage_applied": return &"impact"
		&"unit_defeated": return &"defeat"
		&"phase_changed": return &"phase"
		&"resonance_changed": return &"resonance"
		&"battle_status_changed":
			return &"victory" if StringName(payload.get("to", &"")) == &"victory" else &"defeat_result"
	return &""


func play_events(events: Array[Dictionary]) -> void:
	for event: Dictionary in events:
		var cue := cue_for_event(StringName(event.get("type", &"")), event.get("payload", {}))
		if not cue.is_empty():
			play_cue(cue)


func play_cue(cue: StringName) -> void:
	if not CUES.has(cue):
		return
	played_cues.append(cue)
	if not is_inside_tree() or not playing:
		return
	var playback := get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var specification: Vector2 = CUES[cue]
	var frame_count := int(SAMPLE_RATE * specification.y)
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for index in frame_count:
		var progress := float(index) / maxf(1.0, float(frame_count - 1))
		var envelope := sin(progress * PI) * 0.18
		var sample := sin(TAU * specification.x * float(index) / SAMPLE_RATE) * envelope
		frames[index] = Vector2(sample, sample)
	playback.push_buffer(frames)
