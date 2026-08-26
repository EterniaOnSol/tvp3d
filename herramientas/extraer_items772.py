"""Saca el catalogo de items del propio servidor TVP.

Para que hace falta
-------------------
Cuando el servidor describe una casilla del mapa manda el id de cliente
del item (2 bytes) y **a veces un byte mas**: la cantidad si el item se
apila, o el color si es un liquido (`networkmessage.cpp:95-106`). No hay
ninguna marca que avise cual de los dos casos es: el cliente TIENE que
saber de antemano como es cada item. Si se equivoca en uno solo, todo lo
que viene despues en el paquete queda corrido.

De donde sale cada cosa
-----------------------
    servidor/data/items/items.otb -> grupo y banderas por id de servidor
    servidor/data/items/items.xml -> nombre por id de servidor

El formato del .otb esta sacado del codigo del propio servidor
(`src/items.cpp:215-432` y `src/itemloader.h:91-162`), no adivinado: un
arbol de nodos con los marcadores 0xFE/0xFF/0xFD, y adentro de cada nodo
un uint32 de banderas seguido de atributos (uint8 tipo, uint16 largo).

Aca no hay que cruzar nada por nombre, al reves de lo que pasaba en
3DTIBIA: el servidor y el cliente son los dos 7.72, asi que los ids de
cliente del .otb son exactamente los que llegan por la red.

Correr:  python herramientas/extraer_items772.py
Sale:    cliente3d/assets/items772.json
"""

import json
import re
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BASE = RAIZ / "servidor" / "data" / "items"
OTB = BASE / "items.otb"
XML = BASE / "items.xml"
SALIDA = RAIZ / "cliente3d" / "assets" / "items772.json"

# Marcadores del arbol (los mismos del .otbm).
INICIO, FIN, ESCAPE = 0xFE, 0xFF, 0xFD

# itemloader.h:95 — los atributos que nos interesan.
ATTR_SERVERID = 0x10
ATTR_CLIENTID = 0x11
ATTR_SPEED = 0x14          # lo rapido que se camina por ese suelo
ATTR_MINIMAPCOLOR = 0x21   # con que color sale en el minimapa
ATTR_TOPORDER = 0x2B       # 1 = borde de suelo, se pinta sobre el piso

# itemgroup_t (itemloader.h:8-27).
GRUPO_SUELO = 1
GRUPO_CONTENEDOR = 2
GRUPO_SPLASH = 11
GRUPO_FLUIDO = 12

# itemflags_t (itemloader.h:134-162).
FLAG_BLOCK_SOLID = 1 << 0
FLAG_BLOCK_PROJECTILE = 1 << 1
FLAG_BLOCK_PATHFIND = 1 << 2
FLAG_HAS_HEIGHT = 1 << 3
FLAG_PICKUPABLE = 1 << 5
FLAG_MOVEABLE = 1 << 6
FLAG_STACKABLE = 1 << 7
FLAG_ALWAYSONTOP = 1 << 13
FLAG_LOOKTHROUGH = 1 << 23


def nodos(datos):
    """Recorre el arbol y devuelve (tipo, props) de cada nodo.

    Los bytes de control van escapados con 0xFD, asi que hay que
    des-escaparlos antes de leer nada."""
    salida = []
    i = 0
    n = len(datos)
    actual = None
    tipo_actual = 0
    while i < n:
        b = datos[i]
        if b == ESCAPE:
            if actual is not None:
                actual.append(datos[i + 1])
            i += 2
            continue
        if b == INICIO:
            if actual is not None:
                salida.append((tipo_actual, bytes(actual)))
            actual = bytearray()
            i += 1
            # El primer byte de un nodo es su TIPO (itemgroup_t), no props.
            tipo_actual = datos[i] if i < n else 0
            if i < n:
                i += 1
            continue
        if b == FIN:
            if actual is not None:
                salida.append((tipo_actual, bytes(actual)))
                actual = None
            i += 1
            continue
        if actual is not None:
            actual.append(b)
        i += 1
    return salida


