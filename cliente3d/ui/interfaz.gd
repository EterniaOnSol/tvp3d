extends CanvasLayer

## HUD de TVP3D organizado como el cliente clasico de Tibia.
## La interfaz no inventa estado: escucha a estado_mundo.gd y envia acciones
## por conexion772.gd. Esto permite probarla con el servidor real o el visor.

const VENTANA := preload("res://ui/ventana.gd")
const BARRA := preload("res://ui/barra.gd")
const RANURA := preload("res://ui/ranura.gd")
const MINIMAPA := preload("res://ui/minimapa.gd")

const DISPOSICION_EQUIPO := [
	[2, 1, 3], [6, 4, 5], [9, 7, 10], [0, 8, 0],
]
const NOMBRES_EQUIPO := {
	1: "Helmet", 2: "Amulet", 3: "Backpack", 4: "Armor",
	5: "Right hand", 6: "Left hand", 7: "Legs", 8: "Feet",
	9: "Ring", 10: "Ammo",
}
const NOMBRES_HABILIDAD := {
	"puno": "Fist Fighting", "garrote": "Club Fighting",
	"espada": "Sword Fighting", "hacha": "Axe Fighting",
	"distancia": "Distance Fighting", "escudo": "Shielding",
	"pesca": "Fishing", "mining": "Mining", "farming": "Farming",
	"crafting": "Crafting",
}

class ZonaSuelo extends Control:
	var interfaz

	func _init(p_interfaz) -> void:
		interfaz = p_interfaz
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _can_drop_data(_pos: Vector2, datos: Variant) -> bool:
		return datos is Dictionary and datos.get("tipo", "") in [
			"inventario", "contenedor"]

	func _drop_data(pos: Vector2, datos: Variant) -> void:
		interfaz._soltar_item_en_mundo(pos, datos)


var _mundo
var _estado
var _sprites
var _catalogo
var _root: Control
var _stats_label: Label
var _capacidad_label: Label
var _hp
var _mp
var _battle_box: VBoxContainer
var _battle_window
var _stash_window
var _chat: RichTextLabel
var _chat_input: LineEdit
var _minimapa
var _skills_box: VBoxContainer
var _barra_nivel
var _barra_magia
var _barras_habilidad: Dictionary = {}
var _vitales_window
var _vitales_hp
var _vitales_mp
var _target_window
var _target_name: Label
var _target_bar
var _objetivo_id := 0
var _slots: Dictionary = {}
var _ventanas_contenedor: Dictionary = {}
var _dock_izq: VBoxContainer
var _dock_der_interno: VBoxContainer
var _dock_der_externo: VBoxContainer
var _columnas: Array[VBoxContainer] = []
var _docks_listos := false


func _init(mundo, estado, sprites, catalogo) -> void:
	_mundo = mundo
	_estado = estado
	_sprites = sprites
	_catalogo = catalogo
	layer = 20


func _ready() -> void:
	_armar()
	_estado.cambio.connect(_refrescar)
	_estado.inventario_actualizado.connect(_al_inventario_actualizado)
	_estado.contenedor_actualizado.connect(_al_contenedor_actualizado)
	_estado.contenedor_cerrado.connect(_al_contenedor_cerrado)
	_estado.estadisticas_actualizadas.connect(_al_estadisticas_actualizadas)
	_estado.habilidades_actualizadas.connect(_al_habilidades_actualizadas)
	_estado.habla_recibida.connect(_al_habla)
	_estado.mensaje_servidor.connect(_al_mensaje_servidor)
	_refrescar()


func _armar() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(ZonaSuelo.new(self))
	_armar_docks()
	# El orden inicial sigue la referencia Mythera: VIP y Bestiary arriba,
	# Skills en el centro de la columna y Loot Analyzer abajo.
	_armar_vip()
	_armar_bestiary()
	_armar_skills()
	_armar_loot_analyzer()
	_armar_minimapa()
	_armar_vitales()
	_armar_acciones()
	_armar_stash()
	_armar_equipo()
	_armar_battle()
	_armar_chat()
	_armar_objetivo()


