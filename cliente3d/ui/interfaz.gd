extends CanvasLayer

## HUD de TVP3D organizado como el cliente clasico de Tibia.
## La interfaz no inventa estado: escucha a estado_mundo.gd y envia acciones
## por conexion772.gd. Esto permite probarla con el servidor real o el visor.

const VENTANA := preload("res://ui/ventana.gd")
const BARRA := preload("res://ui/barra.gd")
const RANURA := preload("res://ui/ranura.gd")
const MINIMAPA := preload("res://ui/minimapa.gd")
const MARCA := preload("res://ui/marca_criatura.gd")
# El protocolo transporta client IDs, no los IDs internos del servidor.
const IDS_MONEDAS := [3031, 3035, 3043]
const IDS_MONEDAS_SERVIDOR := {
	2148: 3031, # gold coin
	2152: 3035, # platinum coin
	2160: 3043, # crystal coin
}
const ARCHIVO_NOMBRES_CRIATURAS := "res://assets/monster_names772.json"
const SLOT_ANILLO := 9
# El servidor reparte los ids por rango: jugadores desde 0x10000000, monstruos
# desde 0x40000000 y NPC desde 0x80000000 (player.cpp:34, monster.cpp:18,
# npc.cpp:16). Solo a un jugador se lo puede invitar a una party.
const ID_MINIMO_JUGADOR := 0x10000000
const ID_MINIMO_MONSTRUO := 0x40000000
# El mapa 7.72 que entrega el servidor mide 18x14 casillas: desde 8 al
# oeste/norte hasta 9 al este y 7 al sur respecto del personaje.
const VISTA_X_ANTES := 8
const VISTA_X_DESPUES := 9
const VISTA_Y_ANTES := 6
const VISTA_Y_DESPUES := 7

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
var _zona_suelo: Control
var _stats_label: Label
var _capacidad_label: Label
var _hp
var _mp
var _battle_box: VBoxContainer
var _battle_window
var _battle_scroll: ScrollContainer
var _battle_sprite_slots: Dictionary = {}
var _battle_rows: Dictionary = {}
var _battle_name_labels: Dictionary = {}
var _battle_health_bars: Dictionary = {}
var _battle_marcas: Dictionary = {}
var _menu_criatura: PopupMenu
## Trade a medio armar: a quien se le va a ofrecer, mientras se espera que el
## jugador elija con que objeto.
var _trade_pendiente := {}
var _battle_ids: Array = []
var _battle_anim_tiempo := 0.0
var _stash_window
var _vip_window
var _vip_box: VBoxContainer
var _vip_input: LineEdit
var _hotkeys_window
var _spellbook_window
var _spellbook_box: VBoxContainer
var _spells: Array = []
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
var _target_sprite: TextureRect
var _target_name: Label
var _target_marcas: Dictionary = {}
var _target_bar
var _objetivo_id := 0
var _comercio_window
var _comercio_propio_box: VBoxContainer
var _comercio_contraparte_box: VBoxContainer
var _comercio_nombre := ""
var _comercio_propio: Array = []
var _comercio_contraparte: Array = []
var _slots: Dictionary = {}
var _slots_contenedor: Dictionary = {}
var _ventanas_contenedor: Dictionary = {}
var _contenedores_visuales: Dictionary = {}
var _dialogo_cantidad: ConfirmationDialog
var _canales_box: HBoxContainer
var _botones_canales: Dictionary = {}
var _canal_actual := 0
var _nombre_canal_actual := "Default"
var _dock_izq: VBoxContainer
var _dock_der_interno: VBoxContainer
var _dock_der_externo: VBoxContainer
var _columnas: Array[VBoxContainer] = []
var _docks_listos := false
var _nombres_criaturas: Dictionary = {}


func _init(mundo, estado, sprites, catalogo) -> void:
	_mundo = mundo
	_estado = estado
	_sprites = sprites
	_catalogo = catalogo
	_cargar_nombres_criaturas()
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
	_estado.comercio_actualizado.connect(_al_comercio_actualizado)
	_estado.comercio_cerrado.connect(_al_comercio_cerrado)
	_estado.vip_actualizado.connect(_al_vip_actualizado)
	_estado.vip_reiniciado.connect(_al_vip_reiniciado)
	_estado.canales_actualizados.connect(_al_canales_actualizados)
	_estado.canal_abierto.connect(_al_canal_abierto)
	_estado.canal_cerrado.connect(_al_canal_cerrado)
	_estado.objetivo_cancelado.connect(_al_objetivo_cancelado)
	_refrescar()


func _armar() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var zona_suelo := ZonaSuelo.new(self)
	# Sin tamano propio, un Control hijo queda en 0x0 y nunca recibe el
	# drop de un item del container sobre el mundo.
	zona_suelo.set_anchors_preset(Control.PRESET_FULL_RECT)
	zona_suelo.mouse_filter = Control.MOUSE_FILTER_PASS
	_zona_suelo = zona_suelo
	_root.add_child(zona_suelo)
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
	_armar_hotkeys()
	_armar_spellbook()
	_armar_stash()
	_armar_equipo()
	_armar_battle()
	_armar_chat()
	_armar_objetivo()
	_armar_comercio()


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
		panel.tamano_cambio.connect(func(_nuevo: Vector2):
			_ajustar_columnas())
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
	if titulo == "Battle":
		# El Battle List tiene su propio dock interno, como en el cliente
		# clasico. Si comparte la columna externa queda debajo de Equipment y
		# desaparece fuera de la ventana aunque haya criaturas recibidas.
		return _dock_der_interno
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
		var ancho := 14.0
		for hijo in columna.get_children():
			if hijo is Control and hijo.visible:
				var panel: Control = hijo
				ancho = maxf(ancho, panel.custom_minimum_size.x)
				ancho = maxf(ancho, panel.size.x)
		columna.custom_minimum_size.x = ancho


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
	for nombre in ["Store", "Skills", "Battle", "Vip", "Stash"]:
		var boton := _hacer_boton(nombre, "Open " + nombre)
		boton.custom_minimum_size.x = 44
		if nombre == "Battle":
			boton.pressed.connect(func(): _alternar_ventana(_battle_window))
		elif nombre == "Vip":
			boton.pressed.connect(func(): _alternar_ventana(_vip_window))
		elif nombre == "Stash":
			boton.pressed.connect(func(): _alternar_ventana(_stash_window))
		else:
			boton.pressed.connect(func(): _anotar("%s is not connected yet." % nombre))
		grilla.add_child(boton)


func _armar_hotkeys() -> void:
	_hotkeys_window = _ventana("Hotkeys", Control.PRESET_TOP_RIGHT,
		-200, 370, -10, 490)
	_hotkeys_window.visible = false
	var texto := VENTANA.etiqueta(
		"Ctrl+G  Change character\nCtrl+Q / Ctrl+L  Logout\nCtrl+K  Toggle hotkeys\nEsc  Stop attack / cancel action\nEnter  Chat\nHold V  Proximity voice (7 sqm)",
		9, VENTANA.TEXTO)
	texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hotkeys_window.cuerpo.add_child(texto)


func alternar_hotkeys() -> void:
	_alternar_ventana(_hotkeys_window)


func _armar_spellbook() -> void:
	_spellbook_window = _ventana("Spells", Control.PRESET_TOP_RIGHT,
		-410, 12, -205, 470)
	_spellbook_window.visible = false
	_spellbook_window.custom_minimum_size = Vector2(300, 458)
	var ayuda := VENTANA.etiqueta(
		"Server spell catalog  |  click to cast\nRequirements and parameters come from the Lua scripts.",
		8, VENTANA.TENUE)
	ayuda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spellbook_window.cuerpo.add_child(ayuda)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(286, 390)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_spellbook_window.cuerpo.add_child(scroll)
	_spellbook_box = VBoxContainer.new()
	_spellbook_box.add_theme_constant_override("separation", 3)
	_spellbook_box.custom_minimum_size.x = 282
	scroll.add_child(_spellbook_box)
	_spells = _leer_hechizos()
	if _spells.is_empty():
		_spellbook_box.add_child(VENTANA.etiqueta(
			"Spell catalog not found.", 9, VENTANA.TENUE))
		return
	for hechizo in _spells:
		_agregar_hechizo(hechizo)


