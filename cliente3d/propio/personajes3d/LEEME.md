# Outfits humanos 3D

Componente procedural para los outfits clasicos de Tibia 7.72:

- Masculinos 128-134: Citizen, Hunter, Mage, Knight, Nobleman, Summoner,
  Warrior.
- Femeninos 136-142: Citizen, Hunter, Mage, Knight, Noblewoman, Summoner,
  Warrior.

Cada perfil comparte un esqueleto humano sencillo y agrega una silueta propia
de ropa y equipo. Acepta cuatro colores 0..132 en orden cabeza, cuerpo,
piernas y pies. La conversion HSI replica Outfit::getColor del cliente
OTClient incluido en 3DTIBIA (licencia MIT).

La base mide cerca de 0.95 casillas; sombreros, cascos y armas pueden elevar el
AABB hasta 1.15. El componente ofrece cuatro orientaciones y tres poses.

Integracion runtime:

- El jugador local usa apariencia, colores y direccion confirmados.
- Sus piezas conservan depth test para no colapsar visualmente en una lamina.
- Otros jugadores con IDs del rango de jugador usan el mismo componente.
- Caminar reproduce tres poses; al detenerse vuelve a la pose idle.
- Outfits no soportados, NPCs y casos incompatibles conservan el billboard.
- El cambio es visual: no altera colisiones, ocupacion ni autoridad.

Verificacion:

    Godot --headless --path cliente3d --script res://propio/personajes3d/self_test.gd

## Evolucion prevista: outfits personalizados premium

El componente separa el tipo de outfit de la geometria para poder agregar en
el futuro modelos o packs 3D aportados por el jugador como servicio de pago.
Antes de habilitarlo se necesita un pipeline de importacion controlado:

- formatos y presupuesto tecnico definidos (GLB, triangulos, materiales,
  texturas, huesos y animaciones);
- normalizacion automatica de escala, pivote, orientaciones y sombreado;
- validacion de archivos, derechos de uso y moderacion visual;
- previsualizacion y aprobacion antes de asociarlo a la cuenta;
- almacenamiento/CDN, versionado, retirada y restauracion del outfit;
- cobro, reembolsos y reglas visibles de propiedad/licencia.

Un outfit personalizado sera exclusivamente cosmetico: nunca modificara la
ocupacion, hitbox, alcance, velocidad ni ninguna regla autoritativa.