func _armar_docks() -> void:
	var margen := MarginContainer.new()
	margen.set_anchors_preset(Control.PRESET_FULL_RECT)
	margen.add_theme_constant_override("margin_left", 6)
	margen.add_theme_constant_override("margin_top", 6)
	margen.add_theme_constant_override("margin_right", 6)
	margen.add_theme_constant_override("margin_bottom", 6)
	margen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(margen)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 5)
	fila.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margen.add_child(fila)

	_dock_izq = _nueva_columna(190)
	fila.add_child(_dock_izq)
	_columnas.append(_dock_izq)

	var centro := Control.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(centro)

	_dock_der_interno = _nueva_columna(190)
	fila.add_child(_dock_der_interno)
	_columnas.append(_dock_der_interno)

	_dock_der_externo = _nueva_columna(190)
	fila.add_child(_dock_der_externo)
	_columnas.append(_dock_der_externo)
	_docks_listos = true
	_ajustar_columnas()


func _nueva_columna(ancho: int) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 4)
	columna.custom_minimum_size.x = ancho
	columna.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	columna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return columna


func _ventana(texto: String, preset: int, left: float, top: float,
		right: float, bottom: float, cerrar: bool = false):
	var panel = VENTANA.new(texto, cerrar)
	if _docks_listos and texto not in ["Chat", "Target"]:
		var destino: VBoxContainer = _columna_para_titulo(texto)
		panel.custom_minimum_size = Vector2(190,
			maxf(40.0, bottom - top) if bottom >= top else 40.0)
		panel.reordenable = true
		panel.pidio_reordenar.connect(_reacomodar.bind(panel))
		destino.add_child(panel)
		return panel
	panel.set_anchors_preset(preset)
	panel.offset_left = left
	panel.offset_top = top
	panel.offset_right = right
	panel.offset_bottom = bottom
	_root.add_child(panel)
	return panel


func _columna_para_titulo(titulo: String) -> VBoxContainer:
	if titulo in ["Skills", "VIP", "Bestiary Tracker", "Loot Analyzer"]:
		return _dock_izq
	if titulo in ["Backpack", "Container"]:
		return _dock_der_interno
	return _dock_der_externo


func _hacer_boton(texto: String, ayuda: String = "") -> Button:
	var boton := Button.new()
	boton.text = texto
	boton.flat = true
	boton.focus_mode = Control.FOCUS_NONE
	boton.custom_minimum_size.y = 19
	boton.add_theme_font_size_override("font_size", 9)
	boton.add_theme_color_override("font_color", VENTANA.TEXTO)
	boton.add_theme_color_override("font_hover_color", Color(0.95, 0.95, 0.95))
	if not ayuda.is_empty():
		boton.tooltip_text = ayuda
	return boton


func _reacomodar(pos_mouse: Vector2, panel) -> void:
	var destino := _columna_mas_cerca(pos_mouse.x)
	if destino == null:
		return
	var lugar := _lugar_en_columna(destino, pos_mouse.y, panel)
	if panel.get_parent() != destino:
		if panel.get_parent() != null:
			panel.get_parent().remove_child(panel)
		destino.add_child(panel)
		destino.move_child(panel, clampi(lugar, 0, destino.get_child_count() - 1))
	else:
		destino.move_child(panel, clampi(lugar, 0, destino.get_child_count() - 1))
	_ajustar_columnas()


func _columna_mas_cerca(x: float) -> VBoxContainer:
	if _columnas.is_empty():
		return null
	var mejor: VBoxContainer = _columnas[0]
	var distancia := INF
	for columna in _columnas:
		var centro := columna.global_position.x + columna.size.x * 0.5
		var nueva_distancia := absf(x - centro)
		if nueva_distancia < distancia:
			distancia = nueva_distancia
			mejor = columna
	return mejor


