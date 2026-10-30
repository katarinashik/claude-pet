# Makes the pet's icon from his real approved art: the first typing frame of storyboards\typing-angle.png,
# cut square, the light background made see-through and put on a rounded tile.
# Usage: .\tools\Make-Icon.ps1 [-Tile light|dark|none]   (light: the one Katya chose) [-Out <path>] [-Preview <png>]
#   -Preview also saves a picture of the icon at the sizes Windows shows (256, 48, 32, 16).
param([ValidateSet('dark', 'light', 'none')][string]$Tile = 'light', [string]$Out = '', [string]$Preview = '')
Add-Type -AssemblyName System.Drawing
$root = Split-Path $PSScriptRoot
if (-not $Out) { $Out = Join-Path $root 'ClaudePet.ico' }

# the first frame of the storyboard: 378 px wide; the art starts at y 90, the laptop ends at the frame's bottom (396)
$sheet = [Drawing.Bitmap]::FromFile((Join-Path $root 'storyboards\typing-angle.png'))
$side = 378; $top = 396 - $side
$art = New-Object Drawing.Bitmap $side, $side
for ($y = 0; $y -lt $side; $y++) {
  for ($x = 0; $x -lt $side; $x++) {
    $c = $sheet.GetPixel($x, $y + $top)
    if ([Math]::Abs($c.R - 0xEC) + [Math]::Abs($c.G - 0xE8) + [Math]::Abs($c.B - 0xE2) -lt 12) { $c = [Drawing.Color]::Transparent }
    $art.SetPixel($x, $y, $c)
  }
}
$sheet.Dispose()

function New-IconImage([int]$size) {
  $img = New-Object Drawing.Bitmap $size, $size
  $gr = [Drawing.Graphics]::FromImage($img); $gr.Clear([Drawing.Color]::Transparent)
  if ($Tile -ne 'none') {
    $gr.SmoothingMode = 'AntiAlias'
    $fill = if ($Tile -eq 'dark') { '#282C38' } else { '#ECE8E2' }
    $r = [Math]::Max(2, [int]($size * 0.2)); $path = New-Object Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $r, $r, 180, 90); $path.AddArc($size - $r - 1, 0, $r, $r, 270, 90)
    $path.AddArc($size - $r - 1, $size - $r - 1, $r, $r, 0, 90); $path.AddArc(0, $size - $r - 1, $r, $r, 90, 90); $path.CloseFigure()
    $brush = New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml($fill)); $gr.FillPath($brush, $path); $brush.Dispose()
  }
  # crisp pixels, a small margin on the tile
  $gr.InterpolationMode = 'NearestNeighbor'; $gr.PixelOffsetMode = 'Half'
  $m = if ($Tile -ne 'none') { [int]($size * 0.1) } else { 0 }
  $gr.DrawImage($art, (New-Object Drawing.Rectangle $m, $m, ($size - 2 * $m), ($size - 2 * $m)))
  $gr.Dispose()
  , $img
}

# ICO with several PNG images inside, so every size Windows asks for stays sharp
$sizes = @(256, 64, 48, 32, 16)
$pngs = foreach ($s in $sizes) { $img = New-IconImage $s; $ms = New-Object IO.MemoryStream; $img.Save($ms, [Drawing.Imaging.ImageFormat]::Png); $img.Dispose(); , $ms.ToArray() }
$fs = [IO.File]::Create($Out); $w = New-Object IO.BinaryWriter $fs
$w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $px = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
  $w.Write([byte]$px); $w.Write([byte]$px); $w.Write([byte]0); $w.Write([byte]0)
  $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$offset)
  $offset += $pngs[$i].Length
}
foreach ($p in $pngs) { $w.Write($p) }
$w.Close()

if ($Preview) {
  $show = @(256, 48, 32, 16); $pv = New-Object Drawing.Bitmap 400, 270
  $gr = [Drawing.Graphics]::FromImage($pv); $gr.Clear([Drawing.Color]::FromArgb(0x20, 0x5A, 0x9E)); $x = 6
  foreach ($s in $show) { $img = New-IconImage $s; $gr.DrawImageUnscaled($img, $x, 6); $x += $s + 12; $img.Dispose() }
  $gr.Dispose(); $pv.Save($Preview, [Drawing.Imaging.ImageFormat]::Png); $pv.Dispose()
}
$art.Dispose()
$Out
