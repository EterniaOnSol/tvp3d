"""Igual que extraer_referencias_faltantes.py pero para TODO el bestiario y
mostrando las 4 direcciones (no solo la frontal/sur).

Lee cada servidor/data/monster/monsters/*.xml (name + <look type="..." head=
"..." body="..." legs="..." feet="...">), compone norte/este/sur/oeste en
fase 0 con Tibia.dat + Tibia.spr, y arma un solo PNG por monstruo con las 4
poses en fila, agrandado x4 sin suavizado para que se vea nitido al
mostrarselo a un modelo de IA.

Los outfits con 2 capas (la mayoria de los "humanoides": Amazon, Hunter,
Smuggler, Stalker, Valkyrie, Warlock, etc.) tienen una capa 1 que es una
mascara BINARIA sin sombreado propio: cada pixel es exactamente amarillo
puro (cabeza), rojo puro (cuerpo), verde puro (piernas) o azul puro (pies),
o transparente. El algoritmo real (verificado leyendo el motor de
renderizado de OTClient en otclient-src-41, funciones Outfit::getColor en
src/client/outfit.cpp e Image::overwriteMask en
src/framework/graphics/image.cpp, y el uso de CompositionMode::MULTIPLY en
src/client/creature.cpp) es:

  1. Cada indice de color (0-132) se convierte a RGB con la paleta HSI de
     Tibia (formula exacta de Outfit::getColor, igual a la que ya usa
     cliente3d/propio/personajes3d/catalogo.gd:color_outfit).
  2. Donde la mascara tiene el color puro de una region, el pixel final es
     el pixel de la capa 0 (el dibujo, ya sombreado en gris) MULTIPLICADO
     canal a canal por ese color de paleta. Donde no hay mascara, la capa 0
     queda intacta.

Se comprobo esta formula contra generated/bestiario_referencias/Hunter.png
(la referencia ya aceptada) pixel por pixel: separa color de mascara,
tinta multiplicando por la paleta y compone sobre la capa 0.

Correr:  python herramientas/generar_bestiario_4dir.py [Nombre1 Nombre2 ...]
         (sin argumentos, procesa las 158; con argumentos, solo esos nombres)
Sale:    generated/bestiario_referencias_4dir/
"""

import colorsys
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from leer_dat_spr import Sprites, cargar_dat, componer

RAIZ = Path(__file__).resolve().parent.parent
CLIENTE = RAIZ / "cliente3d" / "assets" / "cliente772"
DAT = CLIENTE / "Tibia.dat"
SPR = CLIENTE / "Tibia.spr"
MONSTRUOS = RAIZ / "servidor" / "data" / "monster" / "monsters"
SALIDA = RAIZ / "generated" / "bestiario_referencias_4dir"

# orden real del .dat (thingtype.cpp): norte, este, sur, oeste
DIRECCIONES = [0, 1, 2, 3]
ESCALA = 4
MARGEN = 4  # separacion entre poses, en pixeles ya escalados


def leer_monstruos():
    """(nombre, looktype, colores) por cada xml, ignorando los que no tienen <look type>."""
    items = []
    for ruta in sorted(MONSTRUOS.glob("*.xml")):
        try:
            raiz = ET.parse(ruta).getroot()
        except ET.ParseError as e:
            print("  %-30s -> XML invalido: %s" % (ruta.name, e))
            continue
        nombre = raiz.get("name")
        look = raiz.find("look")
        if nombre is None or look is None or look.get("type") is None:
            continue
        colores = {
            "cabeza": int(look.get("head", 0)),
            "cuerpo": int(look.get("body", 0)),
            "piernas": int(look.get("legs", 0)),
            "pies": int(look.get("feet", 0)),
        }
        items.append((nombre, int(look.get("type")), colores))
    return items


def color_outfit(indice: int):
    """Paleta de 133 colores de Tibia. Misma formula que
    cliente3d/propio/personajes3d/catalogo.gd:color_outfit(), en RGB 0-255."""
    indice = max(0, min(132, indice))
    paso_h = indice % 19
    if paso_h == 0:
        valor = 1.0 - indice / 19.0 / 7.0
        r, g, b = valor, valor, valor
    else:
        fila = indice // 19
        saturacion, valor = {
            1: (0.25, 0.75), 2: (0.50, 0.75), 3: (0.667, 0.75),
            4: (1.0, 1.0), 5: (1.0, 0.75), 6: (1.0, 0.50),
        }[fila]
        r, g, b = colorsys.hsv_to_rgb(paso_h / 18.0, saturacion, valor)
    return r, g, b