func _lugar_en_columna(columna: VBoxContainer, y: float, panel) -> int:
	var lugar := 0
	for otro in columna.get_children():
		if otro == panel or not otro is Control:
			continue
		var control: Control = otro
		var centro: float = control.global_position.y + control.size.y * 0.5
		if y > centro:
			lugar += 1
	return lugar


func _ajustar_columnas() -> void:
	for columna in _columnas:
		var ocupada := false
		for hijo in columna.get_children():
			if hijo is Control and hijo.visible:
				ocupada = true
				break
		columna.custom_minimum_size.x = 190 if ocupada else 14


func _armar_bestiary() -> void:
	var panel = _ventana("Bestiary Tracker", Control.PRESET_TOP_LEFT,
		10, 340, 200, 424)
	var estado := VENTANA.etiqueta("No tracked creatures", 10, VENTANA.TENUE)
	estado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.cuerpo.add_child(estado)
	var progreso := VENTANA.etiqueta("Track a creature to see progress", 9,
		VENTANA.TENUE)
	progreso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progreso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.cuerpo.add_child(progreso)


func _armar_loot_analyzer() -> void:
	var panel = _ventana("Loot Analyzer", Control.PRESET_TOP_LEFT,
		10, 430, 200, 590)
	var filas := [
		["Supply", "0"], ["Loot", "0"], ["Loot / hour", "0"],
		["Profit", "0"], ["Profit / hour", "0"],
	]
	for datos in filas:
		var fila := HBoxContainer.new()
		var nombre := VENTANA.etiqueta(datos[0], 9, VENTANA.TENUE)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nombre)
		var valor := VENTANA.etiqueta(datos[1], 9)
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		panel.cuerpo.add_child(fila)
	var pie := VENTANA.etiqueta("Session time: 0:00", 9, VENTANA.TENUE)
	panel.cuerpo.add_child(pie)


func _armar_acciones() -> void:
	var panel = _ventana("Actions", Control.PRESET_TOP_RIGHT,
		-200, 294, -10, 362)
	var grilla := GridContainer.new()
	grilla.columns = 4
	grilla.add_theme_constant_override("h_separation", 0)
	grilla.add_theme_constant_override("v_separation", 0)
	panel.cuerpo.add_child(grilla)
	for nombre in ["Store", "Skills", "Battle", "Vip", "Analyz.",
			"Bestiary", "Stash", "Hotkeys"]:
		var boton := _hacer_boton(nombre, "Open " + nombre)
		boton.custom_minimum_size.x = 44
		if nombre == "Battle":
			boton.pressed.connect(func(): _alternar_ventana(_battle_window))
		elif nombre == "Stash":
			boton.pressed.connect(func(): _alternar_ventana(_stash_window))
		else:
			boton.pressed.connect(func(): _anotar("%s is not connected yet." % nombre))
		grilla.add_child(boton)


func _armar_stash() -> void:
	var panel = _ventana("Stash", Control.PRESET_TOP_RIGHT,
		-200, 366, -10, 442)
	_stash_window = panel
	var balance := HBoxContainer.new()
	var balance_nombre := VENTANA.etiqueta("Balance", 9, VENTANA.TENUE)
	balance_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	balance.add_child(balance_nombre)
	balance.add_child(VENTANA.etiqueta("0 gold", 9))
	panel.cuerpo.add_child(balance)
	var tiempo := VENTANA.etiqueta("Time: 0 days", 9, VENTANA.TENUE)
	tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.cuerpo.add_child(tiempo)
	var retirar := _hacer_boton("Withdraw", "Withdraw from stash")
	retirar.pressed.connect(func(): _anotar("Stash withdrawal is not connected yet."))
	panel.cuerpo.add_child(retirar)


func _alternar_ventana(panel) -> void:
	if panel == null:
		return
	panel.visible = not panel.visible
	_ajustar_columnas()