func alternar_spellbook() -> void:
	_alternar_ventana(_spellbook_window)


func _leer_hechizos() -> Array:
	var archivo := FileAccess.open("res://assets/spells772.json", FileAccess.READ)
	if archivo == null:
		return []
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) != TYPE_DICTIONARY:
		return []
	var lista = datos.get("spells", [])
	if typeof(lista) != TYPE_ARRAY:
		return []
	return lista


func _agregar_hechizo(hechizo: Dictionary) -> void:
	var fila := VBoxContainer.new()
	fila.add_theme_constant_override("separation", 0)
	var boton := _hacer_boton(str(hechizo.get("name", "Spell")))
	boton.alignment = HORIZONTAL_ALIGNMENT_LEFT
	boton.custom_minimum_size = Vector2(0, 20)
	boton.tooltip_text = _detalle_hechizo(hechizo)
	boton.pressed.connect(_usar_hechizo.bind(hechizo))
	fila.add_child(boton)
	var resumen := VENTANA.etiqueta(_resumen_hechizo(hechizo), 8,
		VENTANA.TENUE)
	resumen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fila.add_child(resumen)
	_spellbook_box.add_child(fila)


func _resumen_hechizo(hechizo: Dictionary) -> String:
	var palabras := str(hechizo.get("words", "")).strip_edges()
	var requisitos := []
	var mana := int(hechizo.get("mana", 0))
	var mana_pct := int(hechizo.get("mana_percent", 0))
	if mana > 0:
		requisitos.append("Mana %d" % mana)
	if mana_pct > 0:
		requisitos.append("Mana %d%%" % mana_pct)
	requisitos.append("ML %d" % int(hechizo.get("magic_level", 0)))
	var nivel := int(hechizo.get("level", 0))
	if nivel > 0:
		requisitos.append("Lv %d" % nivel)
	if bool(hechizo.get("need_direction", false)):
		requisitos.append("direction")
	if bool(hechizo.get("need_target", false)):
		requisitos.append("target")
	if bool(hechizo.get("has_parameter", false)):
		requisitos.append("parameter")
	return "%s  |  %s" % [palabras, "  ".join(requisitos)]


func _detalle_hechizo(hechizo: Dictionary) -> String:
	var lineas := [
		"Words: %s" % str(hechizo.get("words", "")),
		"Type: %s" % str(hechizo.get("type", "instant")),
		"Mana: %d  (%d%%)" % [
			int(hechizo.get("mana", 0)),
			int(hechizo.get("mana_percent", 0))],
		"Level: %d  Magic Level: %d  Soul: %d" % [
			int(hechizo.get("level", 0)),
			int(hechizo.get("magic_level", 0)),
			int(hechizo.get("soul", 0))],
		"Cooldown: %d ms  Range: %d" % [
			int(hechizo.get("cooldown_ms", 2000)),
			int(hechizo.get("range", -1))],
		"Premium: %s  Aggressive: %s" % [
			"yes" if bool(hechizo.get("premium", false)) else "no",
			"yes" if bool(hechizo.get("aggressive", true)) else "no"],
	]
	var vocaciones: Array = hechizo.get("vocations", [])
	if not vocaciones.is_empty():
		var nombres := []
		for vocacion in vocaciones:
			nombres.append(str(vocacion))
		lineas.append("Vocations: " + ", ".join(nombres))
	var parametros := []
	if bool(hechizo.get("has_parameter", false)):
		parametros.append("parameter required")
	if bool(hechizo.get("has_player_name_parameter", false)):
		parametros.append("player name")
	if bool(hechizo.get("need_target", false)):
		parametros.append("target")
	if bool(hechizo.get("need_direction", false)):
		parametros.append("direction")
	if bool(hechizo.get("self_target", false)):
		parametros.append("self")
	if not parametros.is_empty():
		lineas.append("Parameters: " + ", ".join(parametros))
	var combate: Dictionary = hechizo.get("combat", {})
	if not combate.is_empty():
		var detalles := []
		for clave in combate:
			detalles.append("%s=%s" % [str(clave), str(combate[clave])])
		lineas.append("Combat: " + ", ".join(detalles))
	if hechizo.has("rune_id"):
		lineas.append("Rune item: %d" % int(hechizo.get("rune_id", 0)))
	lineas.append("Source: %s" % str(hechizo.get("source", "")))
	return "\n".join(lineas)


func _usar_hechizo(hechizo: Dictionary) -> void:
	var palabras := str(hechizo.get("words", "")).strip_edges()
	if palabras.is_empty():
		return
	if bool(hechizo.get("has_parameter", false)):
		preparar_chat(palabras + " ")
		_anotar("Spell requires a parameter. Complete the value and press Enter.")
		return
	if _mundo.lanzar_hechizo(palabras):
		_anotar("Casting %s." % str(hechizo.get("name", "spell")))


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
	_vip_window = panel
	# El limite y el estado ya los decide el servidor. Este control solo
	# envia el nombre y muestra las respuestas 0xD2-0xD4.
	var entrada := HBoxContainer.new()
	entrada.add_theme_constant_override("separation", 3)
	_vip_input = LineEdit.new()
	_vip_input.placeholder_text = "Character name"
	_vip_input.add_theme_font_size_override("font_size", 9)
	_vip_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vip_input.custom_minimum_size.y = 20
	_vip_input.text_submitted.connect(func(_texto: String): _agregar_vip())
	entrada.add_child(_vip_input)
	var agregar := _hacer_boton("+", "Add character to VIP")
	agregar.custom_minimum_size = Vector2(22, 20)
	agregar.pressed.connect(_agregar_vip)
	entrada.add_child(agregar)
	panel.cuerpo.add_child(entrada)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 42)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.cuerpo.add_child(scroll)
	_vip_box = VBoxContainer.new()
	_vip_box.add_theme_constant_override("separation", 1)
	_vip_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vip_box)
	_refrescar_vip()


func _agregar_vip() -> void:
	if _vip_input == null:
		return
	var nombre := _vip_input.text.strip_edges()
	if nombre.is_empty():
		return
	var con = _mundo._con
	if con == null or not _estado.adentro:
		_anotar("Connect to the game before adding VIP entries.")
		return
	con.enviar_agregar_vip(nombre)
	_vip_input.clear()
	_anotar("Adding %s to VIP..." % nombre)


func _quitar_vip(guid: int, nombre: String) -> void:
	var con = _mundo._con
	if con == null or not _estado.adentro:
		return
	con.enviar_quitar_vip(guid)
	_anotar("Removing %s from VIP..." % nombre)


func _al_vip_actualizado(_guid: int, _entrada: Dictionary) -> void:
	_refrescar_vip()


func _al_vip_reiniciado() -> void:
	_refrescar_vip()


func _refrescar_vip() -> void:
	if _vip_box == null:
		return
	for hijo in _vip_box.get_children():
		hijo.free()
	var guids: Array = _estado.vip.keys()
	guids.sort()
	if guids.is_empty():
		var vacio := VENTANA.etiqueta("No VIP entries", 9, VENTANA.TENUE)
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vip_box.add_child(vacio)
		return
	for guid in guids:
		var entrada: Dictionary = _estado.vip.get(guid, {})
		var nombre := str(entrada.get("nombre", "Player %d" % int(guid)))
		var conectado := int(entrada.get("estado", 0)) != 0
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 2)
		var etiqueta := VENTANA.etiqueta(
			("● " if conectado else "○ ") + nombre, 9,
			Color(0.35, 0.82, 0.35) if conectado else VENTANA.TENUE)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(etiqueta)
		var quitar := _hacer_boton("x", "Remove %s from VIP" % nombre)
		quitar.custom_minimum_size = Vector2(20, 18)
		quitar.pressed.connect(_quitar_vip.bind(int(guid), nombre))
		fila.add_child(quitar)
		_vip_box.add_child(fila)


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
		if nombre == "Logout":
			boton.pressed.connect(_mundo.solicitar_logout)
		else:
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
	# La lista completa vive dentro del scroll y no se limita a diez criaturas.
	_battle_window.custom_minimum_size = Vector2(190, 108)
	_battle_scroll = ScrollContainer.new()
	_battle_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_battle_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Sin un minimo vertical el VBox interno puede medir el ScrollContainer en
	# cero cuando Battle vive dentro de un dock. El titulo se actualiza, pero
	# las filas quedan fuera del area visible.
	_battle_scroll.custom_minimum_size = Vector2(178, 58)
	_battle_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_window.cuerpo.add_child(_battle_scroll)
	_battle_box = VBoxContainer.new()
	_battle_box.add_theme_constant_override("separation", 3)
	_battle_box.custom_minimum_size.x = 0
	_battle_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_battle_scroll.add_child(_battle_box)
	# Mantener la ventana visible permite ver "No creatures in view" y evita
	# que el dock cambie de ancho cada vez que una criatura entra o sale.
	_battle_window.visible = false