# colores puros exactos que usa la mascara (Image::overwriteMask en OTClient
# compara igualdad exacta contra estos, no un umbral)
REGION_POR_COLOR_PURO = {
    (255, 255, 0): "cabeza",   # SpriteMaskYellow -> getHeadColor()
    (255, 0, 0): "cuerpo",     # SpriteMaskRed    -> getBodyColor()
    (0, 255, 0): "piernas",    # SpriteMaskGreen  -> getLegsColor()
    (0, 0, 255): "pies",       # SpriteMaskBlue   -> getFeetColor()
}


def componer_con_color(t: dict, spr: Sprites, direccion: int, colores: dict) -> Image.Image:
    """Capa 0 (dibujo) con la capa 1 (mascara) aplicada por multiplicacion,
    igual que CompositionMode::MULTIPLY en creature.cpp de OTClient."""
    base = componer(t, spr, direccion, 0, 0).convert("RGBA")
    if t["capas"] < 2:
        return base
    mascara = componer(t, spr, direccion, 0, 1).convert("RGBA")
    if mascara.getbbox() is None:
        return base

    paleta = {region: color_outfit(colores[region]) for region in REGION_POR_COLOR_PURO.values()}
    px_b = base.load()
    px_m = mascara.load()
    for y in range(base.height):
        for x in range(base.width):
            region = REGION_POR_COLOR_PURO.get(px_m[x, y][:3])
            if region is None or px_m[x, y][3] == 0:
                continue
            r, g, b, a = px_b[x, y]
            pr, pg, pb = paleta[region]
            px_b[x, y] = (round(r * pr), round(g * pg), round(b * pb), a)
    return base


def main():
    if not DAT.exists() or not SPR.exists():
        print("Faltan Tibia.dat / Tibia.spr en %s" % CLIENTE)
        raise SystemExit(1)

    print("Leyendo Tibia.dat ...")
    dat = cargar_dat(DAT)
    print("Leyendo Tibia.spr ...")
    spr = Sprites(SPR)

    SALIDA.mkdir(parents=True, exist_ok=True)

    filtro = {a.lower() for a in sys.argv[1:]}

    ok, vacios = [], []
    for nombre, oid, colores in leer_monstruos():
        if filtro and nombre.lower() not in filtro:
            continue
        t = dat["outfits"].get(oid)
        if t is None:
            print("  %-25s type=%-4d -> NO EXISTE en el .dat" % (nombre, oid))
            vacios.append(nombre)
            continue

        poses = []
        for d in DIRECCIONES:
            direccion = min(d, t["dirs"] - 1)
            img = componer_con_color(t, spr, direccion, colores)
            grande = img.resize((img.width * ESCALA, img.height * ESCALA), Image.NEAREST)
            poses.append(grande)

        if all(p.getbbox() is None for p in poses):
            print("  %-25s type=%-4d -> vacio" % (nombre, oid))
            vacios.append(nombre)
            continue

        ancho = sum(p.width for p in poses) + MARGEN * (len(poses) - 1)
        alto = max(p.height for p in poses)
        lamina = Image.new("RGBA", (ancho, alto), (0, 0, 0, 0))
        x = 0
        for p in poses:
            lamina.alpha_composite(p, (x, alto - p.height))
            x += p.width + MARGEN

        # nombres de archivo validos en Windows (por si algun monstruo trae "/")
        archivo = nombre.replace("/", "-") + ".png"
        lamina.save(SALIDA / archivo)
        ok.append(nombre)
        print("  %-25s type=%-4d -> OK (%dx%d)" % (nombre, oid, ancho, alto))

    print("")
    print("Extraidos: %d" % len(ok))
    if vacios:
        print("Sin dibujo: %s" % ", ".join(vacios))
    print("-> %s" % SALIDA)


if __name__ == "__main__":
    main()
