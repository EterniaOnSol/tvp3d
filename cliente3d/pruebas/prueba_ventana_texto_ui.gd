extends Node

## Comprueba la ventana de texto de la interfaz: la que abre el servidor con el
## `0x96` para carteles, cartas y la etiqueta de una parcel.
##
## No inventa permisos: el paquete no dice si el item se puede escribir, solo
## trae un maximo de caracteres. La ventana muestra lo que llego y, al aceptar,
## devuelve lo escrito para que el consumidor lo mande por `0x89`.

const VENTANA_TEXTO := preload("res://ui/ventana_texto.gd")

var _fallas := 0


func _comprobar(condicion: bool, texto: String) -> void:
	if condicion:
		print("  OK   %s" % texto)
	else:
		_fallas += 1
		printerr("  FALLA %s" % texto)


func _ready() -> void:
	var ventana = VENTANA_TEXTO.new()
	add_child(ventana)
	await get_tree().process_frame
	_comprobar(not ventana.visible, "arranca escondida")

	var enviados: Array = []
	ventana.escribio.connect(func(id, texto): enviados.append([id, texto]))

	print("Una etiqueta en blanco:")
	ventana.mostrar({
		"id": 4242, "cid": 3507, "nombre": "label", "texto": "",
		"autor": "", "maximo": 80,
	})
	await get_tree().process_frame
	_comprobar(ventana.visible, "se abre cuando el servidor la manda")
	_comprobar(str(ventana._titulo.text).contains("label"),
		"el titulo nombra el item que mando el servidor")
	_comprobar(ventana._caja.text == "", "la caja arranca con el texto real")
	_comprobar(ventana._caja.editable, "con un maximo mayor que cero se escribe")
	_comprobar(str(ventana._contador.text) == "0 / 80 characters",
		"el contador muestra el maximo del servidor")

	ventana._caja.text = "Valentino\nThais"
	ventana._al_cambiar_texto()
	ventana._al_aceptar()
	_comprobar(enviados == [[4242, "Valentino\nThais"]],
		"al aceptar devuelve el id de ventana y el texto tal cual")
	_comprobar(not ventana.visible, "al aceptar se cierra")

	print("Un texto mas largo que el maximo:")
	ventana.mostrar({
		"id": 7, "cid": 3507, "nombre": "label", "texto": "",
		"autor": "", "maximo": 10,
	})
	ventana._caja.text = "esto es mucho mas largo que diez"
	ventana._al_cambiar_texto()
	_comprobar(ventana._caja.text.length() == 10,
		"se corta en el maximo que puso el servidor")

	print("Un cartel ya escrito:")
	enviados.clear()
	ventana.mostrar({
		"id": 9, "cid": 2599, "nombre": "sign", "texto": "Welcome to Thais",
		"autor": "GOD VALENTINO", "maximo": 0,
	})
	_comprobar(ventana._caja.text == "Welcome to Thais",
		"muestra el texto que ya tenia")
	_comprobar(str(ventana._autor.text).contains("GOD VALENTINO"),
		"dice quien lo escribio")
	_comprobar(not ventana._caja.editable,
		"sin maximo no se puede escribir encima")

	print("Cancelar:")
	ventana.cerrar()
	_comprobar(not ventana.visible and enviados.is_empty(),
		"cerrar no manda nada")

	if _fallas > 0:
		printerr("FALLO: %d comprobaciones de la ventana de texto" % _fallas)
		get_tree().quit(1)
		return
	print("OK: la ventana de texto muestra lo que mando el servidor")
	get_tree().quit(0)
