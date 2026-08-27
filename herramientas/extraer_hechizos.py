"""Extrae el catalogo visible de hechizos desde los scripts Lua del servidor.

No ejecuta Lua ni duplica la logica de combate. Solo lee las llamadas de
configuracion de ``Spell`` y deja en JSON los parametros que el cliente puede
mostrar o usar para preparar el texto de lanzamiento. El servidor sigue
validando vocacion, nivel, mana, cooldown, objetivo y efectos.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = ROOT / "servidor" / "data" / "scripts" / "spells"
DEFAULT_OUTPUT = ROOT / "cliente3d" / "assets" / "spells772.json"


def _texto(linea: str, metodo: str) -> str | None:
    encontrado = re.search(
        rf"spell:{re.escape(metodo)}\(\s*\"([^\"]*)\"\s*\)", linea
    )
    return encontrado.group(1) if encontrado else None


def _numero(linea: str, metodo: str) -> int | None:
    encontrado = re.search(
        rf"spell:{re.escape(metodo)}\(\s*(-?\d+)\s*\)", linea
    )
    return int(encontrado.group(1)) if encontrado else None


def _booleano(linea: str, metodo: str) -> bool | None:
    encontrado = re.search(
        rf"spell:{re.escape(metodo)}\(\s*(true|false)\s*\)", linea
    )
    if not encontrado:
        return None
    return encontrado.group(1) == "true"


def _lista_texto(linea: str, metodo: str) -> list[str] | None:
    encontrado = re.search(rf"spell:{re.escape(metodo)}\((.*)\)", linea)
    if not encontrado:
        return None
    return re.findall(r'"([^"]+)"', encontrado.group(1))


def _parametros_combate(lineas: list[str]) -> dict[str, object]:
    parametros: dict[str, object] = {}
    for linea in lineas:
        encontrado = re.search(
            r"combat:setParameter\(\s*(COMBAT_PARAM_[A-Z_]+)\s*,\s*([^\)]+)\)",
            linea,
        )
        if encontrado:
            parametros[encontrado.group(1)] = encontrado.group(2).strip()
        area = re.search(r"combat:setArea\(createCombatArea\(([^\)]+)\)\)", linea)
        if area:
            parametros["area"] = area.group(1).strip()
    return parametros


def _extraer_archivo(ruta: Path, raiz: Path) -> dict[str, object]:
    lineas = ruta.read_text(encoding="utf-8").splitlines()
    texto = "\n".join(lineas)
    tipo = "rune" if "Spell(SPELL_RUNE)" in texto else "instant"
    resultado: dict[str, object] = {
        "name": _primero(lineas, "name") or ruta.stem.replace("_", " ").title(),
        "words": _primero(lineas, "words") or "",
        "type": tipo,
        "source": ruta.relative_to(raiz).as_posix(),
        "category": ruta.parent.name,
        "vocations": _primero_lista(lineas, "vocation"),
        "mana": _primero_numero(lineas, "mana", 0),
        "mana_percent": _primero_numero(lineas, "manaPercent", 0),
        "magic_level": _primero_numero(lineas, "magicLevel", 0),
        "level": _primero_numero(lineas, "level", 0),
        "soul": _primero_numero(lineas, "soul", 0),
        "cooldown_ms": _primero_numero(lineas, "cooldown", 2000),
        "range": _primero_numero(lineas, "range", -1),
        "premium": _primero_booleano(lineas, "isPremium", False),
        "aggressive": _primero_booleano(lineas, "isAggressive", True),
        "need_learn": _primero_booleano(lineas, "needLearn", True),
        "need_target": _primero_booleano(lineas, "needTarget", False),
        "need_direction": _primero_booleano(lineas, "needDirection", False),
        "self_target": _primero_booleano(lineas, "selfTarget", False),
        "has_parameter": _primero_booleano(lineas, "hasParams", False),
        "has_player_name_parameter": _primero_booleano(
            lineas, "hasPlayerNameParam", False
        ),
        "blocking_walls": _primero_booleano(lineas, "isBlockingWalls", True),
        "blocking_creature": _primero_is_blocking_creature(lineas),
        "combat": _parametros_combate(lineas),
    }
    rune_id = _primero_numero(lineas, "runeId", None)
    if rune_id is not None:
        resultado["rune_id"] = rune_id
    return resultado


def _primero(lineas: list[str], metodo: str) -> str | None:
    for linea in lineas:
        valor = _texto(linea, metodo)
        if valor is not None:
            return valor
    return None


def _primero_numero(lineas: list[str], metodo: str, defecto: int | None) -> int | None:
    for linea in lineas:
        valor = _numero(linea, metodo)
        if valor is not None:
            return valor
    return defecto


def _primero_booleano(lineas: list[str], metodo: str, defecto: bool) -> bool:
    for linea in lineas:
        valor = _booleano(linea, metodo)
        if valor is not None:
            return valor
    return defecto


def _primero_lista(lineas: list[str], metodo: str) -> list[str]:
    for linea in lineas:
        valor = _lista_texto(linea, metodo)
        if valor:
            return valor
    return []


def _primero_is_blocking_creature(lineas: list[str]) -> bool:
    for linea in lineas:
        encontrado = re.search(r"spell:isBlocking\(([^\)]*)\)", linea)
        if not encontrado:
            continue
        valores = [v.strip() for v in encontrado.group(1).split(",")]
        return len(valores) > 1 and valores[1] == "true"
    return False


def extraer(origen: Path, destino: Path) -> int:
    hechizos = [
        _extraer_archivo(ruta, origen)
        for ruta in sorted(origen.rglob("*.lua"))
        if re.search(r"(?m)\bSpell\s*\(", ruta.read_text(encoding="utf-8"))
    ]
    hechizos.sort(key=lambda item: (str(item["type"]), str(item["name"]).lower()))
    documento = {
        "format": "tvp3d.spells.v1",
        "protocol": 772,
        "source": "servidor/data/scripts/spells",
        "server_defaults": {
            "cooldown_ms": 2000,
            "aggressive": True,
            "need_learn": True,
            "blocking_walls": True,
        },
        "spells": hechizos,
    }
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(json.dumps(documento, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return len(hechizos)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    cantidad = extraer(args.source, args.output)
    print(f"Extraidos {cantidad} hechizos a {args.output}")


if __name__ == "__main__":
    main()
