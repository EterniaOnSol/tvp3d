# Exportar el cliente Windows

Este procedimiento produce `dist/TVP3D.exe` sin abrir el editor. Godot y las
plantillas son dependencias de la maquina de build; el jugador solo recibe el
ejecutable.

## Prerrequisitos

- Godot `4.7.2.stable`, ejecutable de consola para Windows x86_64.
- Plantillas oficiales de exportacion `4.7.2.stable`.
- El preset versionado `cliente3d/export_presets.cfg`.

Las plantillas no se versionan. En Windows deben quedar en:

```text
%APPDATA%\Godot\export_templates\4.7.2.stable\
```

Para este preset debe existir, como minimo:

```text
windows_release_x86_64.exe
```

Si falta, descargar el paquete oficial
`Godot_v4.7.2-stable_export_templates.tpz`, abrirlo como ZIP y copiar el
contenido de su carpeta `templates` directamente al directorio anterior.
No copiar el `.tpz`, ni las plantillas, dentro del repositorio.

## Comando de exportacion

Desde la raiz del repositorio, en PowerShell:

```powershell
$godot = (Get-Command Godot_v4.7.2-stable_win64_console.exe -ErrorAction Stop).Source
& $godot --headless --path cliente3d --export-release windows-desktop '..\dist\TVP3D.exe'
```

La primera linea solo localiza la instalacion de Godot en el `PATH`. Si no
esta en el `PATH`, asignar a `$godot` la ruta local del ejecutable de
consola; esa ruta es configuracion de la maquina y no debe versionarse.

Comando exacto usado en esta estacion, expresado sin una ruta absoluta
versionada y ejecutado desde la raiz del repositorio:

```powershell
& '..\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path cliente3d --export-release windows-desktop '..\dist\TVP3D.exe'
```

El nombre `windows-desktop` coincide exactamente con el preset. El ultimo
argumento se resuelve respecto de `cliente3d`, por eso usa `..\dist`.

## Elegir servidor sin recompilar

La opcion recomendada para un jugador es un archivo de texto plano llamado
`tvp3d_host.txt`. Con `config/name="TVP3D"` y sin un directorio de usuario
personalizado, la ruta real de `user://tvp3d_host.txt` en Windows es:

```text
%APPDATA%\Godot\app_userdata\TVP3D\tvp3d_host.txt
```

Expandida por Windows, la misma ruta es
`C:\Users\<usuario>\AppData\Roaming\Godot\app_userdata\TVP3D\tvp3d_host.txt`.
Crear la carpeta si no existe y escribir una sola linea con el hostname, sin
`http://`, `https://` ni puerto, por ejemplo:

```text
juego.example.com
```

Cerrar y volver a abrir el cliente despues de cambiar el archivo. El host se
resuelve en este orden:

1. argumento de usuario `--host`;
2. variable de entorno `TVP3D_HOST`;
3. `user://tvp3d_host.txt`;
4. `localhost`.

Una prueba puntual por linea de comandos usa el separador de argumentos de
usuario de Godot:

```powershell
.\dist\TVP3D.exe -- --host juego.example.com
```

El preset no contiene host, IP, cuenta ni clave. `TVP3D_ACCOUNT` y
`TVP3D_PASSWORD` quedan reservadas para QA y no forman parte de la
configuracion que se entrega al jugador.

## Verificacion del artefacto del 2026-09-12

- Parseo/editor headless: codigo de salida `0`, sin errores de parseo.
- Exportacion release: codigo de salida `0`; finalizo con
  `[ DONE ] savepack`.
- Artefacto: `dist/TVP3D.exe`, 429304992 bytes,
  SHA-256 `E274D23FBDB9A711B858865B4E0DF4ABF274787AE225FEB5E461DD89D7810303`.
- Ejecucion: se abrio directamente `dist/TVP3D.exe`, con titulo `TVP3D`
  y ventana responsiva de 1296x759.
- Servidor local: los puertos 7171/7172 estaban publicados; el cliente mostro
  el formulario, recibio la lista de personajes y una ejecucion entro al
  mundo. No se registraron ni versionaron credenciales.
- `dist/` esta ignorado por Git; el ejecutable y las capturas de validacion
  no se commitean.
