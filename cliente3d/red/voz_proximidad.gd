extends Node

## Chat de voz de baja latencia para la primera integración de TVP3D.
##
## El audio viaja como PCM mono de 8 kHz en cuadros de 20 ms. No depende de
## una librería externa y el servidor solo lo retransmite a la proximidad;
## más adelante se puede cambiar el códec sin tocar el alcance ni el input.

signal estado_cambio(texto: String)
signal hablando_cambio(activo: bool)

const OPCODE_VOZ_PROXIMIDAD := 0xF1
const VERSION_TRAMA := 1
const BANDERA_AUDIO := 1
const TASA_MUESTREO := 8000
const MUESTRAS_POR_TRAMA := 160 # 20 ms
const ALCANCE_CASILLAS := 7
const MAX_ORADORES := 16

var _conexion
var _bus_id := -1
var _captura: AudioEffectCapture
var _microfono: AudioStreamPlayer
var _captura_activa := false
var _hablando := false
var _secuencia := 0
var _paso_entrada := 1.0
var _cursor_entrada := 0.0
var _muestras_entrada: Array = []
var _pcm := PackedByteArray()
var _reproductores := {}
var _ultimo_audio := {}


func configurar_conexion(conexion) -> void:
	if _conexion == conexion:
		return
	detener()
	_conexion = conexion


func iniciar() -> bool:
	if _captura_activa:
		return true
	if _conexion == null:
		estado_cambio.emit("VOICE: no game connection")
		return false

	_bus_id = AudioServer.get_bus_index("VoiceCapture")
	if _bus_id < 0:
		AudioServer.add_bus()
		_bus_id = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus_id, "VoiceCapture")
		AudioServer.set_bus_send(_bus_id, "Master")
		AudioServer.set_bus_mute(_bus_id, true) # evita escucharnos con eco

	_captura = AudioEffectCapture.new()
	AudioServer.add_bus_effect(_bus_id, _captura)
	_microfono = AudioStreamPlayer.new()
	_microfono.name = "MicrofonoProximidad"
	_microfono.stream = AudioStreamMicrophone.new()
	_microfono.bus = "VoiceCapture"
	add_child(_microfono)
	_microfono.play()
	_paso_entrada = maxf(1.0, float(AudioServer.get_mix_rate()) / float(TASA_MUESTREO))
	_captura_activa = true
	estado_cambio.emit("VOICE READY  |  hold V to talk  |  range %d" % ALCANCE_CASILLAS)
	return true


func detener() -> void:
	if _hablando:
		_terminar_habla()
	_captura_activa = false
	if is_instance_valid(_microfono):
		_microfono.stop()
		_microfono.queue_free()
	_microfono = null
	_captura = null
	_muestras_entrada.clear()
	_pcm = PackedByteArray()
	_cursor_entrada = 0.0
	for id in _reproductores.keys():
		var jugador = _reproductores[id]
		if is_instance_valid(jugador):
			jugador.stop()
			jugador.queue_free()
	_reproductores.clear()
	_ultimo_audio.clear()
	if _hablando:
		_hablando = false
		hablando_cambio.emit(false)


func procesar_tecla(evento: InputEventKey) -> bool:
	if evento.keycode != KEY_V:
		return false
	if evento.echo:
		return true
	if evento.pressed:
		if not _hablando:
			_comenzar_habla()
	else:
		if _hablando:
			_terminar_habla()
	return true


func _comenzar_habla() -> void:
	if not _captura_activa or _conexion == null:
		estado_cambio.emit("VOICE: microphone unavailable")
		return
	_drenar_captura()
	_muestras_entrada.clear()
	_pcm = PackedByteArray()
	_cursor_entrada = 0.0
	_hablando = true
	hablando_cambio.emit(true)
	estado_cambio.emit("VOICE TALKING  |  release V")


func _terminar_habla() -> void:
	if not _hablando:
		return
	_hablando = false
	_muestras_entrada.clear()
	_pcm = PackedByteArray()
	_cursor_entrada = 0.0
	_enviar_trama(PackedByteArray([VERSION_TRAMA, 0,
		_secuencia & 0xFF, (_secuencia >> 8) & 0xFF]))
	_secuencia = (_secuencia + 1) & 0xFFFF
	hablando_cambio.emit(false)
	estado_cambio.emit("VOICE READY  |  hold V to talk  |  range %d" % ALCANCE_CASILLAS)


