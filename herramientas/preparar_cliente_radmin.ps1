param(
    [string]$HostAddress = ''
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dist = Join-Path $repo 'dist'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$packageName = "TVP3D-Radmin-Cliente-$stamp"
$package = Join-Path $dist $packageName
$client = Join-Path $package 'cliente3d'
$engine = Join-Path $package 'herramientas\godot'

$serverAddress = $HostAddress.Trim()
if ([string]::IsNullOrWhiteSpace($serverAddress)) {
    # ipconfig no necesita permisos de administrador y funciona igual desde
    # PowerShell, un .bat o una consola lanzada por otro usuario.
    foreach ($line in (& ipconfig.exe)) {
        if ($line -match '(26\.\d{1,3}\.\d{1,3}\.\d{1,3})') {
            $serverAddress = $Matches[1]
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($serverAddress)) {
    throw 'No se encontro la IP 26.x.x.x de Radmin VPN. Abre Radmin VPN o pasa -HostAddress.'
}

New-Item -ItemType Directory -Force -Path $client, $engine | Out-Null

# Solo se incluyen los datos que usa el cliente en tiempo de ejecucion.
# Se excluyen .godot, reportes de QA, capturas y escenas de pruebas para que
# el ZIP no transporte el entorno de desarrollo completo.
$clientEntries = @(
    'assets',
    'comun',
    'mundo',
    'red',
    'ui',
    'generated\maps',
    'generated\world_mapper',
    'main.tscn',
    'mundo3d.gd',
    'dialogo_3d.gd',
    'numero_dano_3d.gd',
    'project.godot'
)

foreach ($entry in $clientEntries) {
    $source = Join-Path $repo ("cliente3d\$entry")
    $target = Join-Path $client $entry
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Falta el archivo o carpeta requerido: $source"
    }
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force
}

$godotSource = Join-Path $repo '..\3DTIBIA\herramientas\godot'
if (-not (Test-Path -LiteralPath $godotSource)) {
    throw "No se encontro Godot en $godotSource"
}
Copy-Item -LiteralPath (Join-Path $godotSource 'Godot_v4.7.2-stable_win64.exe') -Destination $engine -Force
Copy-Item -LiteralPath (Join-Path $godotSource 'Godot_v4.7.2-stable_win64_console.exe') -Destination $engine -Force
Copy-Item -LiteralPath (Join-Path $repo 'herramientas\resolver_godot.bat') -Destination (Join-Path $package 'herramientas') -Force
Copy-Item -LiteralPath (Join-Path $repo 'JUGAR REMOTO.bat') -Destination $package -Force
Copy-Item -LiteralPath (Join-Path $repo 'CLIENTE REMOTO - LEEME.txt') -Destination $package -Force

# El ZIP queda listo para jugar: el amigo no tiene que editar el .bat.
$remoteLauncher = Join-Path $package 'JUGAR REMOTO.bat'
(Get-Content -LiteralPath $remoteLauncher -Raw).Replace('CAMBIAR_POR_IP_RADMIN', $serverAddress) |
    Set-Content -LiteralPath $remoteLauncher -Encoding ascii
$readme = Join-Path $package 'CLIENTE REMOTO - LEEME.txt'
(Get-Content -LiteralPath $readme -Raw).Replace('IP_RADMIN', $serverAddress) |
    Set-Content -LiteralPath $readme -Encoding utf8

$zip = Join-Path $dist "$packageName.zip"
Compress-Archive -LiteralPath $package -DestinationPath $zip -CompressionLevel Fastest

$size = [math]::Round((Get-Item -LiteralPath $zip).Length / 1MB, 1)
Write-Host "Cliente listo: $zip ($size MB)"
Write-Host "Servidor configurado en Radmin: $serverAddress"
