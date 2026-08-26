"""Saca los dibujos del cliente 7.72 y los empaqueta en laminas.

Por que laminas y no un PNG por item
------------------------------------
Son casi 5.000 items. Godot importa cada archivo suelto del proyecto al
abrirlo, asi que 5.000 PNGs son 5.000 importaciones y un arranque lentisimo.
En vez de eso se pegan todos en unas pocas laminas de 2048x2048 y un
`indice.json` dice en que lamina y en que rectangulo quedo cada uno. Godot
carga 3 o 4 texturas y saca recortes con AtlasTexture.

Que se exporta
--------------
    items    : todos los fotogramas de cada id de CLIENTE (los que llegan
               por la red). Los animados traen varias fases.
    outfits  : las 4 direcciones de cada aspecto, para dibujar criaturas.
               Se usa la capa 0 (el dibujo); la capa 1 es la mascara para
               teñir la ropa de los jugadores, que todavia no usamos.

Correr:  python herramientas/extraer_sprites772.py
Sale:    cliente3d/assets/sprites772/
"""

import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from leer_dat_spr import LADO, Sprites, cargar_dat, componer

RAIZ = Path(__file__).resolve().parent.parent
CLIENTE = RAIZ / "cliente3d" / "assets" / "cliente772"
DAT = CLIENTE / "Tibia.dat"
SPR = CLIENTE / "Tibia.spr"
SALIDA = RAIZ / "cliente3d" / "assets" / "sprites772"

LADO_LAMINA = 2048
BORDE = 1          # un pixel de aire para que no se mezclen los vecinos
MAX_FASES = 8      # mas que esto no aporta y agranda las laminas


class Laminas:
    """Empaquetador por estantes: se ordena por altura y se va llenando
    de izquierda a derecha, bajando cuando no entra mas."""

    def __init__(self):
        self.hojas = []
        self._nueva()

    def _nueva(self):
        self.hojas.append(Image.new("RGBA", (LADO_LAMINA, LADO_LAMINA), (0, 0, 0, 0)))
        self.x = 0
        self.y = 0
        self.alto_estante = 0

    def poner(self, img: Image.Image) -> dict:
        w, h = img.size
        if self.x + w + BORDE > LADO_LAMINA:
            self.x = 0
            self.y += self.alto_estante + BORDE
            self.alto_estante = 0
        if self.y + h + BORDE > LADO_LAMINA:
            self._nueva()
        self.hojas[-1].alpha_composite(img, (self.x, self.y))
        sitio = {"l": len(self.hojas) - 1, "x": self.x, "y": self.y, "w": w, "h": h}
        self.x += w + BORDE
        self.alto_estante = max(self.alto_estante, h)
        return sitio

    def guardar(self, carpeta: Path):
        for n, hoja in enumerate(self.hojas):
            hoja.save(carpeta / ("lamina_%02d.png" % n))
        return len(self.hojas)


def main():
    if not DAT.exists() or not SPR.exists():
        print("Faltan Tibia.dat / Tibia.spr en %s" % CLIENTE)
        raise SystemExit(1)

    print("Leyendo Tibia.dat ...")
    dat = cargar_dat(DAT)
    c = dat["conteos"]
    print("  items hasta el id %d, %d outfits, %d efectos, %d proyectiles"
          % (c["items"], c["outfits"], c["efectos"], c["proyectiles"]))
    print("  firma 0x%08X" % dat["firma"])

    print("Leyendo Tibia.spr ...")
    spr = Sprites(SPR)
    print("  %d sprites" % spr.cantidad)

    SALIDA.mkdir(parents=True, exist_ok=True)
    laminas = Laminas()

    # ---------------- items ----------------
    print("Empaquetando items ...")
    items = {}
    vacios = 0
    for cid, t in sorted(dat["items"].items()):
        fases = max(1, min(t["fases"], MAX_FASES))
        cuadros = []
        for f in range(fases):
            img = componer(t, spr, 0, f)
            if img.getbbox() is None:
                break
            cuadros.append(laminas.poner(img))
        if not cuadros:
            vacios += 1
            continue
        ficha = {"c": cuadros, "alto": t["alto"], "ancho": t["ancho"]}
        items[str(cid)] = ficha

    # ---------------- outfits ----------------
    print("Empaquetando outfits ...")
    outfits = {}
    for oid, t in sorted(dat["outfits"].items()):
        dirs = min(max(t["dirs"], 1), 4)
        fases = max(1, min(t["fases"], MAX_FASES))
        # [direccion][fase]
        por_dir = []
        algo = False
        for d in range(dirs):
            fila = []
            for f in range(fases):
                img = componer(t, spr, d, f, 0)
                if img.getbbox() is not None:
                    algo = True
                fila.append(laminas.poner(img))
            por_dir.append(fila)
        if not algo:
            continue
        outfits[str(oid)] = {
            "c": por_dir, "dirs": dirs, "fases": fases,
            "alto": t["alto"], "ancho": t["ancho"],
        }

    cuantas = laminas.guardar(SALIDA)

    (SALIDA / "indice.json").write_text(json.dumps({
        "lado_lamina": LADO_LAMINA,
        "laminas": cuantas,
        # El orden de las direcciones en el .dat es el mismo que el de los
        # opcodes de caminar: norte, este, sur, oeste.
        "orden_direcciones": ["norte", "este", "sur", "oeste"],
        "items": items,
        "outfits": outfits,
    }, separators=(",", ":")), encoding="utf-8")

    print("")
    print("items con dibujo : %d" % len(items))
    print("items vacios     : %d (no tienen dibujo en este cliente)" % vacios)
    print("outfits          : %d" % len(outfits))
    print("laminas          : %d de %dx%d" % (cuantas, LADO_LAMINA, LADO_LAMINA))
    print("-> %s" % SALIDA)


if __name__ == "__main__":
    main()
