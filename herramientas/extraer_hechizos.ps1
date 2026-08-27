param(
    [string]$Source = "$PSScriptRoot\..\servidor\data\scripts\spells",
    [string]$Output = "$PSScriptRoot\..\cliente3d\assets\spells772.json"
)

$items = @()
$sourcePath = (Resolve-Path -LiteralPath $Source).Path
$files = Get-ChildItem -LiteralPath $sourcePath -Recurse -Filter '*.lua' -File
foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw
    if ($text -notmatch '(?m)\bSpell\s*\(') {
        continue
    }
    $getText = {
        param([string]$name)
        $match = [regex]::Match($text, ('spell:' + $name + '\(\s*"([^"]*)"\s*\)'))
        if ($match.Success) { return $match.Groups[1].Value }
        return $null
    }
    $getNumber = {
        param([string]$name, [int]$default)
        $match = [regex]::Match($text, ('spell:' + $name + '\(\s*(-?\d+)\s*\)'))
        if ($match.Success) { return [int]$match.Groups[1].Value }
        return $default
    }
    $getBool = {
        param([string]$name, [bool]$default)
        $match = [regex]::Match($text, ('spell:' + $name + '\(\s*(true|false)\s*\)'))
        if ($match.Success) { return $match.Groups[1].Value -eq 'true' }
        return $default
    }
    $name = & $getText 'name'
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase(
            ($file.BaseName -replace '_', ' '))
    }
    $words = & $getText 'words'
    $vocMatch = [regex]::Match($text, 'spell:vocation\(([^\)]*)\)')
    $vocations = @()
    if ($vocMatch.Success) {
        $vocations = @([regex]::Matches($vocMatch.Groups[1].Value, '"([^"]+)"') |
            ForEach-Object { $_.Groups[1].Value })
    }
    $combat = [ordered]@{}
    foreach ($match in [regex]::Matches($text,
        'combat:setParameter\(\s*(COMBAT_PARAM_[A-Z_]+)\s*,\s*([^\)]+)\)')) {
        $combat[$match.Groups[1].Value] = $match.Groups[2].Value.Trim()
    }
    $area = [regex]::Match($text, 'combat:setArea\(createCombatArea\(([^\)]+)\)\)')
    if ($area.Success) { $combat['area'] = $area.Groups[1].Value.Trim() }
    $blockingCreature = $false
    $blocking = [regex]::Match($text, 'spell:isBlocking\(([^\)]*)\)')
    if ($blocking.Success) {
        $args = $blocking.Groups[1].Value.Split(',')
        $blockingCreature = $args.Count -gt 1 -and $args[1].Trim() -eq 'true'
    }
    $items += [ordered]@{
        name = $name
        words = $words
        type = if ($text.Contains('Spell(SPELL_RUNE)')) { 'rune' } else { 'instant' }
        source = ($file.FullName.Substring($sourcePath.Length).TrimStart('\','/') -replace '\\','/')
        category = $file.Directory.Name
        vocations = $vocations
        mana = & $getNumber 'mana' 0
        mana_percent = & $getNumber 'manaPercent' 0
        magic_level = & $getNumber 'magicLevel' 0
        level = & $getNumber 'level' 0
        soul = & $getNumber 'soul' 0
        cooldown_ms = & $getNumber 'cooldown' 2000
        range = & $getNumber 'range' -1
        premium = & $getBool 'isPremium' $false
        aggressive = & $getBool 'isAggressive' $true
        need_learn = & $getBool 'needLearn' $true
        need_target = & $getBool 'needTarget' $false
        need_direction = & $getBool 'needDirection' $false
        self_target = & $getBool 'selfTarget' $false
        has_parameter = & $getBool 'hasParams' $false
        has_player_name_parameter = & $getBool 'hasPlayerNameParam' $false
        blocking_walls = & $getBool 'isBlockingWalls' $true
        blocking_creature = $blockingCreature
        combat = $combat
    }
    $rune = [regex]::Match($text, 'spell:runeId\(\s*(\d+)\s*\)')
    if ($rune.Success) { $items[-1].rune_id = [int]$rune.Groups[1].Value }
}
$items = @($items | Sort-Object @{Expression = { $_.type }}, @{Expression = { $_.name }})
$document = [ordered]@{
    format = 'tvp3d.spells.v1'
    protocol = 772
    source = 'servidor/data/scripts/spells'
    server_defaults = [ordered]@{
        cooldown_ms = 2000
        aggressive = $true
        need_learn = $true
        blocking_walls = $true
    }
    spells = $items
}
$parent = Split-Path -Parent $Output
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$document | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Output -Encoding UTF8
Write-Output "Extraidos $($items.Count) hechizos a $Output"