func _armar_estado() -> void:
	var panel = _ventana("TVP3D  |  Character", Control.PRESET_TOP_LEFT,
		12, 12, 242, 210)
	var nombre := VENTANA.etiqueta("Rookgaard adventurer", 12,
		Color(0.95, 0.82, 0.48))
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.cuerpo.add_child(nombre)
	_hp = BARRA.new(Color(0.70, 0.16, 0.16), "Hit Points", 17)
	panel.cuerpo.add_child(_hp)
	_mp = BARRA.new(Color(0.18, 0.34, 0.72), "Mana", 17)
	panel.cuerpo.add_child(_mp)
	_stats_label = VENTANA.etiqueta("Level: --", 11)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.cuerpo.add_child(_stats_label)
	panel.cuerpo.add_child(VENTANA.separador())
	var ayuda := VENTANA.etiqueta(
		"WASD / arrows: walk\nLeft: walk or drag\nRight: use / rotate camera\nF6: lower floors  |  F4: inspect",
		10, VENTANA.TENUE)
	panel.cuerpo.add_child(ayuda)


func _armar_skills() -> void:
	var panel = _ventana("Skills", Control.PRESET_TOP_LEFT,
		10, 10, 200, 334)
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 1)
	panel.cuerpo.add_child(_skills_box)
	for nombre in ["Exp.", "Level", "Hitpoints", "Mana", "Speed",
			"Capacity", "Food", "Stamina"]:
		var fila := HBoxContainer.new()
		var etiqueta := VENTANA.etiqueta(nombre, 10, VENTANA.TENUE)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var valor := VENTANA.etiqueta("--", 10)
		valor.name = nombre
		valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		fila.add_child(valor)
		_skills_box.add_child(fila)
	_barra_nivel = BARRA.new(Color(0.72, 0.60, 0.28), "", 9)
	_barra_nivel.name = "LevelProgress"
	_skills_box.add_child(_barra_nivel)
	_skills_box.add_child(VENTANA.separador())
	_barra_magia = BARRA.new(Color(0.35, 0.45, 0.80), "Magic Level", 13)
	_skills_box.add_child(_barra_magia)
	for clave in NOMBRES_HABILIDAD:
		var barra := BARRA.new(Color(0.45, 0.55, 0.72),
			NOMBRES_HABILIDAD[clave], 13)
		barra.name = clave
		_skills_box.add_child(barra)
		_barras_habilidad[clave] = barra


func _armar_vip() -> void:
	var panel = _ventana("VIP", Control.PRESET_TOP_LEFT,
		10, 340, 200, 432)
	var nombres := [
		["Dawn2", true], ["Dawn4", true], ["Dawn3", false], ["Dawn5", false],
	]
	for datos in nombres:
		var fila := VENTANA.etiqueta(str(datos[0]), 10,
			Color(0.35, 0.82, 0.35) if datos[1] else VENTANA.TENUE)
		panel.cuerpo.add_child(fila)


func _armar_minimapa() -> void:
	var panel = _ventana("Minimap", Control.PRESET_TOP_RIGHT,
		-200, 10, -10, 230)
	_minimapa = MINIMAPA.new(_mundo, _estado, _catalogo)
	_minimapa.pidio_caminar.connect(_caminar_desde_minimapa)
	panel.cuerpo.add_child(_minimapa)
	var pie := HBoxContainer.new()
	var leyenda := VENTANA.etiqueta("White: you  Pink: creatures", 8, VENTANA.TENUE)
	leyenda.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(leyenda)
	var menos := Button.new()
	menos.text = "-"
	menos.tooltip_text = "Zoom out"
	menos.custom_minimum_size = Vector2(18, 16)
	menos.pressed.connect(func(): _minimapa.acercar(false))
	pie.add_child(menos)
	var mas := Button.new()
	mas.text = "+"
	mas.tooltip_text = "Zoom in"
	mas.custom_minimum_size = Vector2(18, 16)
	mas.pressed.connect(func(): _minimapa.acercar(true))
	pie.add_child(mas)
	panel.cuerpo.add_child(pie)


func _caminar_desde_minimapa(celda: Vector2i) -> void:
	_mundo.caminar_a_casilla_desde_minimapa(celda)


