"""Convierte el mapa entero de Tibia a trozos que el cliente 3D puede leer.

Por que
-------
El servidor solo manda 18x14 casillas alrededor tuyo — es el protocolo, no
hay forma de pedir mas. Para ver el mundo a lo lejos hay que leer el mismo
`.otbm` que usa el servidor. El reparto queda asi:

    el .otbm       -> el decorado: pisos, paredes, arboles, todo lo quieto
    el servidor    -> lo que se mueve y lo que cambia, en vivo

Los ids del .otbm son de SERVIDOR y los sprites estan por id de CLIENTE.
La traduccion sale del `items.otb`, igual que en extraer_items772.py.

Formato de salida
-----------------
Un solo archivo `mapa.bin` cortado en trozos de 64x64 casillas, mas un
`mapa.json` que dice en que byte empieza cada trozo. Asi el cliente lee del
disco solo los trozos que tiene cerca, sin cargar 70 MB en memoria.

Cada casilla dentro de un trozo son 4 bytes de cabecera y despues los ids:

    u8 dx, u8 dy   la casilla dentro del trozo (0-63)
    u8 z           el piso
    u8 cuantos     cuantas cosas hay encima
    u16 x cuantos  los ids de cliente, de abajo hacia arriba

Correr:  python herramientas/extraer_mapa772.py
Sale:    cliente3d/assets/mapa772/
"""

import json
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from extraer_items772 import leer_otb
from leer_otbm import recorrer

RAIZ = Path(__file__).resolve().parent.parent
OTBM = RAIZ / "servidor" / "data" / "world" / "map.otbm"
SALIDA = RAIZ / "cliente3d" / "assets" / "mapa772"

LADO_TROZO = 64
MAX_POR_CASILLA = 32   # ninguna casilla de Tibia tiene tantas cosas


def main():
    if not OTBM.exists():
        print("No esta el mapa en %s" % OTBM)
        raise SystemExit(1)

    print("Leyendo items.otb para traducir los ids ...")
    items = leer_otb()
    a_cliente = {sid: it["cid"] for sid, it in items.items()}
    print("  %d items" % len(a_cliente))

    print("Leyendo %s (%d MB) ..." % (OTBM.name, OTBM.stat().st_size // 1024 // 1024))
    datos = OTBM.read_bytes()

    trozos = {}
    cuenta = {"casillas": 0, "cosas": 0, "sin_traducir": 0}
    limites = [999999, 999999, 0, 0]   # minx, miny, maxx, maxy
    arranque = time.time()

    def por_casilla(x, y, z, ids, _banderas):
        cids = []
        for sid in ids:
            cid = a_cliente.get(sid)
            if cid is None:
                cuenta["sin_traducir"] += 1
                continue
            cids.append(cid)
        if not cids:
            return
        del cids[MAX_POR_CASILLA:]

        cuenta["casillas"] += 1
        cuenta["cosas"] += len(cids)
        limites[0] = min(limites[0], x)
        limites[1] = min(limites[1], y)
        limites[2] = max(limites[2], x)
        limites[3] = max(limites[3], y)

        tx, ty = x // LADO_TROZO, y // LADO_TROZO
        buf = trozos.get((tx, ty))
        if buf is None:
            buf = bytearray()
            trozos[(tx, ty)] = buf
        buf.append(x - tx * LADO_TROZO)
        buf.append(y - ty * LADO_TROZO)
        buf.append(z)
        buf.append(len(cids))
        buf.extend(struct.pack("<%dH" % len(cids), *cids))

    info = recorrer(datos, por_casilla)
    print("  %d areas, %d casillas, %d cosas, %.1f s"
          % (info["areas"], cuenta["casillas"], cuenta["cosas"],
             time.time() - arranque))
    if cuenta["sin_traducir"]:
        print("  %d cosas con un id que no esta en items.otb (se descartan)"
              % cuenta["sin_traducir"])

    SALIDA.mkdir(parents=True, exist_ok=True)
    indice = {}
    with open(SALIDA / "mapa.bin", "wb") as f:
        for (tx, ty), buf in sorted(trozos.items()):
            indice["%d_%d" % (tx, ty)] = [f.tell(), len(buf)]
            f.write(buf)

    tam = (SALIDA / "mapa.bin").stat().st_size
    (SALIDA / "mapa.json").write_text(json.dumps({
        "lado_trozo": LADO_TROZO,
        "minx": limites[0], "miny": limites[1],
        "maxx": limites[2], "maxy": limites[3],
        "trozos": indice,
    }, separators=(",", ":")), encoding="utf-8")

    print("")
    print("trozos    : %d de %dx%d" % (len(trozos), LADO_TROZO, LADO_TROZO))
    print("el mundo  : de (%d,%d) a (%d,%d)" % tuple(limites))
    print("mapa.bin  : %.1f MB" % (tam / 1024 / 1024))
    print("-> %s" % SALIDA)


if __name__ == "__main__":
    main()
