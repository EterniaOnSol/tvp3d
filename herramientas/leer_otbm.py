"""Lector del `.otbm`, el archivo donde vive el mapa entero de Tibia.

Por que hace falta leer el disco si ya hay un servidor
-----------------------------------------------------
El servidor NO manda el mapa entero: manda una ventana de 18x14 casillas
alrededor tuyo y nada mas (`protocolgame.cpp:1699`, con
`maxClientViewportX/Y` = 8 y 6). Eso es asi en el protocolo de Tibia y no
se puede pedir de otra forma.

Para ver el mundo a lo lejos hay que leerlo del mismo `.otbm` que usa el
servidor. Queda un reparto claro:

    el .otbm del disco -> el decorado: pisos, paredes, arboles
    el servidor en vivo -> lo que se mueve y lo que cambia

El formato del arbol (marcadores 0xFE/0xFF/0xFD, atributos, nodos de
item) esta sacado del lector del propio servidor: `src/iomap.cpp` y las
constantes de `src/iomap.h:14-63`. No se adivino nada.
"""

import struct

START, END, ESCAPE = 0xFE, 0xFF, 0xFD

OTBM_MAP_DATA = 2
OTBM_TILE_AREA = 4
OTBM_TILE = 5
OTBM_ITEM = 6
OTBM_HOUSETILE = 14

OTBM_ATTR_TILE_FLAGS = 3
OTBM_ATTR_ACTION_ID = 4
OTBM_ATTR_UNIQUE_ID = 5
OTBM_ATTR_TEXT = 6
OTBM_ATTR_DESC = 7
OTBM_ATTR_TELE_DEST = 8
OTBM_ATTR_ITEM = 9
OTBM_ATTR_DEPOT_ID = 10
OTBM_ATTR_RUNE_CHARGES = 12
OTBM_ATTR_HOUSEDOORID = 14
OTBM_ATTR_COUNT = 15
OTBM_ATTR_DURATION = 16
OTBM_ATTR_DECAYING_STATE = 17
OTBM_ATTR_WRITTENDATE = 18
OTBM_ATTR_WRITTENBY = 19
OTBM_ATTR_SLEEPERGUID = 20
OTBM_ATTR_SLEEPSTART = 21
OTBM_ATTR_CHARGES = 22
OTBM_ATTR_KEYNUMBER = 23
OTBM_ATTR_KEYHOLENUMBER = 24
OTBM_ATTR_DOORQUESTNUMBER = 25
OTBM_ATTR_DOORQUESTVALUE = 26
OTBM_ATTR_DOORLEVEL = 27
OTBM_ATTR_CHESTQUESTNUMBER = 28

OTBM_TILEFLAG_PROTECTIONZONE = 1 << 0


class OTBMParseError(ValueError):
    """Error de formato con un codigo util para los importadores."""


class Stream:
    """Lector del arbol OTBM. Adentro de un nodo los bytes de control van
    escapados con 0xFD, asi que hay dos modos de leer."""

    __slots__ = ("data", "pos", "nodes")

    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
        self.nodes = 0

    def _u8_raw(self) -> int:
        if self.pos >= len(self.data):
            raise OTBMParseError("OTBM_TRUNCATED_NODE")
        b = self.data[self.pos]
        self.pos += 1
        return b

    def _u8_esc(self) -> int:
        d, p = self.data, self.pos
        if p >= len(d):
            raise OTBMParseError("OTBM_TRUNCATED_NODE")
        b = d[p]
        if b == ESCAPE:
            p += 1
            if p >= len(d):
                raise OTBMParseError("OTBM_TRUNCATED_ESCAPE")
            b = d[p]
        self.pos = p + 1
        return b

    def get_u8(self) -> int:
        return self._u8_esc() if self.nodes > 0 else self._u8_raw()

    def _bytes(self, n: int) -> bytes:
        if self.nodes > 0:
            return bytes(self._u8_esc() for _ in range(n))
        if n < 0 or self.pos + n > len(self.data):
            raise OTBMParseError("OTBM_TRUNCATED_BYTES")
        b = self.data[self.pos:self.pos + n]
        self.pos += n
        return b

    def get_u16(self) -> int:
        return struct.unpack("<H", self._bytes(2))[0]

    def get_u32(self) -> int:
        return struct.unpack("<I", self._bytes(4))[0]

    def get_string(self) -> str:
        n = self.get_u16()
        return self._bytes(n).decode("latin-1") if n else ""

    def back(self, n: int = 1) -> None:
        self.pos -= n

    def is_prop(self, prop: int) -> bool:
        v = self.get_u8()
        if v == prop:
            return True
        self.back()
        return False

    def start_node(self, type_: int = 0) -> bool:
        p1 = self.get_u8()
        if p1 == START:
            if type_ == 0:
                self.nodes += 1
                return True
            p2 = self.get_u8()
            if p2 == type_:
                self.nodes += 1
                return True
            self.back()
            self.back()
            return False
        self.back()
        return False

    def end_node(self) -> bool:
        if self.get_u8() == END:
            self.nodes -= 1
            return True
        self.back()
        return False

    def skip_node_body(self) -> None:
        """Se come todo lo que queda del nodo actual sin decodificar nada:
        solo cuenta START/END respetando el escape. Deja el stream como si
        se hubiera parseado entero y cerrado con end_node()."""
        data = self.data
        pos = self.pos
        depth = 0
        while True:
            if pos >= len(data):
                raise OTBMParseError("OTBM_TRUNCATED_NODE")
            b = data[pos]
            if b == ESCAPE:
                if pos + 1 >= len(data):
                    raise OTBMParseError("OTBM_TRUNCATED_ESCAPE")
                pos += 2
                continue
            if b == START:
                depth += 1
                pos += 1
                continue
            if b == END:
                if depth == 0:
                    self.pos = pos + 1
                    self.nodes -= 1
                    return
                depth -= 1
                pos += 1
                continue
            pos += 1