func _armar_equipo() -> void:
	var panel = _ventana("Equipment", Control.PRESET_TOP_RIGHT,
		-200, 295, -10, 490)
	var grilla := GridContainer.new()
	grilla.columns = 3
	grilla.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grilla.add_theme_constant_override("h_separation", 2)
	grilla.add_theme_constant_override("v_separation", 2)
	panel.cuerpo.add_child(grilla)
	for fila in DISPOSICION_EQUIPO:
		for slot in fila:
			if slot == 0:
				var hueco := Control.new()
				hueco.custom_minimum_size = Vector2(RANURA.LADO, RANURA.LADO)
				grilla.add_child(hueco)
				continue
			var ranura = RANURA.new(self, slot)
			ranura.tooltip_text = NOMBRES_EQUIPO.get(slot, "Equipment")
			_slots[slot] = ranura
			grilla.add_child(ranura)
	var pie := HBoxContainer.new()
	pie.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel.cuerpo.add_child(pie)
	_capacidad_label = VENTANA.etiqueta("Cap: --", 10, VENTANA.TENUE)
	_capacidad_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(_capacidad_label)
	for nombre in ["Quests", "Options", "Logout"]:
		var boton := Button.new()
		boton.text = nombre
		boton.flat = true
		boton.custom_minimum_size = Vector2(0, 17)
		boton.add_theme_font_size_override("font_size", 9)
		boton.pressed.connect(func(): _anotar(nombre + " is not connected yet."))
		pie.add_child(boton)


func _armar_vitales() -> void:
	var panel = _ventana("Health", Control.PRESET_TOP_RIGHT,
		-200, 237, -10, 294)
	_vitales_window = panel
	var cuerpo := VBoxContainer.new()
	panel.cuerpo.add_child(cuerpo)
	var hp := BARRA.new(Color(0.72, 0.16, 0.16), "HP", 13)
	hp.name = "HP"
	_vitales_hp = hp
	cuerpo.add_child(hp)
	var mp := BARRA.new(Color(0.22, 0.35, 0.72), "MP", 13)
	mp.name = "MP"
	_vitales_mp = mp
	cuerpo.add_child(mp)
	var pz := VENTANA.etiqueta("Protection Zone", 9, Color(0.55, 0.80, 1.0))
	pz.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pz.visible = false
	cuerpo.add_child(pz)


func _armar_battle() -> void:
	_battle_window = _ventana("Battle", Control.PRESET_TOP_RIGHT,
		-200, 498, -10, -34)
	_battle_window.custom_minimum_size = Vector2(190, 188)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_window.cuerpo.add_child(scroll)
	_battle_box = VBoxContainer.new()
	_battle_box.add_theme_constant_override("separation", 3)
	_battle_box.custom_minimum_size.x = 178
	scroll.add_child(_battle_box)
	# In the reference client Battle is opened from the action toolbar;
	# it does not occupy the right dock while there are no creatures.
	_battle_window.visible = false


func _armar_chat() -> void:
	var panel = _ventana("Chat", Control.PRESET_BOTTOM_WIDE,
		210, -170, -210, -10)
	var canales := HBoxContainer.new()
	canales.add_theme_constant_override("separation", 4)
	for nombre in ["Default", "Server Log", "Help", "Loot", "Trade"]:
		var canal := _hacer_boton(nombre)
		canal.custom_minimum_size = Vector2(0, 17)
		canal.add_theme_color_override("font_color", VENTANA.TENUE)
		canales.add_child(canal)
	var chat_off := _hacer_boton("Chat off", "Toggle chat display")
	chat_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_off.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chat_off.pressed.connect(func(): _chat.visible = not _chat.visible)
	canales.add_child(chat_off)
	panel.cuerpo.add_child(canales)
	_chat = RichTextLabel.new()
	_chat.bbcode_enabled = false
	_chat.scroll_active = true
	_chat.custom_minimum_size.y = 87
	_chat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat.add_theme_font_size_override("normal_font_size", 10)
	panel.cuerpo.add_child(_chat)
	var fila := HBoxContainer.new()
	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Say something..."
	_chat_input.add_theme_font_size_override("font_size", 10)
	_chat_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_input.text_submitted.connect(_decir)
	fila.add_child(_chat_input)
	panel.cuerpo.add_child(fila)


