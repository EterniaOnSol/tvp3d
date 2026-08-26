# Contrato: integracion

Version: 1.0.0
Estado: PUBLICADO
Propietario: integracion
Depende de: servidor, cliente, editor, assets

## Proposito

Permitir que una maquina limpia clone TVP3D, prepare sus herramientas y
arranque tanto el perfil legacy TVP 7.72 como el perfil propio Godot usando
rutas relativas al repositorio.

## Requisitos de maquina

- Windows 10/11.
- Docker Desktop iniciado y con Docker Compose disponible.
- Godot 4.7.x. Puede estar en `herramientas/godot/`, en el PATH como `godot`,
  o indicarse con la variable `TVP3D_GODOT`.
- El repositorio privado clonado con todos sus archivos versionados.

## Archivos de desarrollo versionados

- `servidor/config.lua` contiene la configuracion local Docker de TVP3D.
- `servidor/key.pem` contiene la clave RSA de desarrollo compatible con
  `cliente3d/red/rsa.gd`.
- `servidor/gamedata/` y `.godot/` siguen siendo estado local generado y no se
  versionan.

## Comandos publicos

| Comando | Resultado |
|---|---|
| `PREPARAR TVP3D.bat` | Verifica Docker, Godot, config y RSA |
| `ARRANCAR SERVIDOR.bat` | Compila y arranca TVP y MariaDB en Docker |
| `JUGAR.bat` | Abre el cliente TVP3D conectado a localhost |
| `ABRIR MAP EDITOR.bat` | Abre el editor 3D del mapa |
| `PROBAR CONEXION.bat` | Ejecuta la prueba de login y movimiento |
| `PARAR SERVIDOR.bat` | Detiene los contenedores sin borrar la base |
| `PREPARAR TVP3D PROPIO.bat` | Verifica Godot y las escenas del perfil propio |
| `ARRANCAR SERVIDOR PROPIO.bat` | Arranca el servidor Godot headless en `7277` |
| `JUGAR PROPIO.bat` | Abre el cliente propio 3D en `7277` |
| `PROBAR SERVIDOR PROPIO.bat` | Comprueba dos clientes, estado compartido y ocupacion |

Todos los comandos se resuelven desde `%~dp0`; no dependen de
`C:\Users\dell\...` ni de un directorio de trabajo externo.

## Perfil de red

- Login: `7171`.
- Juego: `7172`.
- MariaDB desde Windows: `3371`.
- phpMyAdmin: `8071`.
- Dentro de Docker, el servidor usa `mariadb:3306`.
- Perfil propio: TCP `127.0.0.1:7277`, sin Docker ni MariaDB.

## Criterio de aceptacion

Una maquina con Docker Desktop y Godot instalados puede ejecutar `PREPARAR
TVP3D.bat`, luego `ARRANCAR SERVIDOR.bat` y `JUGAR.bat`; el cliente llega a la
pantalla de juego con la cuenta de desarrollo y el mapa completo. Sin Docker,
el perfil propio debe pasar `PREPARAR TVP3D PROPIO.bat`, luego
`ARRANCAR SERVIDOR PROPIO.bat` y `JUGAR PROPIO.bat`; el recorrido de dos
clientes se valida con `PROBAR SERVIDOR PROPIO.bat`. Los modelos 3D de
criaturas se pueden agregar bajo `cliente3d/assets/` y conectarse al
identificador/nombre conservado por el renderer de cubos.

## Errores

- Si falta Docker, Godot, `servidor/config.lua` o `servidor/key.pem`, el
  preparador termina con codigo distinto de cero y explica el archivo faltante.
- Si Docker no esta iniciado, el preparador lo reporta sin imprimir
  credenciales.
