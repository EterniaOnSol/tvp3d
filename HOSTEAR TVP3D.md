# Probar TVP3D con amigos usando Radmin VPN

Para una prueba pequeña, tu PC puede ser el host. Como estás compartiendo
internet desde el celular, Radmin VPN evita depender del reenvío de puertos
del operador móvil.

## En tu PC (host)

1. Abre Radmin VPN y pulsa **Power On**.
2. Crea una red en **Network -> Create new network**. Usa un nombre y una
   contraseña que no hayas publicado.
3. Pásale a tu amigo el nombre y la contraseña de esa red.
4. Ejecuta `ARRANCAR PRUEBA RADMIN.bat` desde la carpeta de TVP3D.
5. El archivo mostrará tu IP virtual `26.x.x.x`. Esa es la IP que debes
   compartirle; no compartas la IP de tu celular ni la de Docker.

Radmin VPN hace que los equipos de la misma red virtual puedan comunicarse
como si estuvieran en una LAN. La guía oficial indica que el host crea la red
y el otro jugador entra con **Join an existing Network**:
[guía oficial de redes de Radmin VPN](https://radmin-club.com/radmin-vpn/how-to-manage-your-network/).

## En el PC de tu amigo

1. Instala Radmin VPN y entra a la red virtual con **Network -> Join an
   existing Network**.
2. Confirma que tu PC aparezca conectado/verde en la lista.
3. Copia la carpeta de TVP3D y Godot, o dale un ZIP del cliente.
4. Abre `JUGAR REMOTO.bat` y cambia esta línea:

   `set "TVP3D_HOST=CAMBIAR_POR_IP_PUBLICA_O_DOMINIO"`

   por la IP `26.x.x.x` que muestra tu Radmin VPN.
5. Abre la web en `http://IP_RADMIN:8072`, crea una cuenta y un personaje,
   y luego entra al juego con esas mismas credenciales.

## Puertos usados dentro de Radmin

- Juego/login: `7171` y `7172`.
- Página web: `8072`.

No hay que abrir `3371` (MariaDB) ni `8071` (phpMyAdmin). Si Windows
Firewall pregunta, permite Docker y el servidor en la red de Radmin; si la
conexión aparece bloqueada, la documentación oficial recomienda revisar el
firewall de Windows para la conexión virtual.

## Proximity chat

El chat de voz funciona en tiempo real mientras ambos jugadores estén cerca
en el mismo piso. Mantén presionada `V` para hablar y suéltala para dejar de
transmitir. Ambos deben permitir el acceso al micrófono de Windows.

Esta configuración es para la prueba. Más adelante, si queremos que entren
personas sin instalar Radmin VPN, pasamos el servidor y la web a un VPS.