def leer_otb():
    datos = OTB.read_bytes()
    # 4 bytes de version adelante del arbol (items.cpp:215-230).
    items = {}
    for tipo, props in nodos(datos[4:]):
        if len(props) < 4:
            continue
        flags = int.from_bytes(props[0:4], "little")
        p = 4
        sid = cid = 0
        velocidad = 0
        color = 0
        orden = 0
        while p + 3 <= len(props):
            attrib = props[p]
            largo = int.from_bytes(props[p + 1:p + 3], "little")
            p += 3
            dato = props[p:p + largo]
            p += largo
            if attrib == ATTR_SERVERID and largo == 2:
                sid = int.from_bytes(dato, "little")
            elif attrib == ATTR_CLIENTID and largo == 2:
                cid = int.from_bytes(dato, "little")
            elif attrib == ATTR_SPEED and largo == 2:
                velocidad = int.from_bytes(dato, "little")
            elif attrib == ATTR_MINIMAPCOLOR and largo == 2:
                color = int.from_bytes(dato, "little")
            elif attrib == ATTR_TOPORDER and largo == 1:
                orden = dato[0]
        if sid == 0 or cid == 0:
            continue
        items[sid] = {
            "cid": cid,
            "grupo": tipo,
            # Las dos que deciden si viene un byte de mas:
            "apilable": bool(flags & FLAG_STACKABLE),
            "liquido": tipo in (GRUPO_SPLASH, GRUPO_FLUIDO),
            # El resto es para dibujar.
            "suelo": tipo == GRUPO_SUELO,
            "contenedor": tipo == GRUPO_CONTENEDOR,
            "bloquea": bool(flags & FLAG_BLOCK_SOLID),
            "block_pathfind": bool(flags & FLAG_BLOCK_PATHFIND),
            "frena_vista": bool(flags & FLAG_BLOCK_PROJECTILE),
            "tiene_alto": bool(flags & FLAG_HAS_HEIGHT),
            "se_ve_a_traves": bool(flags & FLAG_LOOKTHROUGH),
            "levantable": bool(flags & FLAG_PICKUPABLE),
            "movible": bool(flags & FLAG_MOVEABLE),
            "siempre_arriba": bool(flags & FLAG_ALWAYSONTOP),
            "orden_arriba": orden,
            "velocidad_suelo": velocidad,
            "color_mapa": color,
        }
    return items


RE_ITEM = re.compile(r'<item\s+id="(\d+)"[^>]*?name="([^"]*)"', re.I)
RE_RANGO = re.compile(r'<item\s+fromid="(\d+)"\s+toid="(\d+)"[^>]*?name="([^"]*)"', re.I)


def leer_nombres():
    texto = XML.read_text(encoding="utf-8", errors="replace")
    nombres = {}
    for sid, nombre in RE_ITEM.findall(texto):
        nombres[int(sid)] = nombre.strip()
    for desde, hasta, nombre in RE_RANGO.findall(texto):
        for sid in range(int(desde), int(hasta) + 1):
            nombres[sid] = nombre.strip()
    return nombres


def main():
    items = leer_otb()
    nombres = leer_nombres()
    print("items.otb: %d items" % len(items))
    print("items.xml: %d nombres" % len(nombres))

    # Varios ids de servidor pueden compartir un id de cliente (dos items
    # distintos que se ven igual). Para el byte de mas TIENEN que coincidir,
    # asi que si no coinciden hay que enterarse.
    por_cliente = {}
    choques = 0
    for sid, it in sorted(items.items()):
        cid = it["cid"]
        ficha = {k: v for k, v in it.items() if k != "cid"}
        ficha["nombre"] = nombres.get(sid, "")
        anterior = por_cliente.get(cid)
        if anterior is None:
            por_cliente[cid] = ficha
            continue
        if (anterior["apilable"] != ficha["apilable"]
                or anterior["liquido"] != ficha["liquido"]):
            choques += 1
            print("  OJO: el id de cliente %d no se pone de acuerdo "
                  "(apilable/liquido) entre dos items de servidor" % cid)

    salida = {str(cid): ficha for cid, ficha in sorted(por_cliente.items())}

    apilables = sum(1 for f in salida.values() if f["apilable"])
    liquidos = sum(1 for f in salida.values() if f["liquido"])
    suelos = sum(1 for f in salida.values() if f["suelo"])

    SALIDA.parent.mkdir(parents=True, exist_ok=True)
    SALIDA.write_text(
        json.dumps(salida, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8")

    print("")
    print("ids de cliente distintos : %d" % len(salida))
    print("  llevan byte de cantidad: %d apilables" % apilables)
    print("  llevan byte de color   : %d liquidos" % liquidos)
    print("  son suelo              : %d" % suelos)
    print("  desacuerdos            : %d" % choques)
    print("-> %s" % SALIDA)


if __name__ == "__main__":
    main()