def recorrer(datos: bytes, por_casilla, por_casilla_ext=None,
             por_casilla_detalle=None):
    """Recorre el .otbm entero y llama a `por_casilla(x, y, z, ids, banderas)`
    con los ids de SERVIDOR de cada casilla que tenga algo encima. Si se pasa
    `por_casilla_ext`, recibe ademas el house id: x, y, z, ids, banderas,
    house_id. Si se pasa `por_casilla_detalle`, recibe los mismos datos pero
    con una lista de items completos en lugar de ids: x, y, z, items,
    banderas, house_id. El callback antiguo se conserva para los extractores
    existentes.
    """
    if len(datos) < 4:
        raise OTBMParseError("OTBM_TRUNCATED_HEADER")
    s = Stream(datos[4:])   # los primeros 4 bytes son el identificador

    if not s.start_node():
        raise ValueError("no se pudo leer el nodo raiz")
    s.pos += 1              # tipo del nodo raiz, se saltea igual que el servidor

    s.get_u32()             # version
    ancho = s.get_u16()
    alto = s.get_u16()
    s.get_u32()             # version mayor de items
    s.get_u32()             # version menor de items

    areas = 0
    if s.start_node(OTBM_MAP_DATA):
        # Atributos sueltos del mapa (descripcion, archivo de spawns, de casas).
        while True:
            attr = s.get_u8()
            if attr in (1, 2, 11, 13):
                s.get_string()
            else:
                s.back()
                break

        while s.start_node(OTBM_TILE_AREA):
            _area(s, por_casilla, por_casilla_ext, por_casilla_detalle)
            areas += 1

    return {"ancho": ancho, "alto": alto, "areas": areas}