func _armar_chat() -> void:
	var panel = _ventana("Chat", Control.PRESET_BOTTOM_WIDE,
		210, -170, -210, -10)
	_canales_box = HBoxContainer.new()
	_canales_box.add_theme_constant_override("separation", 4)
	_canales_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agregar_boton_canal(0, "Default")
	var chat_off := _hacer_boton("Chat off", "Toggle chat display")
	chat_off.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_off.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chat_off.pressed.connect(func(): _chat.visible = not _chat.visible)
	_canales_box.add_child(chat_off)
	panel.cuerpo.add_child(_canales_box)
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


func _agregar_boton_canal(id: int, nombre: String) -> void:
	if _canales_box == null or _botones_canales.has(id):
		return
	var canal := _hacer_boton(nombre, "Open %s" % nombre)
	canal.custom_minimum_size = Vector2(0, 17)
	canal.add_theme_color_override("font_color", VENTANA.TENUE)
	canal.pressed.connect(_seleccionar_canal.bind(id, nombre))
	# Chat off permanece al final; los canales nuevos se insertan antes.
	var posicion := maxi(0, _canales_box.get_child_count() - 1)
	_canales_box.add_child(canal)
	_canales_box.move_child(canal, posicion)
	_botones_canales[id] = canal


func _quitar_boton_canal(id: int) -> void:
	if id == 0 or not _botones_canales.has(id):
		return
	var boton = _botones_canales[id]
	_botones_canales.erase(id)
	if is_instance_valid(boton):
		boton.queue_free()


func _seleccionar_canal(id: int, nombre: String) -> void:
	_canal_actual = id
	_nombre_canal_actual = nombre
	if id != 0 and _mundo != null and _mundo._con != null \
		and not _estado.canales_abiertos.has(id):
		_mundo._con.enviar_abrir_canal(id)
		_anotar("Opening channel %s..." % nombre)
	if _chat_input != null:
		_chat_input.placeholder_text = "Say in %s..." % nombre \
			if id != 0 else "Say something..."


func _al_canales_actualizados(lista: Array) -> void:
	for id in _botones_canales.keys():
		if int(id) != 0:
			_quitar_boton_canal(int(id))
	for canal in lista:
		_agregar_boton_canal(int(canal.get("id", 0)),
			str(canal.get("nombre", "Channel")))


func _al_canal_abierto(id: int, nombre: String) -> void:
	_agregar_boton_canal(id, nombre)
	_seleccionar_canal(id, nombre)


func _al_canal_cerrado(id: int) -> void:
	_quitar_boton_canal(id)
	if _canal_actual == id:
		_seleccionar_canal(0, "Default")


func _armar_comercio() -> void:
	# Trade no se acopla a los docks: debe quedar visible sobre el mundo,
	# igual que en el cliente clasico, mientras las dos ofertas se actualizan.
	var panel = VENTANA.new("Trade", true)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_top = -145
	panel.offset_right = 210
	panel.offset_bottom = 145
	panel.custom_minimum_size = Vector2(420, 290)
	panel.cerrar_solicitado.connect(_cerrar_comercio)
	_root.add_child(panel)
	_comercio_window = panel

	var ayuda := VENTANA.etiqueta(
		"Both players must accept. The server validates the transfer.", 9,
		VENTANA.TENUE)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.cuerpo.add_child(ayuda)
	var columnas := HBoxContainer.new()
	columnas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columnas.add_theme_constant_override("separation", 8)
	panel.cuerpo.add_child(columnas)
	var columna_propia := _crear_columna_comercio("Your offer")
	columnas.add_child(columna_propia)
	_comercio_propio_box = columna_propia.get_node("Items") as VBoxContainer
	var columna_contraparte := _crear_columna_comercio("Partner offer")
	columnas.add_child(columna_contraparte)
	_comercio_contraparte_box = columna_contraparte.get_node("Items") as VBoxContainer
	var acciones := HBoxContainer.new()
	acciones.alignment = BoxContainer.ALIGNMENT_CENTER
	acciones.add_theme_constant_override("separation", 8)
	var aceptar := _hacer_boton("Accept", "Accept the current trade offer")
	aceptar.pressed.connect(_aceptar_comercio)
	acciones.add_child(aceptar)
	var cancelar := _hacer_boton("Cancel", "Cancel the current trade")
	cancelar.pressed.connect(_cerrar_comercio)
	acciones.add_child(cancelar)
	panel.cuerpo.add_child(acciones)
	panel.visible = false


func _crear_columna_comercio(titulo: String) -> VBoxContainer:
	var columna := VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var encabezado := VENTANA.etiqueta(titulo, 10,
		Color(0.95, 0.82, 0.48))
	encabezado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	columna.add_child(encabezado)
	var lista := VBoxContainer.new()
	lista.name = "Items"
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 3)
	columna.add_child(lista)
	return columna


func _al_comercio_actualizado(nombre: String, propio: bool,
		items: Array) -> void:
	_comercio_nombre = nombre
	if propio:
		_comercio_propio = items.duplicate(true)
	else:
		_comercio_contraparte = items.duplicate(true)
	if _comercio_window == null:
		return
	_comercio_window.fijar_titulo("Trade with %s" % nombre)
	_comercio_window.visible = true
	_refrescar_comercio()


func _al_comercio_cerrado() -> void:
	_comercio_propio.clear()
	_comercio_contraparte.clear()
	_comercio_nombre = ""
	if _comercio_window != null:
		_comercio_window.visible = false


func _refrescar_comercio() -> void:
	if _comercio_propio_box == null or _comercio_contraparte_box == null:
		return
	_refrescar_lista_comercio(_comercio_propio_box, _comercio_propio, false)
	_refrescar_lista_comercio(_comercio_contraparte_box,
		_comercio_contraparte, true)


func _refrescar_lista_comercio(lista: VBoxContainer, items: Array,
		es_contraparte: bool) -> void:
	for hijo in lista.get_children():
		hijo.queue_free()
	if items.is_empty():
		var vacio := VENTANA.etiqueta("(empty)", 9, VENTANA.TENUE)
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lista.add_child(vacio)
		return
	for indice in range(items.size()):
		var cosa: Dictionary = items[indice]
		var fila := HBoxContainer.new()
		fila.custom_minimum_size.y = 34
		var icono := TextureRect.new()
		icono.custom_minimum_size = Vector2(32, 32)
		icono.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icono.texture = icono_para_item(int(cosa.get("cid", 0)))
		icono.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fila.add_child(icono)
		var nombre := str(cosa.get("nombre", "item"))
		var cantidad := int(cosa.get("cantidad", 1))
		var etiqueta := VENTANA.etiqueta(
			("%s x%d" % [nombre, cantidad]) if cantidad > 1 else nombre,
			9)
		etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		etiqueta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(etiqueta)
		var mirar := _hacer_boton("Look", "Look at this trade item")
		mirar.custom_minimum_size.x = 42
		mirar.pressed.connect(_mirar_comercio.bind(es_contraparte, indice))
		fila.add_child(mirar)
		lista.add_child(fila)


func _mirar_comercio(es_contraparte: bool, indice: int) -> void:
	var con = _mundo._con
	if con != null:
		con.enviar_mirar_comercio(es_contraparte, indice)


func _aceptar_comercio() -> void:
	var con = _mundo._con
	if con != null:
		con.enviar_aceptar_comercio()
		_anotar("Trade accepted; waiting for the partner.")


