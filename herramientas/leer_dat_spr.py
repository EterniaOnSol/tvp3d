"""Lector de Tibia.dat + Tibia.spr clasicos (7.55 - 7.72).

El formato NO esta adivinado: esta leido de la implementacion de OTClient

    src/client/thingtype.cpp        (unserialize, getSpriteIndex)
    src/client/thingtypemanager.cpp (loadDat)

Los dos archivos son del cliente 7.72 oficial y estan en
`cliente3d/assets/cliente772/`. Se comprobo que son los que van con este
servidor: el .dat dice que el ultimo item es el **5089**, que es
exactamente el id de cliente mas alto que usa el `items.otb` del servidor.
Firma del .dat: 0x439D5A33.

QUE ES CADA COSA EN EL .dat

Un "thing" (item, outfit, efecto o proyectil) es una lista de atributos
terminada en 0xFF, despues su geometria, y despues la lista de numeros de
sprite. La geometria dice como se arma el dibujo:

    ancho x alto   en casillas de 32 px (una pared es 1x2)
    capas          para los outfits: 0 = el dibujo, 1 = la mascara de color
    dirs           patronX: para los outfits son las 4 direcciones
    py             patronY: para los outfits, los "addons" (en 7.72 no hay)
    pz             patronZ: la montura (en 7.72 tampoco hay)
    fases           los fotogramas de la animacion
"""

import struct
from pathlib import Path

from PIL import Image

LADO = 32  # cada sprite de Tibia es de 32x32

# Atributos que traen datos extra detras. Valores del enum ThingAttr.
ATTR_1xU16 = {
    0,   # Ground (la velocidad al caminar)
    8,   # Writable
    9,   # WritableOnce
    25,  # Elevation
    28,  # MinimapColor
    29,  # LensHelp
    32,  # Cloth
}
ATTR_2xU16 = {
    21,  # Light        (intensidad + color)
    24,  # Displacement (x + y)
}
FIN_ATRIBUTOS = 0xFF

PRIMER_ITEM = 100      # en el .dat los items arrancan aca


class Lector:
    """Lector secuencial de bytes, al estilo del FileStream de OTClient."""

    def __init__(self, datos: bytes):
        self.d = datos
        self.p = 0

    def u8(self) -> int:
        v = self.d[self.p]
        self.p += 1
        return v

    def u16(self) -> int:
        v = struct.unpack_from("<H", self.d, self.p)[0]
        self.p += 2
        return v

    def u32(self) -> int:
        v = struct.unpack_from("<I", self.d, self.p)[0]
        self.p += 4
        return v


def leer_thing(r: Lector) -> dict:
    """Lee un 'thing' del .dat."""
    atributos = set()
    while True:
        a = r.u8()
        if a == FIN_ATRIBUTOS:
            break
        atributos.add(a)
        if a in ATTR_2xU16:
            r.u16()
            r.u16()
        elif a in ATTR_1xU16:
            r.u16()

    ancho = r.u8()
    alto = r.u8()
    if ancho > 1 or alto > 1:
        r.u8()  # realSize, no lo necesitamos

    capas = r.u8()
    dirs = r.u8()
    py = r.u8()
    pz = r.u8()
    fases = r.u8()

    total = ancho * alto * capas * dirs * py * pz * fases
    indices = [r.u16() for _ in range(total)]

    return {
        "ancho": ancho, "alto": alto, "capas": capas,
        "dirs": dirs, "py": py, "pz": pz, "fases": fases,
        "indices": indices, "atributos": atributos,
    }


def cargar_dat(ruta: Path) -> dict:
    """Devuelve los items Y los outfits, con sus ids nativos."""
    r = Lector(Path(ruta).read_bytes())
    firma = r.u32()
    ult_item = r.u16()
    ult_outfit = r.u16()
    ult_efecto = r.u16()
    ult_proy = r.u16()

    items = {}
    for iid in range(PRIMER_ITEM, ult_item + 1):
        items[iid] = leer_thing(r)

    outfits = {}
    for oid in range(1, ult_outfit + 1):
        outfits[oid] = leer_thing(r)

    efectos = {}
    for eid in range(1, ult_efecto + 1):
        efectos[eid] = leer_thing(r)

    proyectiles = {}
    for pid in range(1, ult_proy + 1):
        proyectiles[pid] = leer_thing(r)

    return {
        "firma": firma,
        "items": items,
        "outfits": outfits,
        "efectos": efectos,
        "proyectiles": proyectiles,
        "conteos": {
            "items": ult_item, "outfits": ult_outfit,
            "efectos": ult_efecto, "proyectiles": ult_proy,
        },
    }


class Sprites:
    """Tibia.spr: los dibujos de 32x32, comprimidos con RLE."""

    def __init__(self, ruta):
        self.d = Path(ruta).read_bytes()
        self.firma = struct.unpack_from("<I", self.d, 0)[0]
        self.cantidad = struct.unpack_from("<H", self.d, 4)[0]
        self.base = 6  # los offsets arrancan justo despues del contador
        self.cache = {}

    def sprite(self, sid: int):
        """Un sprite de 32x32 en RGBA, o None si esta vacio."""
        if sid <= 0 or sid > self.cantidad:
            return None
        if sid in self.cache:
            return self.cache[sid]

        off = struct.unpack_from("<I", self.d, self.base + (sid - 1) * 4)[0]
        if off == 0:
            self.cache[sid] = None
            return None

        p = off + 3  # 3 bytes de color transparente que no se usan
        tam = struct.unpack_from("<H", self.d, p)[0]
        p += 2
        fin = p + tam

        px = bytearray(LADO * LADO * 4)
        i = 0
        # Compresion RLE: (cuantos transparentes, cuantos con color, RGB...)
        while p < fin and i < LADO * LADO:
            transp = struct.unpack_from("<H", self.d, p)[0]
            p += 2
            coloreados = struct.unpack_from("<H", self.d, p)[0]
            p += 2
            i += transp
            for _ in range(coloreados):
                if i >= LADO * LADO:
                    break
                px[i * 4 + 0] = self.d[p]
                px[i * 4 + 1] = self.d[p + 1]
                px[i * 4 + 2] = self.d[p + 2]
                px[i * 4 + 3] = 255
                p += 3
                i += 1

        img = Image.frombytes("RGBA", (LADO, LADO), bytes(px))
        self.cache[sid] = img
        return img


def indice_sprite(t: dict, w, h, capa, x, y, z, fase) -> int:
    """Formula exacta de ThingType::getSpriteIndex (thingtype.cpp)."""
    return ((((((fase % t["fases"])
                * t["pz"] + z)
               * t["py"] + y)
              * t["dirs"] + x)
             * t["capas"] + capa)
            * t["alto"] + h) * t["ancho"] + w


def componer(t: dict, spr: Sprites, direccion: int, fase: int, capa: int = 0):
    """Arma un fotograma completo (puede ser de varios sprites de 32x32)."""
    img = Image.new("RGBA", (t["ancho"] * LADO, t["alto"] * LADO), (0, 0, 0, 0))
    for h in range(t["alto"]):
        for w in range(t["ancho"]):
            i = indice_sprite(t, w, h, capa, direccion, 0, 0, fase)
            if i >= len(t["indices"]):
                continue
            s = spr.sprite(t["indices"][i])
            if s is None:
                continue
            # En Tibia el ancla esta abajo a la derecha: w crece hacia la
            # izquierda y h hacia arriba.
            dx = (t["ancho"] - 1 - w) * LADO
            dy = (t["alto"] - 1 - h) * LADO
            img.alpha_composite(s, (dx, dy))
    return img