func _process(_delta: float) -> void:
	if _hablando and _captura_activa:
		_leer_captura()
		_convertir_a_pcm()
		_enviar_tramas()
	_limpiar_reproductores()


func _drenar_captura() -> void:
	if _captura == null:
		return
	var disponibles := _captura.get_frames_available()
	if disponibles > 0:
		_captura.get_buffer(mini(disponibles, 4096))


func _leer_captura() -> void:
	if _captura == null:
		return
	var disponibles := _captura.get_frames_available()
	if disponibles <= 0:
		return
	var frames: PackedVector2Array = _captura.get_buffer(mini(disponibles, 4096))
	for frame in frames:
		_muestras_entrada.append(clampf((frame.x + frame.y) * 0.5, -1.0, 1.0))


func _convertir_a_pcm() -> void:
	if _muestras_entrada.is_empty():
		return
	while true:
		var inicio := int(floor(_cursor_entrada))
		var fin := maxi(inicio + 1, int(floor(_cursor_entrada + _paso_entrada)))
		if fin > _muestras_entrada.size():
			break
		var suma := 0.0
		for indice in range(inicio, fin):
			suma += float(_muestras_entrada[indice])
		var promedio := suma / float(maxi(1, fin - inicio))
		_pcm.append(int(clampf((promedio * 0.5 + 0.5) * 255.0, 0.0, 255.0)))
		_cursor_entrada += _paso_entrada
	var consumir := int(floor(_cursor_entrada))
	if consumir > 0:
		_muestras_entrada = _muestras_entrada.slice(consumir)
		_cursor_entrada -= consumir


func _enviar_tramas() -> void:
	while _pcm.size() >= MUESTRAS_POR_TRAMA:
		var trama := PackedByteArray([VERSION_TRAMA, BANDERA_AUDIO,
			_secuencia & 0xFF, (_secuencia >> 8) & 0xFF])
		trama.append_array(_pcm.slice(0, MUESTRAS_POR_TRAMA))
		_pcm = _pcm.slice(MUESTRAS_POR_TRAMA)
		_enviar_trama(trama)
		_secuencia = (_secuencia + 1) & 0xFFFF


func _enviar_trama(trama: PackedByteArray) -> void:
	if _conexion != null:
		_conexion.enviar_voz(trama)


func recibir_frame(orador_id: int, trama: PackedByteArray) -> void:
	if orador_id <= 0 or trama.size() < 4:
		return
	if trama[0] != VERSION_TRAMA:
		return
	var banderas: int = trama[1]
	if (banderas & BANDERA_AUDIO) == 0:
		return # el silencio solo sirve para marcar el final en futuras UI
	if trama.size() != 4 + MUESTRAS_POR_TRAMA:
		return
	var jugador = _reproductores.get(orador_id)
	if jugador == null or not is_instance_valid(jugador):
		if _reproductores.size() >= MAX_ORADORES:
			return
		var flujo := AudioStreamGenerator.new()
		flujo.mix_rate = TASA_MUESTREO
		flujo.buffer_length = 0.35
		jugador = AudioStreamPlayer.new()
		jugador.name = "Voz_%d" % orador_id
		jugador.stream = flujo
		add_child(jugador)
		jugador.play()
		_reproductores[orador_id] = jugador
	var playback := jugador.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var disponibles := mini(playback.get_frames_available(), MUESTRAS_POR_TRAMA)
	for indice in range(disponibles):
		var muestra := (float(trama[4 + indice]) / 255.0) * 2.0 - 1.0
		playback.push_frame(Vector2(muestra, muestra))
	_ultimo_audio[orador_id] = Time.get_ticks_msec() / 1000.0


func _limpiar_reproductores() -> void:
	var ahora := Time.get_ticks_msec() / 1000.0
	for id in _ultimo_audio.keys().duplicate():
		if ahora - float(_ultimo_audio[id]) < 1.5:
			continue
		var jugador = _reproductores.get(id)
		if is_instance_valid(jugador):
			jugador.stop()
			jugador.queue_free()
		_reproductores.erase(id)
		_ultimo_audio.erase(id)