func _cerrar_comercio() -> void:
	var con = _mundo._con
	if con != null and bool(_estado.comercio.get("activo", false)):
		con.enviar_cerrar_comercio()
	if _comercio_window != null:
		_comercio_window.visible = false


func _armar_objetivo() -> void:
	_target_window = _ventana("Target", Control.PRESET_CENTER_TOP,
		-155, 12, 155, 96)
	_target_window.visible = false
	_target_window.custom_minimum_size = Vector2(300, 96)
	var contenido := HBoxContainer.new()
	contenido.add_theme_constant_override("separation", 7)
	contenido.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contenido.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_target_window.cuerpo.add_child(contenido)
	_target_sprite = TextureRect.new()
	_target_sprite.custom_minimum_size = Vector2(58, 58)
	_target_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_target_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_target_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_target_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contenido.add_child(_target_sprite)
	var detalles := VBoxContainer.new()
	detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	detalles.add_theme_constant_override("separation", 4)
	contenido.add_child(detalles)
	var linea_nombre := HBoxContainer.new()
	linea_nombre.add_theme_constant_override("separation", 4)
	linea_nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.add_child(linea_nombre)
	_target_name = VENTANA.etiqueta("", 11)
	_target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_target_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_target_name.custom_minimum_size = Vector2(135, 20)
	_target_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_target_name.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_target_name.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_target_name.add_theme_constant_override("outline_size", 3)
	linea_nombre.add_child(_target_name)
	_target_marcas = _agregar_marcas(linea_nombre, 14.0)
	_target_bar = BARRA.new(Color(0.78, 0.18, 0.18), "", 14)
	detalles.add_child(_target_bar)


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
	_actualizar_objetivo()
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
		"Speed": str(_velocidad_propia()),
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
	var ids_actuales: Array = []
	var ids: Array = _estado.criaturas.keys()
	ids.sort()
	for id in ids:
		if int(id) == _estado.mi_id:
			continue
		var criatura: Dictionary = _estado.criaturas[id]
		if not _criatura_en_piso_actual(criatura) \
				or not _criatura_a_la_vista(criatura):
			continue
		ids_actuales.append(int(id))

	# Los golpes solo cambian nombre/vida. Mantener las mismas filas evita que
	# el sprite desaparezca un frame cada vez que llega una actualizacion 0xA0.
	# Solo se reconstruye cuando entra o sale una criatura, o cambiamos de piso.
	if ids_actuales == _battle_ids and _battle_rows.size() == ids_actuales.size():
		for id in ids_actuales:
			var criatura_actual: Dictionary = _estado.criaturas.get(id, {})
			_actualizar_datos_fila_battle(id, criatura_actual)
		_battle_window.visible = _estado.adentro
		_battle_window.fijar_titulo("Battle (%d)" % ids_actuales.size())
		_actualizar_seleccion_battle()
		return

	_battle_sprite_slots.clear()
	_battle_rows.clear()
	_battle_name_labels.clear()
	_battle_health_bars.clear()
	_battle_marcas.clear()
	_battle_ids = ids_actuales.duplicate()
	for hijo in _battle_box.get_children():
		hijo.free()
	var puestos := 0
	for id in ids_actuales:
		_agregar_fila_battle(id, _estado.criaturas[id])
		puestos += 1
	if puestos == 0:
		_battle_box.add_child(VENTANA.etiqueta("No creatures in view", 10,
			VENTANA.TENUE))
	_battle_window.visible = _estado.adentro
	_battle_window.fijar_titulo("Battle (%d)" % puestos)
	_actualizar_seleccion_battle()


func _criatura_en_piso_actual(criatura: Dictionary) -> bool:
	if _estado == null:
		return false
	var posicion = criatura.get("pos", null)
	return posicion is Vector3i and posicion.z == _estado.mi_pos.z


func _criatura_a_la_vista(criatura: Dictionary) -> bool:
	if _estado == null:
		return false
	var posicion = criatura.get("pos", null)
	if not posicion is Vector3i or not _estado.mi_pos is Vector3i:
		return false
	# Mantener esta comprobacion alineada con ProtocolGame::canSee() del
	# servidor. El Battle List no debe conservar criaturas fuera del viewport
	# aunque sigan en el diccionario por un mensaje de movimiento anterior.
	var offset_z: int = _estado.mi_pos.z - posicion.z
	return posicion.x >= _estado.mi_pos.x - VISTA_X_ANTES + offset_z \
			and posicion.x <= _estado.mi_pos.x + VISTA_X_DESPUES + offset_z \
			and posicion.y >= _estado.mi_pos.y - VISTA_Y_ANTES + offset_z \
			and posicion.y <= _estado.mi_pos.y + VISTA_Y_DESPUES + offset_z


func _actualizar_objetivo() -> void:
	if _objetivo_id <= 0:
		return
	if mostrar_objetivo(_objetivo_id):
		return
	_al_objetivo_cancelado()
	if _mundo != null and _mundo.has_method("limpiar_objetivo_visual"):
		_mundo.limpiar_objetivo_visual()


func _al_objetivo_cancelado() -> void:
	_objetivo_id = 0
	if _target_window != null:
		_target_window.visible = false
	_actualizar_seleccion_battle()


func _agregar_fila_battle(id: int, criatura: Dictionary) -> void:
	var fila := Button.new()
	fila.flat = true
	fila.focus_mode = Control.FOCUS_NONE
	fila.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	fila.custom_minimum_size.y = 40
	fila.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.clip_contents = false
	fila.tooltip_text = "Left click: talk  |  Right click: menu" \
		if _mundo != null and _mundo.has_method("es_npc") and _mundo.es_npc(id) \
		else "Left click: attack  |  Right click: menu"
	fila.gui_input.connect(func(evento): _input_battle(evento, id))
	_battle_rows[id] = fila
	_aplicar_estilo_fila_battle(fila, id)
	var caja := HBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_FULL_RECT)
	caja.offset_left = 5
	caja.offset_top = 3
	caja.offset_right = -5
	caja.offset_bottom = -3
	caja.add_theme_constant_override("separation", 5)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(caja)
	var sprite := TextureRect.new()
	sprite.custom_minimum_size = Vector2(36, 34)
	sprite.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(sprite)
	_battle_sprite_slots[id] = sprite
	_actualizar_sprite_battle(sprite, criatura, 0)
	var detalles := VBoxContainer.new()
	detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detalles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(detalles)
	var linea := HBoxContainer.new()
	linea.add_theme_constant_override("separation", 3)
	linea.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	linea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detalles.add_child(linea)
	var nombre := VENTANA.etiqueta(_nombre_criatura(id, criatura), 10)
	nombre.custom_minimum_size.y = 14
	nombre.clip_text = false
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nombre.add_theme_color_override("font_color", Color(0.96, 0.96, 0.96))
	nombre.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.95))
	nombre.add_theme_constant_override("outline_size", 2)
	linea.add_child(nombre)
	_battle_name_labels[id] = nombre
	_battle_marcas[id] = _agregar_marcas(linea, 11.0)
	_actualizar_marcas(_battle_marcas[id], criatura)
	var porcentaje := clampf(float(criatura.get("vida", 100)) / 100.0, 0.0, 1.0)
	var barra = BARRA.new(Color(0.68, 0.18, 0.18), "", 7)
	barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barra.fijar(porcentaje, "%d%%" % int(porcentaje * 100.0))
	detalles.add_child(barra)
	_battle_health_bars[id] = barra
	_battle_box.add_child(fila)
	_aplicar_estilo_fila_battle(fila, id)


func _actualizar_datos_fila_battle(id: int, criatura: Dictionary) -> void:
	if criatura.is_empty():
		return
	var nombre: Label = _battle_name_labels.get(id)
	if is_instance_valid(nombre):
		nombre.text = _nombre_criatura(id, criatura)
	var barra = _battle_health_bars.get(id)
	if is_instance_valid(barra):
		var porcentaje := clampf(float(criatura.get("vida", 100)) / 100.0,
			0.0, 1.0)
		barra.fijar(porcentaje, "%d%%" % int(porcentaje * 100.0))
	var sprite: TextureRect = _battle_sprite_slots.get(id)
	if is_instance_valid(sprite):
		_actualizar_sprite_battle(sprite, criatura, 0)
	_actualizar_marcas(_battle_marcas.get(id, {}), criatura)


