# Draws the pet's icon (a 16 x 16 pixel Claude scaled to 64 x 64) and saves it as an .ico with a PNG inside.
# Usage: .\tools\Make-Icon.ps1 [-Out <path>]   (default: ClaudePet.ico next to the script folder)
param([string]$Out = '')
Add-Type -AssemblyName System.Drawing
if (-not $Out) { $Out = Join-Path (Split-Path $PSScriptRoot) 'ClaudePet.ico' }
$rows = @(
  '................',
  '................',
  '................',
  '...oooooooooo...',
  '...oooooooooo...',
  '...oodoooodoo...',
  '.ooodoooodoooo..',
  '.oooooooooooooo.',
  '...oooooooooo...',
  '...oooooooooo...',
  '...oooooooooo...',
  '...oooooooooo...',
  '....o.o..o.o....',
  '....o.o..o.o....',
  '................',
  '................')
$colors = @{ o = '#D97757'; d = '#2A1A14' }
$scale = 4
$bmp = New-Object Drawing.Bitmap 64, 64
$gr = [Drawing.Graphics]::FromImage($bmp); $gr.Clear([Drawing.Color]::Transparent)
for ($y = 0; $y -lt 16; $y++) {
  for ($x = 0; $x -lt 16; $x++) {
    $ch = [string]$rows[$y][$x]
    if ($colors.ContainsKey($ch)) {
      $brush = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml($colors[$ch]))
      $gr.FillRectangle($brush, $x * $scale, $y * $scale, $scale, $scale); $brush.Dispose()
    }
  }
}
$gr.Dispose()
$ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
$png = $ms.ToArray()
# ICO: 6-byte header, one 16-byte entry, then the PNG
$fs = [IO.File]::Create($Out); $w = New-Object IO.BinaryWriter $fs
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]1)
$w.Write([byte]64); $w.Write([byte]64); $w.Write([byte]0); $w.Write([byte]0)
$w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$png.Length); $w.Write([uint32]22)
$w.Write($png); $w.Close()
$Out