func _armar_objetivo() -> void:
	_target_window = _ventana("Target", Control.PRESET_CENTER_TOP,
		-120, 12, 120, 86)
	_target_window.visible = false
	_target_name = VENTANA.etiqueta("", 11)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_window.cuerpo.add_child(_target_name)
	_target_bar = BARRA.new(Color(0.78, 0.18, 0.18), "", 14)
	_target_window.cuerpo.add_child(_target_bar)


func _refrescar() -> void:
	if _estado == null:
		return
	var stats: Dictionary = _estado.estadisticas
	var vida: int = int(stats.get("vida", 0))
	var vida_max: int = int(stats.get("vida_max", 0))
	var mana: int = int(stats.get("mana", 0))
	var mana_max: int = int(stats.get("mana_max", 0))
	var capacidad: int = int(stats.get("capacidad", 0))
	if _capacidad_label != null:
		_capacidad_label.text = "Cap: %d" % capacidad
	_actualizar_skills(stats)
	_actualizar_vitales(vida, vida_max, mana, mana_max)
	_actualizar_battle()
	for slot in _slots:
		var ranura = _slots[slot]
		ranura.mostrar(_estado.inventario.get(slot, {}))
	if _minimapa != null:
		_minimapa.refrescar()


func _actualizar_vitales(vida: int, vida_max: int, mana: int,
		mana_max: int) -> void:
	if _vitales_hp == null or _vitales_mp == null:
		return
	_vitales_hp.fijar(float(vida) / float(maxi(1, vida_max)),
		"%d / %d" % [vida, vida_max])
	_vitales_mp.fijar(float(mana) / float(maxi(1, mana_max)),
		"%d / %d" % [mana, mana_max])


func _actualizar_skills(stats: Dictionary) -> void:
	if _skills_box == null:
		return
	var valores := {
		"Exp.": str(stats.get("experiencia", 0)),
		"Level": str(stats.get("nivel", 0)),
		"Hitpoints": "%d / %d" % [int(stats.get("vida", 0)),
			int(stats.get("vida_max", 0))],
		"Mana": "%d / %d" % [int(stats.get("mana", 0)),
			int(stats.get("mana_max", 0))],
		"Speed": str(stats.get("velocidad", 0)),
		"Capacity": str(stats.get("capacidad", 0)),
		"Food": str(stats.get("food", stats.get("comida", 0))),
		"Stamina": str(stats.get("stamina", 0)),
	}
	for nombre in valores:
		var valor = _skills_box.find_child(nombre, true, false)
		if valor != null:
			valor.text = valores[nombre]
	if _barra_nivel != null:
		var nivel_pct := float(stats.get("nivel_pct", 0)) / 100.0
		_barra_nivel.fijar(nivel_pct, "%d%%" % int(nivel_pct * 100.0))
	if _barra_magia != null:
		var magia_pct := float(stats.get("magia_pct", 0)) / 100.0
		_barra_magia.fijar(magia_pct, str(stats.get("magia", 0)))
	for clave in _estado.habilidades:
		if not _barras_habilidad.has(clave):
			continue
		var datos: Dictionary = _estado.habilidades[clave]
		_barras_habilidad[clave].fijar(
			float(datos.get("porcentaje", 0)) / 100.0,
			str(datos.get("nivel", 0)))


func _actualizar_battle() -> void:
	if _battle_box == null:
		return
	for hijo in _battle_box.get_children():
		hijo.queue_free()
	var ids: Array = _estado.criaturas.keys()
	ids.sort()
	var puestos := 0
	for id in ids:
		if int(id) == _estado.mi_id:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		_agregar_fila_battle(int(id), criatura)
		puestos += 1
		if puestos >= 10:
			break
	if puestos == 0:
		_battle_box.add_child(VENTANA.etiqueta("No creatures in view", 10,
			VENTANA.TENUE))
	_battle_window.fijar_titulo("Battle (%d)" % puestos)