func _agregar_marcas(padre: Control, lado: float) -> Dictionary:
	"""Crea la calavera y el escudo de party de una criatura en ese orden."""
	var marcas := {
		MARCA.CALAVERA: MARCA.new(MARCA.CALAVERA, lado),
		MARCA.ESCUDO: MARCA.new(MARCA.ESCUDO, lado),
	}
	for clase in marcas:
		padre.add_child(marcas[clase])
	return marcas


func _actualizar_marcas(marcas: Dictionary, criatura: Dictionary) -> void:
	"""Solo copia lo que el servidor confirmo; una ausencia no se rellena."""
	for clase in marcas:
		var marca = marcas[clase]
		if is_instance_valid(marca):
			marca.mostrar(int(criatura.get(clase, 0)))


func _velocidad_propia() -> int:
	"""La velocidad del personaje llega en `AddCreature` y en `0x8F`, no en el
	`0xA0` de stats: se lee del estado de criatura de `mi_id`."""
	if _estado == null:
		return 0
	var propia: Dictionary = _estado.criaturas.get(_estado.mi_id, {})
	return int(propia.get("velocidad", 0))


func _cargar_nombres_criaturas() -> void:
	var archivo := FileAccess.open(ARCHIVO_NOMBRES_CRIATURAS, FileAccess.READ)
	if archivo == null:
		return
	var datos = JSON.parse_string(archivo.get_as_text())
	if typeof(datos) == TYPE_DICTIONARY:
		_nombres_criaturas = datos


func _nombre_criatura(id: int, criatura: Dictionary) -> String:
	var nombre := str(criatura.get("nombre", "")).strip_edges()
	if not nombre.is_empty():
		return nombre
	var tipo := int(criatura.get("apariencia", 0))
	var nombre_por_apariencia := str(_nombres_criaturas.get(str(tipo), ""))
	if not nombre_por_apariencia.is_empty():
		return nombre_por_apariencia
	return "Creature %d" % id


func _estilo_fila_battle(seleccionada: bool, hover: bool = false) -> StyleBoxFlat:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.18, 0.15, 0.12, 0.95) if hover \
		else Color(0.08, 0.085, 0.11, 0.85)
	estilo.set_corner_radius_all(2)
	if seleccionada:
		# Marco rojo claro: la fila que se esta atacando se reconoce incluso
		# cuando el panel Target queda fuera de la zona visible.
		estilo.border_color = Color(1.0, 0.16, 0.12, 0.98)
		estilo.set_border_width_all(2)
	return estilo


func _aplicar_estilo_fila_battle(fila: Button, id: int) -> void:
	if not is_instance_valid(fila):
		return
	var seleccionada := id == _objetivo_id
	fila.add_theme_stylebox_override("normal",
		_estilo_fila_battle(seleccionada))
	fila.add_theme_stylebox_override("hover",
		_estilo_fila_battle(seleccionada, true))
	fila.add_theme_stylebox_override("pressed",
		_estilo_fila_battle(seleccionada, true))
	fila.add_theme_stylebox_override("focus",
		_estilo_fila_battle(seleccionada))


# --------------------------------------------------------------------
#  Menu de criatura y party
#
#  Este servidor no manda ningun paquete de party: lo unico que llega es el
#  escudo de cada criatura por el `0x91`. La party, entonces, se lee de los
#  escudos confirmados (`protocolo-red` 1.4.0) y nunca de una lista propia.
# --------------------------------------------------------------------
func es_jugador(id: int) -> bool:
	return id >= ID_MINIMO_JUGADOR and id < ID_MINIMO_MONSTRUO


func _escudo_de(id: int) -> int:
	return int(_estado.criaturas.get(id, {}).get("escudo_party", 0))


func acciones_de_criatura(id: int) -> Array:
	"""Que se le puede hacer a esta criatura, segun el estado confirmado.

	Devuelve pares `[accion, texto]`. Se expone para que la regresion pueda
	comprobar el menu sin abrir una ventana."""
	var acciones: Array = [["atacar", "Attack"], ["seguir", "Follow"]]
	if not es_jugador(id) or id == _estado.mi_id:
		return acciones
	acciones.append(["comerciar", "Trade with %s" % _nombre_de(id)])
	var suyo := _escudo_de(id)
	var mio := _escudo_de(_estado.mi_id)
	var en_party := mio == 3 or mio == 4
	var soy_lider := mio == 4
	match suyo:
		1:
			# Nos invito: unirse es entrar a SU party.
			acciones.append(["unirse", "Join Party"])
		2:
			# Lo invitamos nosotros y todavia no acepto.
			acciones.append(["revocar", "Revoke Invitation"])
		3:
			if soy_lider:
				acciones.append(["liderazgo", "Pass Leadership"])
		4:
			pass   # es el lider de nuestra party; no hay accion sobre el
		_:
			if not en_party or soy_lider:
				acciones.append(["invitar", "Invite to Party"])
	if en_party:
		acciones.append(["salir", "Leave Party"])
	return acciones


func _abrir_menu_criatura(id: int, donde: Vector2) -> void:
	var acciones := acciones_de_criatura(id)
	if _menu_criatura == null:
		_menu_criatura = PopupMenu.new()
		_root.add_child(_menu_criatura)
	_menu_criatura.clear()
	if _menu_criatura.id_pressed.is_connected(_al_menu_criatura):
		_menu_criatura.id_pressed.disconnect(_al_menu_criatura)
	_menu_criatura.id_pressed.connect(_al_menu_criatura.bind(id))
	var indice := 0
	for accion in acciones:
		if accion[0] == "invitar" or accion[0] == "unirse" \
				or accion[0] == "salir":
			_menu_criatura.add_separator()
		_menu_criatura.add_item(str(accion[1]), indice)
		indice += 1
	_menu_criatura.set_meta("acciones", acciones)
	_menu_criatura.position = Vector2i(donde)
	_menu_criatura.reset_size()
	_menu_criatura.popup()


func _al_menu_criatura(indice: int, id: int) -> void:
	var acciones: Array = _menu_criatura.get_meta("acciones", [])
	if indice < 0 or indice >= acciones.size():
		return
	ejecutar_accion_criatura(str(acciones[indice][0]), id)


func ejecutar_accion_criatura(accion: String, id: int) -> void:
	"""Manda la intencion y nada mas: el resultado lo confirma el servidor con
	los escudos, y hasta entonces la interfaz no cambia de estado."""
	var con = _mundo._con if _mundo != null else null
	match accion:
		"atacar":
			_seleccionar_objetivo(id, false)
			return
		"seguir":
			_seleccionar_objetivo(id, true)
			return
	if accion == "comerciar":
		# Primera mitad del trade: se recuerda a quien y el jugador elige el
		# objeto con el clic siguiente, igual que el "use with" de runas.
		_trade_pendiente = {"id": id, "nombre": _nombre_de(id)}
		_anotar("Trade with %s: click the item you want to offer."
			% _nombre_de(id))
		return
	if con == null:
		return
	match accion:
		"invitar":
			con.enviar_invitar_a_party(id)
			_anotar("Inviting %s to your party." % _nombre_de(id))
		"unirse":
			con.enviar_unirse_a_party(id)
			_anotar("Joining the party of %s." % _nombre_de(id))
		"revocar":
			con.enviar_revocar_invitacion_party(id)
			_anotar("Revoking the invitation of %s." % _nombre_de(id))
		"liderazgo":
			con.enviar_pasar_liderazgo_party(id)
			_anotar("Passing the party leadership to %s." % _nombre_de(id))
		"salir":
			con.enviar_salir_de_party()
			_anotar("Leaving the party.")


func _nombre_de(id: int) -> String:
	return _nombre_criatura(id, _estado.criaturas.get(id, {}))