def _read_item(s: Stream, context: str, read_attributes: bool = True) -> dict:
    """Lee un item inline o dentro de un nodo OTBM_ITEM.

    Los tipos y anchos son los de `servidor/src/iomap.h` y `item.cpp`.
    No se salta un atributo desconocido: sin conocer su ancho seria
    imposible mantener la posicion del stream de forma segura.
    """
    try:
        server_id = s.get_u16()
        attributes = {}
        attributes_present = []
        subtype = None
        contents = []

        # OTBM_ATTR_ITEM es la variante inline del suelo y solo serializa el
        # id. Los atributos pertenecen a los nodos OTBM_ITEM.
        if not read_attributes:
            return {
                "server_id": server_id,
                "count": 1,
                "subtype": None,
                "attributes": attributes,
                "attributes_present": attributes_present,
            }

        while True:
            # PropStream de OTBM queda acotado al cuerpo del nodo y no
            # serializa necesariamente un atributo 0 de cierre. Un FF raw
            # es el marcador END; un FF escapado sigue siendo un byte de
            # datos y pasa por get_u8().
            if (s.nodes > 0 and s.pos < len(s.data) and
                    s.data[s.pos] in (START, END)):
                break
            attr = s.get_u8()
            if attr == 0:
                break
            attributes_present.append(attr)

            if attr == OTBM_ATTR_ACTION_ID:
                attributes["action_id"] = s.get_u16()
            elif attr == OTBM_ATTR_UNIQUE_ID:
                attributes["unique_id"] = s.get_u16()
            elif attr == OTBM_ATTR_TEXT:
                attributes["text"] = s.get_string()
            elif attr == OTBM_ATTR_DESC:
                attributes["description"] = s.get_string()
            elif attr == OTBM_ATTR_TELE_DEST:
                attributes["teleport_destination"] = {
                    "x": s.get_u16(), "y": s.get_u16(), "z": s.get_u8()
                }
            elif attr == OTBM_ATTR_DEPOT_ID:
                attributes["depot_id"] = s.get_u16()
            elif attr == OTBM_ATTR_RUNE_CHARGES:
                subtype = s.get_u8()
                attributes["rune_charges"] = subtype
            elif attr == OTBM_ATTR_HOUSEDOORID:
                attributes["house_door_id"] = s.get_u8()
            elif attr == OTBM_ATTR_COUNT:
                subtype = s.get_u8()
                attributes["count_attribute"] = subtype
            elif attr == OTBM_ATTR_DURATION:
                attributes["duration"] = struct.unpack("<i", s._bytes(4))[0]
            elif attr == OTBM_ATTR_DECAYING_STATE:
                attributes["decaying_state"] = s.get_u8()
            elif attr == OTBM_ATTR_WRITTENDATE:
                attributes["written_date"] = s.get_u32()
            elif attr == OTBM_ATTR_WRITTENBY:
                attributes["written_by"] = s.get_string()
            elif attr == OTBM_ATTR_SLEEPERGUID:
                attributes["sleeper_guid"] = s.get_u32()
            elif attr == OTBM_ATTR_SLEEPSTART:
                attributes["sleep_start"] = s.get_u32()
            elif attr == OTBM_ATTR_CHARGES:
                subtype = s.get_u16()
                attributes["charges"] = subtype
            elif attr == OTBM_ATTR_KEYNUMBER:
                attributes["key_number"] = s.get_u16()
            elif attr == OTBM_ATTR_KEYHOLENUMBER:
                attributes["keyhole_number"] = s.get_u16()
            elif attr == OTBM_ATTR_DOORQUESTNUMBER:
                attributes["door_quest_number"] = s.get_u16()
            elif attr == OTBM_ATTR_DOORQUESTVALUE:
                attributes["door_quest_value"] = s.get_u16()
            elif attr == OTBM_ATTR_DOORLEVEL:
                attributes["door_level"] = s.get_u16()
            elif attr == OTBM_ATTR_CHESTQUESTNUMBER:
                attributes["chest_quest_number"] = s.get_u16()
            else:
                raise OTBMParseError(
                    "OTBM_UNSUPPORTED_ATTRIBUTE attr=%d context=%s" %
                    (attr, context))
    except OTBMParseError:
        raise
    except (IndexError, struct.error, UnicodeError) as error:
        raise OTBMParseError(
            "OTBM_TRUNCATED_ATTRIBUTE context=%s: %s" % (context, error))

    effective_count = subtype if subtype not in (None, 0) else 1
    result = {
        "server_id": server_id,
        "count": effective_count,
        "subtype": subtype,
        "attributes": attributes,
        "attributes_present": attributes_present,
    }
    while s.start_node():
        node_type = s.get_u8()
        if node_type == OTBM_ITEM:
            contents.append(_read_item(
                s, "%s:content" % context))
            if not s.end_node():
                raise OTBMParseError(
                    "OTBM_INVALID_NODE content(%s)" % context)
        else:
            s.skip_node_body()
    if contents:
        result["contents"] = contents
    return result


def _area(s: Stream, por_casilla, por_casilla_ext=None,
          por_casilla_detalle=None) -> None:
    base_x = s.get_u16()
    base_y = s.get_u16()
    base_z = s.get_u8()

    while s.start_node():
        tipo = s.get_u8()
        if tipo != OTBM_TILE and tipo != OTBM_HOUSETILE:
            s.skip_node_body()
            continue
        x = base_x + s.get_u8()
        y = base_y + s.get_u8()
        z = base_z
        house_id = 0
        if tipo == OTBM_HOUSETILE:
            house_id = s.get_u32()

        items = []
        banderas = 0

        # Las propiedades del tile preceden a sus nodos hijo. El siguiente
        # marcador START/END no es una propiedad y se devuelve al stream.
        while True:
            attr = s.get_u8()
            if attr in (START, END):
                s.back()
                break
            if attr == OTBM_ATTR_TILE_FLAGS:
                banderas = s.get_u32()
            elif attr == OTBM_ATTR_ITEM:
                items.append(_read_item(
                    s, "tile(%d,%d,%d):inline" % (x, y, z),
                    read_attributes=False))
            else:
                raise OTBMParseError(
                    "OTBM_UNSUPPORTED_ATTRIBUTE attr=%d context=tile(%d,%d,%d)" %
                    (attr, x, y, z))

        while s.start_node():
            t = s.get_u8()
            if t == OTBM_ITEM:
                items.append(_read_item(
                    s, "tile(%d,%d,%d):item" % (x, y, z)))
                if not s.end_node():
                    raise OTBMParseError(
                        "OTBM_INVALID_NODE item(%d,%d,%d)" % (x, y, z))
            else:
                s.skip_node_body()

        if not s.end_node():
            raise ValueError("casilla sin cerrar en (%d,%d,%d)" % (x, y, z))

        if items:
            ids = [item["server_id"] for item in items]
            if por_casilla_ext is not None:
                por_casilla_ext(x, y, z, ids, banderas, house_id)
            if por_casilla_detalle is not None:
                por_casilla_detalle(x, y, z, items, banderas, house_id)
            if por_casilla is not None:
                por_casilla(x, y, z, ids, banderas)

    if not s.end_node():
        raise ValueError("area sin cerrar")