func _agregar_fila_battle(id: int, criatura: Dictionary) -> void:
	var fila := Button.new()
	fila.flat = true
	fila.custom_minimum_size.y = 34
	fila.tooltip_text = "Left click: attack  |  Right click: follow"
	fila.pressed.connect(func(): _seleccionar_objetivo(id, false))
	fila.gui_input.connect(func(evento): _input_battle(evento, id))
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.08, 0.085, 0.11, 0.85)
	estilo.set_corner_radius_all(2)
	fila.add_theme_stylebox_override("normal", estilo)
	var hover = estilo.duplicate()
	hover.bg_color = Color(0.18, 0.15, 0.12, 0.95)
	fila.add_theme_stylebox_override("hover", hover)
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 6
	caja.offset_top = 3
	caja.offset_right = -6
	caja.offset_bottom = -3
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(caja)
	var nombre := VENTANA.etiqueta(str(criatura.get("nombre", "Creature")), 10)
	caja.add_child(nombre)
	var porcentaje := clampf(float(criatura.get("vida", 100)) / 100.0, 0.0, 1.0)
	var barra = BARRA.new(Color(0.68, 0.18, 0.18), "", 7)
	barra.fijar(porcentaje, "%d%%" % int(porcentaje * 100.0))
	caja.add_child(barra)
	_battle_box.add_child(fila)


func _input_battle(evento: InputEvent, id: int) -> void:
	if evento is InputEventMouseButton and evento.pressed \
			and evento.button_index == MOUSE_BUTTON_RIGHT:
		_seleccionar_objetivo(id, true)
		get_viewport().set_input_as_handled()


func _seleccionar_objetivo(id: int, seguir: bool) -> void:
	_objetivo_id = id
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	if criatura.is_empty():
		return
	_target_window.visible = true
	_target_name.text = str(criatura.get("nombre", "Creature"))
	var porcentaje := clampf(float(criatura.get("vida", 100)) / 100.0, 0.0, 1.0)
	_target_bar.fijar(porcentaje, "%d%%" % int(porcentaje * 100.0))
	var con = _mundo._con
	if con != null:
		if seguir:
			con.enviar_seguir(id)
			_anotar("Following %s." % _target_name.text)
		else:
			con.enviar_atacar(id)
			_anotar("Attacking %s." % _target_name.text)


func _al_inventario_actualizado(_slot: int, _cosa: Dictionary) -> void:
	_refrescar()


func _al_estadisticas_actualizadas(_datos: Dictionary) -> void:
	_refrescar()


func _al_habilidades_actualizadas(_datos: Dictionary) -> void:
	_refrescar()


func _al_mensaje_servidor(texto: String) -> void:
	_anotar("[Server] " + texto)


func _al_habla(quien: String, texto: String, _clase: int) -> void:
	_anotar("%s: %s" % [quien, texto])


func _anotar(texto: String) -> void:
	if _chat != null:
		_chat.append_text(texto + "\n")


func _decir(texto: String) -> void:
	var limpio := texto.strip_edges()
	if limpio.is_empty():
		return
	var con = _mundo._con
	if con != null:
		con.enviar_hablar(limpio)
	_anotar("You: " + limpio)
	_chat_input.clear()


func icono_para_item(cid: int) -> Texture2D:
	var cuadro: Dictionary = _sprites.cuadro_item(cid, 0)
	if cuadro.is_empty():
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = cuadro["lamina"]
	var escala: Vector3 = cuadro["escala"]
	var corrimiento: Vector3 = cuadro["corrimiento"]
	const LADO_LAMINA := 2048.0
	atlas.region = Rect2(corrimiento.x * LADO_LAMINA,
		corrimiento.y * LADO_LAMINA, escala.x * LADO_LAMINA,
		escala.y * LADO_LAMINA)
	return atlas