func _ofrecer_en_comercio(tipo: String, id_contenedor: int, slot: int,
		cosa: Dictionary) -> void:
	"""Manda el `0x7D` con el objeto elegido y el jugador ya recordado.

	Quien decide si ese objeto se puede ofrecer, si hay distancia y si el otro
	acepta es el servidor; aca solo se arma la intencion."""
	var id := int(_trade_pendiente.get("id", 0))
	var nombre_otro := str(_trade_pendiente.get("nombre", ""))
	_trade_pendiente.clear()
	var con = _mundo._con if _mundo != null else null
	if con == null or id <= 0:
		return
	if not _estado.criaturas.has(id):
		_anotar("%s is no longer in view." % nombre_otro)
		return
	con.enviar_solicitar_comercio(
		_posicion_de_item(tipo, id_contenedor, slot),
		int(cosa.get("cid", 0)), 0, id)
	_anotar("Offering %s to %s." % [
		str(cosa.get("nombre", "item")), nombre_otro])


func _actualizar_seleccion_battle() -> void:
	for id in _battle_rows:
		var fila: Button = _battle_rows[id]
		_aplicar_estilo_fila_battle(fila, int(id))


func _actualizar_sprite_battle(sprite: TextureRect, criatura: Dictionary,
		fase: int) -> void:
	if _sprites == null or not is_instance_valid(sprite):
		return
	var tipo := int(criatura.get("apariencia", 0))
	var direccion := int(criatura.get("direccion", 2))
	var cuadro: Dictionary = _sprites.cuadro_outfit(tipo, direccion, fase)
	if cuadro.is_empty():
		# Un cambio de direccion o una trama incompleta no debe dejar la fila
		# vacia. Conservamos el ultimo frame valido hasta recibir uno nuevo.
		return
	var atlas := sprite.texture as AtlasTexture
	if atlas == null or atlas.atlas != cuadro["lamina"]:
		atlas = AtlasTexture.new()
		atlas.atlas = cuadro["lamina"]
		sprite.texture = atlas
	# Las laminas generadas por sprites772.gd son de 2048x2048.
	var lado := 2048.0
	atlas.region = Rect2(
		float(cuadro["corrimiento"].x) * lado,
		float(cuadro["corrimiento"].y) * lado,
		float(cuadro["escala"].x) * lado,
		float(cuadro["escala"].y) * lado)


func _process(delta: float) -> void:
	if _sprites == null:
		return
	_battle_anim_tiempo += delta
	if _battle_anim_tiempo < 0.14:
		return
	_battle_anim_tiempo = 0.0
	var fase := int(Time.get_ticks_msec() / 140)
	for id in _battle_sprite_slots:
		var sprite: TextureRect = _battle_sprite_slots[id]
		var criatura: Dictionary = _estado.criaturas.get(id, {})
		if not criatura.is_empty():
			_actualizar_sprite_battle(sprite, criatura, fase)
	if _target_sprite != null and _objetivo_id > 0:
		var objetivo: Dictionary = _estado.criaturas.get(_objetivo_id, {})
		if not objetivo.is_empty():
			_actualizar_sprite_battle(_target_sprite, objetivo, fase)


func _input_battle(evento: InputEvent, id: int) -> void:
	if not evento is InputEventMouseButton or not evento.pressed:
		return
	if evento.button_index == MOUSE_BUTTON_LEFT:
		# Handle the click here instead of relying on Button.pressed. The row is
		# rebuilt whenever the creature state changes, and a native Button can
		# lose its release signal during that refresh.
		_seleccionar_objetivo(id, false)
		get_viewport().set_input_as_handled()
	elif evento.button_index == MOUSE_BUTTON_RIGHT:
		# Como en el cliente clasico, el boton derecho sobre una fila del
		# Battle abre el menu de la criatura. Seguirla sigue estando ahi.
		_abrir_menu_criatura(id, evento.global_position)
		get_viewport().set_input_as_handled()


func mostrar_objetivo(id: int) -> bool:
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	if criatura.is_empty() or not _criatura_en_piso_actual(criatura) \
			or not _criatura_a_la_vista(criatura):
		return false
	_objetivo_id = id
	_target_window.visible = true
	_actualizar_sprite_battle(_target_sprite, criatura, 0)
	_target_name.text = _nombre_criatura(id, criatura)
	_actualizar_marcas(_target_marcas, criatura)
	var porcentaje := clampf(float(criatura.get("vida", 100)) / 100.0, 0.0, 1.0)
	_target_bar.fijar(porcentaje, "%d%%" % int(porcentaje * 100.0))
	_actualizar_seleccion_battle()
	return true


func _seleccionar_objetivo(id: int, seguir: bool) -> void:
	var criatura: Dictionary = _estado.criaturas.get(id, {})
	if criatura.is_empty():
		return
	if not seguir and _mundo.esta_esperando_uso_con():
		if _mundo.usar_con_criatura_pendiente(id):
			return
	mostrar_objetivo(id)
	if seguir:
		var con = _mundo._con
		if con != null:
			con.enviar_seguir(id)
			_anotar("Following %s." % _target_name.text)
		return
	# `atacar_criatura` owns the connection/range/path checks. The UI must not
	# gate the call by peeking at the connection, otherwise a valid Battle row
	# click can be swallowed while the connection is being replaced on login.
	if _mundo.atacar_criatura(id):
		var accion := "Talking to" if _mundo.has_method("es_npc") \
			and _mundo.es_npc(id) else "Attacking"
		_anotar("%s %s." % [accion, _target_name.text])


func _al_inventario_actualizado(_slot: int, _cosa: Dictionary) -> void:
	_refrescar()


func _al_estadisticas_actualizadas(_datos: Dictionary) -> void:
	_refrescar()


func _al_habilidades_actualizadas(_datos: Dictionary) -> void:
	_refrescar()


func _al_mensaje_servidor(texto: String) -> void:
	# Conservamos tambien los 0xB4 en el historial: los mensajes de look y los
	# rechazos deben poder leerse y copiarse aunque el aviso flotante expire.
	_anotar(texto)


func _al_habla(quien: String, texto: String, _clase: int) -> void:
	_anotar("%s: %s" % [quien, texto])


func _anotar(texto: String) -> void:
	if _chat != null:
		_chat.append_text(texto + "\n")
		# RichTextLabel actualiza sus líneas en el siguiente frame; desplazarlo
		# después evita que cada mensaje nuevo deje visible el primero.
		_chat.call_deferred("scroll_to_line", _chat.get_line_count())


func _decir(texto: String) -> void:
	var limpio := texto.strip_edges()
	if limpio.is_empty():
		_chat_input.clear()
		_chat_input.release_focus()
		return
	var con = _mundo._con
	if con != null:
		if _canal_actual == 0:
			# El opcode extendido F2 del servidor conserva el auto-walk mientras
			# se escribe en Default.
			con.enviar_hablar(limpio)
			_anotar("You: " + limpio)
		else:
			# Los canales usan parseSay 7.72: clase amarilla + uint16 channel.
			con.enviar_hablar_en_canal(_canal_actual, limpio)
			_anotar("[%s] You: %s" % [_nombre_canal_actual, limpio])
	_chat_input.clear()
	_chat_input.release_focus()


func activar_chat() -> void:
	if _chat_input == null or not _mundo._estado.adentro:
		return
	# Escribir no debe cancelar el auto-camino ya enviado al servidor. El
	# cliente solo bloquea nuevos pasos mientras el campo tiene el foco; el
	# movimiento confirmado sigue su curso de forma natural.
	_chat_input.grab_focus()
	_chat_input.caret_column = _chat_input.text.length()


func preparar_chat(texto: String) -> void:
	if _chat_input == null or not _mundo._estado.adentro:
		return
	_chat_input.text = texto
	activar_chat()


func cancelar_chat() -> void:
	if _chat_input == null:
		return
	_chat_input.clear()
	_chat_input.release_focus()


func esta_escribiendo() -> bool:
	return _chat_input != null and _chat_input.has_focus()


func esta_sobre_interfaz() -> bool:
	"""Indica si la rueda esta sobre una ventana de la UI y no sobre el mapa."""
	var control := get_viewport().gui_get_hovered_control()
	if control == null or control == _zona_suelo or _root == null:
		return false
	return _root.is_ancestor_of(control)


