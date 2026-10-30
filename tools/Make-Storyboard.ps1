# Renders a storyboard for a pose: runs the real ClaudePet.ps1 art (without opening the pet),
# plays the frame lines from a frames file, and puts every Shot side by side, light and dark backgrounds in turn.
#   powershell -sta -NoProfile -File tools\Make-Storyboard.ps1 -Frames frames\coffee.ps1
# The picture goes to storyboards\<frames name>.png unless -Out says otherwise.
param([Parameter(Mandatory = $true)][string]$Frames, [string]$Out = '', [int]$Scale = 3, [int]$Columns = 4)

$root = Split-Path $PSScriptRoot
$Frames = (Resolve-Path $Frames).Path
if (-not $Out) { $Out = Join-Path $root ("storyboards\" + [IO.Path]::GetFileNameWithoutExtension($Frames) + '.png') }
$work = Join-Path $env:TEMP 'claudepet-storyboard'
New-Item -ItemType Directory -Force $work | Out-Null
Get-ChildItem $work -Filter '*.png' | Remove-Item

# the pet's own code up to the point where it would open the window; its own lock name, and no pet.log lines
$src = [IO.File]::ReadAllText((Join-Path $root 'ClaudePet.ps1'))
$src = $src.Replace("'Local\ClaudeDesktopPet'", "'Local\ClaudePetStoryboard'").Replace('param([int]$TestSeconds = 0', 'param([int]$TestSeconds = 1')
$src = $src.Substring(0, $src.IndexOf('[void]$win.ShowDialog()'))

$prelude = @'
$S.lv = 4; Set-Laptop 4; Set-Legs -1; $bang.Visibility = 'Hidden'
$sz = New-Object System.Windows.Size(($GW * $PX), (($GH + $OY) * $PX))
$script:shotN = 0
function Shot([string]$name) {
  $script:shotN++
  $scene.Measure($sz); $scene.Arrange((New-Object System.Windows.Rect(0, 0, $sz.Width, $sz.Height))); $scene.UpdateLayout()
  $bmp = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]$sz.Width, [int]$sz.Height, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
  $bmp.Render($win.Content)
  $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
  $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($bmp))
  $fs = [IO.File]::Create((Join-Path 'WORK' ('{0:D2}.png' -f $script:shotN))); $enc.Save($fs); $fs.Close()
}
'@
$run = Join-Path $work 'run.ps1'
[IO.File]::WriteAllText($run, $src + "`n" + $prelude.Replace('WORK', $work) + "`n" + [IO.File]::ReadAllText($Frames))
& powershell.exe -Sta -NoProfile -ExecutionPolicy Bypass -File $run

# contact sheet, nearest-neighbour so the pixels stay sharp
Add-Type -AssemblyName System.Drawing
$shots = @(Get-ChildItem $work -Filter '*.png' | Sort-Object Name)
if ($shots.Count -eq 0) { throw 'no frames were rendered: check the frames file' }
$first = [Drawing.Image]::FromFile($shots[0].FullName)
$w = $first.Width * $Scale; $h = $first.Height * $Scale; $first.Dispose()
$cols = [Math]::Min($Columns, $shots.Count); $rows = [Math]::Ceiling($shots.Count / $cols); $gap = 6
$sheet = New-Object Drawing.Bitmap(($cols * $w + ($cols - 1) * $gap), ($rows * $h + ($rows - 1) * $gap))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::White)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
for ($k = 0; $k -lt $shots.Count; $k++) {
  $x = ($k % $cols) * ($w + $gap); $y = [Math]::Floor($k / $cols) * ($h + $gap)
  $bg = if ($k % 2) { [Drawing.Color]::FromArgb(40, 44, 58) } else { [Drawing.Color]::FromArgb(236, 232, 224) }
  $g.FillRectangle((New-Object Drawing.SolidBrush $bg), $x, $y, $w, $h)
  $img = [Drawing.Image]::FromFile($shots[$k].FullName); $g.DrawImage($img, $x, $y, $w, $h); $img.Dispose()
}
$g.Dispose()
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$sheet.Save($Out); $sheet.Dispose()
"$($shots.Count) frames -> $Out"
