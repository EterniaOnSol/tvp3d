param(
	[string]$VideoPath,
	[string]$OutputDirectory
)

Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

New-Item -ItemType Directory -Force $OutputDirectory | Out-Null

$player = New-Object System.Windows.Media.MediaPlayer
$player.Volume = 0
$player.ScrubbingEnabled = $true
$opened = New-Object System.Threading.ManualResetEvent($false)
$failed = New-Object System.Threading.ManualResetEvent($false)
$player.add_MediaOpened({ $opened.Set() | Out-Null })
$player.add_MediaFailed({ $failed.Set() | Out-Null })
$player.Open([Uri]::new($VideoPath))

$dispatcher = [System.Windows.Threading.Dispatcher]::CurrentDispatcher
$deadline = [DateTime]::UtcNow.AddSeconds(30)
while (-not $opened.WaitOne(0) -and [DateTime]::UtcNow -lt $deadline) {
	$dispatcher.Invoke([Action] {}, [System.Windows.Threading.DispatcherPriority]::Background)
	Start-Sleep -Milliseconds 50
}
if (-not $opened.WaitOne(0)) {
	throw "The video did not open in time."
}
if ($failed.WaitOne(0)) {
	throw "Windows Media Foundation could not decode the video."
}

$width = [int]$player.NaturalVideoWidth
$height = [int]$player.NaturalVideoHeight
$duration = $player.NaturalDuration.TimeSpan.TotalSeconds
$times = @()
for ($t = 0.0; $t -lt $duration; $t += 2.0) {
	$times += $t
}

Write-Output ("video={0}x{1} duration={2:F2}s" -f $width, $height, $duration)

for ($i = 0; $i -lt $times.Count; $i++) {
	$player.Stop()
	$player.Position = [TimeSpan]::FromSeconds([double]$times[$i])
	$player.Play()
	Start-Sleep -Milliseconds 350
	$player.Pause()

	$visual = New-Object System.Windows.Media.DrawingVisual
	$context = $visual.RenderOpen()
	$context.DrawVideo($player, [System.Windows.Rect]::new(0, 0, $width, $height))
	$context.Close()

	$bitmap = New-Object System.Windows.Media.Imaging.RenderTargetBitmap(
		$width, $height, 96, 96,
		[System.Windows.Media.PixelFormats]::Pbgra32)
	$bitmap.Render($visual)
	$encoder = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
	$encoder.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
	$name = "frame_{0:D2}_{1:D5}.png" -f $i, [int]$times[$i]
	$path = Join-Path $OutputDirectory $name
	$stream = [System.IO.File]::Open($path, [System.IO.FileMode]::Create)
	$encoder.Save($stream)
	$stream.Close()
	Write-Output $path
}

$player.Close()