func icono_para_item(cid: int) -> Texture2D:
	var cuadro: Dictionary = _sprites.cuadro_item(cid, 0)
	# El protocolo correcto transporta client IDs, pero algunos objetos
	# antiguos o datos de prueba pueden llegar con el ID interno del servidor.
	# La conversion solo se aplica cuando no existe un sprite para el valor
	# recibido, asi no altera items reales que compartan ese numero.
	if cuadro.is_empty() and IDS_MONEDAS_SERVIDOR.has(cid):
		cuadro = _sprites.cuadro_item(int(IDS_MONEDAS_SERVIDOR[cid]), 0)
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


func color_para_liquido(color_liquido: int) -> Color:
	"""Color visual del byte de liquido que manda el protocolo 7.72.

	El sprite del vial es compartido por todos los fluidos. El byte adicional
	que lee mapa772.gd es el que permite pintar la variante correcta en la UI.
	Se devuelve con alpha para que el sprite original del vial conserve sus
	detalles y el tinte solo lo coloree.
	"""
	match color_liquido:
		1: # water
			return Color(0.20, 0.58, 1.00, 0.68)
		2: # blood / life fluid
			return Color(1.00, 0.12, 0.08, 0.68)
		3: # beer, wine, mud and similar amber fluids
			return Color(1.00, 0.67, 0.10, 0.62)
		4: # slime
			return Color(0.18, 0.88, 0.24, 0.68)
		5: # lemonade / urine
			return Color(0.94, 0.86, 0.20, 0.62)
		6: # milk
			return Color(0.96, 0.96, 1.00, 0.42)
		7: # mana fluid provisional: usar azul de agua mientras definimos la paleta
			return Color(0.20, 0.58, 1.00, 0.70)
		_:
			return Color(1.0, 1.0, 1.0, 0.0)


func usar_inventario(slot: int, cosa: Dictionary) -> void:
	usar_ranura("inventario", -1, slot, cosa)


func usar_ranura(tipo: String, id_contenedor: int, slot: int,
		cosa: Dictionary) -> void:
	if not _trade_pendiente.is_empty():
		# Segunda mitad del trade: ya se eligio a quien, ahora el objeto.
		_ofrecer_en_comercio(tipo, id_contenedor, slot, cosa)
		return
	if _es_runa(cosa) or bool(cosa.get("liquido", false)):
		if _mundo.preparar_uso_con(tipo, id_contenedor, slot, cosa):
			var nombre := str(cosa.get("nombre", "spell rune"))
			var destino := "your character" \
				if bool(cosa.get("liquido", false)) \
				else "a creature or map tile"
			_anotar("Use with %s: click %s." % [nombre, destino])
		return
	if _es_anillo(cosa):
		_equipar_anillo(tipo, id_contenedor, slot, cosa)
		return
	var con = _mundo._con
	if con != null:
		var posicion := _posicion_de_item(tipo, id_contenedor, slot)
		con.enviar_usar_item(posicion, int(cosa.get("cid", 0)), 0, 0)
	_anotar("Using %s..." % str(cosa.get("nombre", "item")))


func abrir_contenedor_desde_ranura(tipo: String, id_contenedor: int,
		slot: int, cosa: Dictionary) -> void:
	"""Abre una mochila/body/container con Shift+clic derecho.

	El ultimo byte de 0x82 es el indice de la ventana. Se escoge uno libre
	para que cada apertura nueva llegue como un panel independiente.
	"""
	if not bool(cosa.get("contenedor", false)) or _mundo._con == null:
		return
	var indice := _indice_contenedor_libre()
	if indice < 0:
		_anotar("No more container windows available.")
		return
	_mundo._con.enviar_usar_item(_posicion_de_item(tipo, id_contenedor, slot),
		int(cosa.get("cid", 0)), 0, indice)
	_anotar("Opening %s in a new window..." %
		str(cosa.get("nombre", "container")))


func _indice_contenedor_libre() -> int:
	for indice in range(16):
		if not _estado.contenedores.has(indice):
			return indice
	return -1


static func _es_anillo(cosa: Dictionary) -> bool:
	return str(cosa.get("nombre", "")).strip_edges().to_lower().ends_with("ring")


func _equipar_anillo(tipo: String, id_contenedor: int, slot: int,
		cosa: Dictionary) -> void:
	if tipo == "inventario" and slot == SLOT_ANILLO:
		_anotar("%s is already equipped." % str(cosa.get("nombre", "ring")))
		return
	var con = _mundo._con
	if con == null:
		return
	con.enviar_mover_ubicacion(_posicion_de_item(tipo, id_contenedor, slot),
		int(cosa.get("cid", 0)), 0,
		Vector3i(0xFFFF, SLOT_ANILLO, 0), 1)
	_anotar("Equipping %s..." % str(cosa.get("nombre", "ring")))


static func _es_runa(cosa: Dictionary) -> bool:
	# En 7.72 todos los objetos de las runas del servidor se anuncian como
	# "spell rune"; el client id es distinto para cada dibujo.
	return str(cosa.get("nombre", "")).strip_edges().to_lower() == "spell rune"


static func _es_cambio_de_moneda(anterior: Dictionary,
		nuevo: Dictionary) -> bool:
	if anterior.is_empty() or int(anterior.get("cid", 0)) not in IDS_MONEDAS:
		return false
	if nuevo.is_empty():
		return true
	return int(nuevo.get("cid", 0)) not in IDS_MONEDAS \
		or int(anterior.get("cid", 0)) != int(nuevo.get("cid", 0)) \
		or int(anterior.get("cantidad", 1)) != int(nuevo.get("cantidad", 1))


func mirar_inventario(slot: int, cosa: Dictionary) -> void:
	mirar_ranura("inventario", -1, slot, cosa)


func mirar_ranura(tipo: String, id_contenedor: int, slot: int,
		cosa: Dictionary) -> void:
	_anotar("You see %s in inventory slot %d." % [
		str(cosa.get("nombre", "item")), slot])
	if _mundo._con != null and _estado.adentro:
		# El mismo 0x8C sirve para inventario y contenedores. En una
		# mochila el slot va en Z de la posicion especial 0xFFFF/0x40.
		var posicion := _posicion_de_item(tipo, id_contenedor, slot)
		_mundo._con.enviar_mirar(posicion, int(cosa.get("cid", 0)), 0)


func cancelar_uso_con() -> bool:
	if not _trade_pendiente.is_empty():
		_anotar("Trade with %s cancelled." % str(_trade_pendiente.get("nombre", "")))
		_trade_pendiente.clear()
		return true
	if _mundo == null or not _mundo.esta_esperando_uso_con():
		return false
	_mundo.cancelar_uso_con()
	return true


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
	if _es_pila_divisible(datos):
		_pedir_cantidad_movimiento(datos, func(cantidad: int):
			_enviar_movimiento_a_ranura(datos, tipo_destino, id_destino,
				ranura_destino, cantidad))
		return
	_enviar_movimiento_a_ranura(datos, tipo_destino, id_destino,
		ranura_destino, int(datos.get("cantidad", 1)))


func _enviar_movimiento_a_ranura(datos: Dictionary, tipo_destino: String,
		id_destino: int, ranura_destino: int, cantidad: int) -> void:
	var tipo_origen: String = str(datos.get("tipo", "inventario"))
	var id_origen: int = int(datos.get("contenedor", -1))
	var ranura_origen: int = int(datos.get("slot", -1))
	var total := maxi(1, int(datos.get("cantidad", 1)))
	var cantidad_real := clampi(cantidad, 1, mini(255, total))
	var con = _mundo._con
	if con == null:
		return
	var origen := _posicion_de_item(tipo_origen, id_origen, ranura_origen)
	var destino := _posicion_de_item(tipo_destino, id_destino, ranura_destino)
	con.enviar_mover_ubicacion(origen, int(datos.get("cid", 0)), 0,
		destino, cantidad_real)


func _es_pila_divisible(datos: Dictionary) -> bool:
	return bool(datos.get("apilable", false)) \
		and int(datos.get("cantidad", 1)) > 1