func usar_inventario(slot: int, cosa: Dictionary) -> void:
	var con = _mundo._con
	if con != null:
		con.enviar_usar_inventario(slot, int(cosa.get("cid", 0)))
	_anotar("Using %s..." % str(cosa.get("nombre", "item")))


func mirar_inventario(slot: int, cosa: Dictionary) -> void:
	_anotar("You see %s in inventory slot %d." % [
		str(cosa.get("nombre", "item")), slot])


func mover_a_ranura(datos: Dictionary, tipo_destino: String,
		id_destino: int, ranura_destino: int) -> void:
	var tipo_origen: String = str(datos.get("tipo", "inventario"))
	var id_origen: int = int(datos.get("contenedor", -1))
	var ranura_origen: int = int(datos.get("slot", -1))
	if ranura_origen < 0 or (tipo_origen == tipo_destino
			and id_origen == id_destino and ranura_origen == ranura_destino):
		return
	var con = _mundo._con
	if con == null:
		return
	var origen := _posicion_de_item(tipo_origen, id_origen, ranura_origen)
	var destino := _posicion_de_item(tipo_destino, id_destino, ranura_destino)
	con.enviar_mover_ubicacion(origen, int(datos.get("cid", 0)), 0,
		destino, int(datos.get("cantidad", 1)))


func _posicion_de_item(tipo: String, id_contenedor: int, ranura: int) -> Vector3i:
	if tipo == "contenedor":
		return Vector3i(0xFFFF, id_contenedor, ranura)
	return Vector3i(0xFFFF, ranura, 0)


func _soltar_item_en_mundo(posicion_mouse: Vector2, datos: Dictionary) -> void:
	_mundo.soltar_inventario_en_mouse(posicion_mouse, datos)


func _al_contenedor_actualizado(id: int, datos: Dictionary) -> void:
	if not _ventanas_contenedor.has(id):
		var ventana = VENTANA.new("Container", true)
		ventana.custom_minimum_size = Vector2(190, 170)
		ventana.reordenable = true
		ventana.pidio_reordenar.connect(_reacomodar.bind(ventana))
		ventana.cerrar_solicitado.connect(func(): _cerrar_contenedor(id))
		_dock_der_interno.add_child(ventana)
		_dock_der_interno.move_child(ventana, 0)
		_ventanas_contenedor[id] = ventana
		_ajustar_columnas()
	_refrescar_contenedor(id, datos)


func _refrescar_contenedor(id: int, datos: Dictionary) -> void:
	if not _ventanas_contenedor.has(id):
		return
	var ventana = _ventanas_contenedor[id]
	ventana.fijar_titulo("%s [%d]" % [str(datos.get("nombre", "Container")), id])
	for hijo in ventana.cuerpo.get_children():
		hijo.queue_free()
	var grilla := GridContainer.new()
	grilla.columns = 4
	grilla.add_theme_constant_override("h_separation", 3)
	grilla.add_theme_constant_override("v_separation", 3)
	ventana.cuerpo.add_child(grilla)
	var capacidad := mini(32, maxi(1, int(datos.get("capacidad", 1))))
	var items: Array = datos.get("items", [])
	for ranura in range(capacidad):
		var slot = RANURA.new(self, ranura, "contenedor", id)
		if ranura < items.size():
			slot.mostrar(items[ranura])
		grilla.add_child(slot)
	var pie := VENTANA.etiqueta("%d / %d slots" % [items.size(), capacidad],
		9, VENTANA.TENUE)
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ventana.cuerpo.add_child(pie)


func _al_contenedor_cerrado(id: int) -> void:
	if not _ventanas_contenedor.has(id):
		return
	var ventana = _ventanas_contenedor[id]
	_ventanas_contenedor.erase(id)
	if ventana.get_parent() != null:
		ventana.get_parent().remove_child(ventana)
	ventana.queue_free()
	_ajustar_columnas()


func _cerrar_contenedor(id: int) -> void:
	var con = _mundo._con
	if con != null:
		con.enviar_cerrar_contenedor(id)
	else:
		_al_contenedor_cerrado(id)