func _pedir_cantidad_movimiento(datos: Dictionary, accion: Callable) -> void:
	"""Pide la cantidad sin inventar el resultado del movimiento.

	El unico efecto que produce la confirmacion es enviar 0x78 con el count
	seleccionado. La respuesta y el estado final siguen viniendo del servidor.
	"""
	if is_instance_valid(_dialogo_cantidad):
		_dialogo_cantidad.queue_free()
	var total := clampi(int(datos.get("cantidad", 1)), 1, 255)
	var dialogo := ConfirmationDialog.new()
	_dialogo_cantidad = dialogo
	dialogo.title = "Move stack"
	dialogo.dialog_text = "%s (%d available)\nHow many do you want to move?" % [
		str(datos.get("nombre", "item")), total]
	var selector := SpinBox.new()
	selector.min_value = 1
	selector.max_value = total
	selector.step = 1
	selector.value = total
	selector.custom_minimum_size = Vector2(170, 0)
	# Godot 4.7 no expone un get_vbox() publico en ConfirmationDialog. El
	# popup tiene un tamano fijo y el selector se coloca dentro del area libre
	# debajo del texto nativo del dialogo.
	selector.position = Vector2(58, 76)
	dialogo.add_child(selector)
	dialogo.confirmed.connect(func():
		_dialogo_cantidad = null
		accion.call(clampi(int(selector.value), 1, total))
		dialogo.queue_free())
	dialogo.canceled.connect(func():
		_dialogo_cantidad = null
		dialogo.queue_free())
	add_child(dialogo)
	dialogo.popup_centered(Vector2(300, 150))


func _posicion_de_item(tipo: String, id_contenedor: int, ranura: int) -> Vector3i:
	if tipo == "contenedor":
		# protocolgame.cpp/internalGetThing distingue un container por el bit
		# 0x40 de la posicion Y, igual que internalGetPosition al servidor.
		return Vector3i(0xFFFF, 0x40 | id_contenedor, ranura)
	return Vector3i(0xFFFF, ranura, 0)


func _soltar_item_en_mundo(posicion_mouse: Vector2, datos: Dictionary) -> void:
	if _es_pila_divisible(datos):
		_pedir_cantidad_movimiento(datos, func(cantidad: int):
			_mundo.soltar_inventario_en_mouse(posicion_mouse, datos, cantidad))
		return
	_mundo.soltar_inventario_en_mouse(posicion_mouse, datos)


func recibir_objeto_del_mundo(posicion_mouse: Vector2, origen: Vector3i,
		datos: Dictionary) -> bool:
	"""Acepta un item arrastrado desde el mapa sobre un slot del HUD."""
	var destino := _ranura_bajo_mouse(posicion_mouse)
	if destino.is_empty():
		return false
	var objeto: Dictionary = datos.get("cosa", {})
	var pila := int(datos.get("stackpos", -1))
	if objeto.get("tipo") != "item" or pila < 0:
		return false
	if _es_pila_divisible(objeto):
		_pedir_cantidad_movimiento(objeto, func(cantidad: int):
			_mundo.recoger_objeto_en_ranura(origen, datos, pila,
				str(destino.get("tipo", "inventario")),
				int(destino.get("contenedor", -1)),
				int(destino.get("slot", -1)), cantidad))
		return true
	return _mundo.recoger_objeto_en_ranura(origen, datos, pila,
		str(destino.get("tipo", "inventario")),
		int(destino.get("contenedor", -1)), int(destino.get("slot", -1)))


func _ranura_bajo_mouse(posicion_mouse: Vector2) -> Dictionary:
	for slot in _slots:
		var ranura = _slots[slot]
		if is_instance_valid(ranura) and ranura.visible \
				and ranura.get_global_rect().has_point(posicion_mouse):
			return {"tipo": "inventario", "contenedor": -1, "slot": int(slot)}
	for id_contenedor in _slots_contenedor:
		var por_ranura: Dictionary = _slots_contenedor[id_contenedor]
		for slot in por_ranura:
			var ranura = por_ranura[slot]
			if is_instance_valid(ranura) and ranura.visible \
					and ranura.get_global_rect().has_point(posicion_mouse):
				return {"tipo": "contenedor", "contenedor": int(id_contenedor),
					"slot": int(slot)}
	return {}


func _al_contenedor_actualizado(id: int, datos: Dictionary) -> void:
	if not _ventanas_contenedor.has(id):
		var ventana = VENTANA.new("Container", true)
		# El contenido vive dentro de un ScrollContainer, por lo que la ventana
		# puede hacerse pequena sin que la grilla fuerce a mostrar todas las
		# ranuras a la vez.
		ventana.custom_minimum_size = Vector2(190, 108)
		ventana.reordenable = true
		ventana.pidio_reordenar.connect(_reacomodar.bind(ventana))
		ventana.tamano_cambio.connect(func(_nuevo: Vector2):
			_ajustar_columnas())
		ventana.cerrar_solicitado.connect(func(): _cerrar_contenedor(id))
		_dock_der_interno.add_child(ventana)
		# Las mochilas nuevas siempre se apilan abajo del panel derecho, dejando
		# Battle y las ventanas ya abiertas en su sitio.
		_dock_der_interno.move_child(ventana, _dock_der_interno.get_child_count() - 1)
		_ventanas_contenedor[id] = ventana
		_ajustar_columnas()
	var anterior: Dictionary = _contenedores_visuales.get(id, {})
	_refrescar_contenedor(id, datos, anterior)
	_contenedores_visuales[id] = datos.duplicate(true)


func _volver_contenedor(id: int) -> void:
	var con = _mundo._con
	if con == null:
		return
	con.enviar_subir_contenedor(id)


func _refrescar_contenedor(id: int, datos: Dictionary,
		anterior: Dictionary = {}) -> void:
	if not _ventanas_contenedor.has(id):
		return
	var ventana = _ventanas_contenedor[id]
	ventana.fijar_titulo("%s [%d]" % [str(datos.get("nombre", "Container")), id])
	for hijo in ventana.cuerpo.get_children():
		# El contenido se reconstruye al llegar cada actualización del servidor.
		# Liberarlo de inmediato evita que el scroll anterior quede superpuesto
		# durante un frame y oculte la primera fila de la mochila.
		hijo.free()
	_slots_contenedor[id] = {}
	if bool(datos.get("tiene_padre", false)):
		var navegacion := HBoxContainer.new()
		navegacion.add_theme_constant_override("separation", 4)
		var volver := Button.new()
		volver.text = "< Back"
		volver.flat = true
		volver.focus_mode = Control.FOCUS_NONE
		volver.custom_minimum_size = Vector2(0, 19)
		volver.add_theme_font_size_override("font_size", 9)
		volver.pressed.connect(_volver_contenedor.bind(id))
		navegacion.add_child(volver)
		ventana.cuerpo.add_child(navegacion)
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollRanuras"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.custom_minimum_size = Vector2(0, 52)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ventana.cuerpo.add_child(scroll)
	var grilla := GridContainer.new()
	grilla.name = "GrillaRanuras"
	grilla.columns = 4
	grilla.add_theme_constant_override("h_separation", 3)
	grilla.add_theme_constant_override("v_separation", 3)
	# Reservar siempre la primera fila evita que el ScrollContainer nazca con
	# altura cero durante el primer frame de apertura.
	grilla.custom_minimum_size = Vector2(0, 34)
	grilla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grilla.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(grilla)
	# capacity es un byte del paquete 0x6E. El cliente clasico muestra todas
	# las ranuras que anuncia el servidor; limitarlo a 32 ocultaba contenido
	# real de corpses, depots y contenedores grandes.
	var capacidad := mini(255, maxi(1, int(datos.get("capacidad", 1))))
	var items: Array = datos.get("items", [])
	var items_anteriores: Array = anterior.get("items", [])
	for ranura in range(capacidad):
		var slot = RANURA.new(self, ranura, "contenedor", id)
		_slots_contenedor[id][ranura] = slot
		if ranura < items.size():
			slot.mostrar(items[ranura])
			var previo: Dictionary = items_anteriores[ranura] \
				if ranura < items_anteriores.size() else {}
			if _es_cambio_de_moneda(previo, items[ranura]):
				slot.animar_acunado(int(items[ranura].get("cantidad", \
					previo.get("cantidad", 1))))
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
	_slots_contenedor.erase(id)
	_contenedores_visuales.erase(id)
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
