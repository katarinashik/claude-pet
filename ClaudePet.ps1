param([int]$TestSeconds = 0, [string]$Log = '')

$mutex = New-Object System.Threading.Mutex($false, 'Local\ClaudeDesktopPet')
if (-not $mutex.WaitOne(0)) { exit }

# everything of his lives in %USERPROFILE%\ClaudePet: not in %LOCALAPPDATA%, which the Claude desktop app keeps
# in its own sandbox (Windows outside the app can't see it there, and the app closed him with its session)
$petDir = Join-Path $env:USERPROFILE 'ClaudePet'
# pet.log: when he starts, when and why he stops, and any error inside (kept small)
$petLog = Join-Path $petDir 'pet.log'
function Write-PetLog([string]$msg) {
  if ($TestSeconds -gt 0) { return }
  try {
    if ((Test-Path $petLog) -and (Get-Item $petLog).Length -gt 200KB) { Move-Item $petLog "$petLog.old" -Force }
    Add-Content $petLog ('{0:yyyy-MM-dd HH:mm:ss}  {1}' -f (Get-Date), $msg)
  } catch {}
}
Write-PetLog "started (pid $PID)"
$script:byeChosen = $false

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Add-Type -TypeDefinition @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class PetWin {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }
  delegate bool MonitorEnumProc(IntPtr hMon, IntPtr hdc, IntPtr rect, IntPtr data);
  delegate bool EnumWindowsProc(IntPtr h, IntPtr l);

  [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h, int i);
  [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h, int i, int v);
  [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
  [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumWindowsProc f, IntPtr l);
  [DllImport("user32.dll")] static extern bool EnumDisplayMonitors(IntPtr hdc, IntPtr clip, MonitorEnumProc f, IntPtr d);
  [DllImport("user32.dll")] static extern bool GetMonitorInfo(IntPtr hMon, ref MONITORINFO mi);
  [DllImport("dwmapi.dll")] static extern int DwmGetWindowAttribute(IntPtr h, int attr, out int v, int size);

  public static RECT GetRect(IntPtr h) { RECT r; GetWindowRect(h, out r); return r; }
  public static void MoveTo(IntPtr h, int x, int y) { SetWindowPos(h, IntPtr.Zero, x, y, 0, 0, 0x0001 | 0x0004 | 0x0010); }
  // back to the very top of the always-on-top windows, without moving or taking the focus
  public static void KeepOnTop(IntPtr h) { SetWindowPos(h, new IntPtr(-1), 0, 0, 0, 0, 0x0001 | 0x0002 | 0x0010); }

  // which monitor is the main one, in the same order as WorkAreas()
  public static bool[] Primaries() {
    List<bool> list = new List<bool>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (m, hdc, r, d) => {
      MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfo(m, ref mi)) list.Add((mi.dwFlags & 1) != 0);
      return true;
    }, IntPtr.Zero);
    return list.ToArray();
  }

  // stamp a sprite (x, y, color triplets) onto a canvas of ARGB pixels
  public static void Draw(int[] canvas, int w, int h, int[] pts, int ox, int oy) {
    for (int i = 0; i + 2 < pts.Length; i += 3) {
      int x = pts[i] + ox, y = pts[i + 1] + oy;
      if (x >= 0 && x < w && y >= 0 && y < h) canvas[y * w + x] = pts[i + 2];
    }
  }

  // work area (screen minus taskbar) of every monitor
  public static RECT[] WorkAreas() {
    List<RECT> list = new List<RECT>();
    EnumDisplayMonitors(IntPtr.Zero, IntPtr.Zero, (m, hdc, r, d) => {
      MONITORINFO mi = new MONITORINFO(); mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
      if (GetMonitorInfo(m, ref mi)) list.Add(mi.rcWork);
      return true;
    }, IntPtr.Zero);
    return list.ToArray();
  }

}
"@

$PX = 4    # one art pixel = 4 screen pixels (6 = the first, bigger pet, 8 = bigger still)
$GW = 22   # art width, in art pixels
$GH = 17   # art height
$OY = 9    # free rows above the head for the floating code symbols and the thought bubble

$bc = New-Object System.Windows.Media.BrushConverter
function New-Brush($hex) { $b = $bc.ConvertFromString($hex); $b.Freeze(); $b }
$orange = New-Brush '#D97757'
$paw    = New-Brush '#E58A66'   # paws a touch lighter, so they read in front of the laptop
$ink    = New-Brush '#2A1810'
$lidC   = New-Brush '#1C1C1E'
$lidTop = New-Brush '#3A3A3C'
$hingeC = New-Brush '#121214'
$deckC  = New-Brush '#55555A'   # bottom part of the laptop
$keyC   = New-Brush '#55585F'   # keys
$frontC = New-Brush '#3E3E42'   # its front edge
$keyLit = New-Brush '#F2F4FA'   # a key lighting up when pressed
$armC   = New-Brush '#C4623F'   # arms a shade darker than the body
$sideC  = New-Brush '#B85C3F'   # the side of the body, turned a little away from us
$pawFar = New-Brush '#C97A5A'   # the far hand, a little in shadow
$screenC = New-Brush '#16233A'  # screen
$codeA  = New-Brush '#E58052'   # code colours
$codeB  = New-Brush '#F3E6D3'
$codeC  = New-Brush '#8FC4FF'
$logo   = New-Brush '#F2F2F2'
$hit    = New-Brush '#01000000'   # invisible but catches the mouse

function Add-Px($parent, [double]$x, [double]$y, [double]$w, [double]$h, $brush) {
  $r = New-Object System.Windows.Shapes.Rectangle
  $r.Width = $w * $PX; $r.Height = $h * $PX; $r.Fill = $brush
  [System.Windows.Controls.Canvas]::SetLeft($r, $x * $PX)
  [System.Windows.Controls.Canvas]::SetTop($r, ($y + $OY) * $PX)
  [void]$parent.Children.Add($r)
  $r
}
function Set-Top($r, [double]$y) { [System.Windows.Controls.Canvas]::SetTop($r, ($y + $OY) * $PX) }
function Set-Box($r, [double]$y, [double]$h) { Set-Top $r $y; $r.Height = $h * $PX }
function Show-If($el, [bool]$on) { if ($on) { $el.Visibility = 'Visible' } else { $el.Visibility = 'Hidden' } }

# --- window -------------------------------------------------------------
$win = New-Object System.Windows.Window
$win.WindowStyle = 'None'
$win.AllowsTransparency = $true
$win.Background = [System.Windows.Media.Brushes]::Transparent
$win.Topmost = $true
$win.ShowInTaskbar = $false
$win.ResizeMode = 'NoResize'
$win.WindowStartupLocation = 'Manual'
$win.Width = $GW * $PX
$win.Height = ($GH + $OY) * $PX
$win.Left = [System.Windows.SystemParameters]::WorkArea.Right - $win.Width
$win.Top = [System.Windows.SystemParameters]::WorkArea.Bottom - $win.Height
$win.Opacity = 0
$win.Title = 'Claude pet'

$scene = New-Object System.Windows.Controls.Canvas
$scene.Width = $win.Width; $scene.Height = $win.Height
$scene.SnapsToDevicePixels = $true
[System.Windows.Media.RenderOptions]::SetEdgeMode($scene, [System.Windows.Media.EdgeMode]::Aliased)
$flip = New-Object System.Windows.Media.ScaleTransform
$flip.CenterX = $scene.Width / 2
$scene.RenderTransform = $flip   # mirrored while walking to the right
$win.Content = $scene

# --- the art: laid out pixel by pixel after the reference picture ------------------------------------
# laptop in front, lower left; Claude behind it, his right arm coming down to the keyboard on the right
[void](Add-Px $scene 0 0 $GW $GH $hit)

# rows of text -> rectangles; each letter is a colour from $map, '.' is empty
function Add-Art($parent, [int]$x0, [int]$y0, [string[]]$rows, $map) {
  $out = New-Object System.Collections.ArrayList
  for ($j = 0; $j -lt $rows.Count; $j++) {
    $row = $rows[$j]; $i = 0
    while ($i -lt $row.Length) {
      $ch = [string]$row[$i]
      if (-not $map.ContainsKey($ch)) { $i++; continue }
      $k = $i; while ($k -lt $row.Length -and [string]$row[$k] -eq $ch) { $k++ }
      [void]$out.Add((Add-Px $parent ($x0 + $i) ($y0 + $j) ($k - $i) 1 $map[$ch]))
      $i = $k
    }
  }
  , $out.ToArray()
}

# legs: two on the left (hidden behind the laptop while he works), two on the right
$legs = @(
  @((Add-Px $scene 5 11 1 3 $orange), 11),
  @((Add-Px $scene 7 11 1 3 $orange), 11),
  @((Add-Px $scene 16 11 1 3 $orange), 11),
  @((Add-Px $scene 17 11 1 3 $orange), 11)
)

$upper = New-Object System.Windows.Controls.Canvas
$bob = New-Object System.Windows.Media.TranslateTransform
$upper.RenderTransform = $bob
[void]$scene.Children.Add($upper)
[void](Add-Px $upper 4 0 14 11 $orange)   # body, whole down to its lower edge (the laptop hides the lower left part)
$nubL = Add-Px $upper 3 9 1 1 $orange     # a little step on the left, only shown behind the open laptop
$earL = Add-Px $upper 1 6 3 2 $orange     # left ear (it flaps in the wind)
$earR = Add-Px $upper 18 6 3 2 $orange    # right ear (it flaps in the fan's wind on hot days)
$eyeL = Add-Px $upper 6 4 1 2 $ink
$eyeR = Add-Px $upper 15 4 1 2 $ink
$armL = @()

# laptop: lid seen from behind, a little turned, the keyboard part sticking out on the right
$lidMap = @{ G = $lidTop; K = $lidC; W = $logo; B = $lidC; D = $hingeC }
$lidRows = @(
  (Add-Art $scene 0 10 @('GGGGGGGGGG') $lidMap),
  (Add-Art $scene 0 11 @('KKKKKKKKKK') $lidMap),
  (Add-Art $scene 0 12 @('KKKKKKKKKK') $lidMap),
  (Add-Art $scene 0 13 @('KKKKKKKKKKK') $lidMap),
  (Add-Art $scene 0 14 @('.KKKKKKKKKKBBB') $lidMap),
  (Add-Art $scene 0 15 @('.KKKKKKKKKKBB') $lidMap),
  (Add-Art $scene 0 16 @('.DDDDDDDDDDD') $lidMap)
)
$logoDots = foreach ($xy in @(@(3,11), @(2,12), @(3,13), @(6,11), @(7,12), @(6,13))) { Add-Px $scene $xy[0] $xy[1] 1 1 $logo }   # "<>" on the lid
$keyGlow = Add-Px $scene 12 14 1 1 $keyLit

# right arm coming down to the keyboard, hand on the keys
$armMap = @{ A = $orange; S = $armC }
$armR = Add-Art $scene 11 11 @('AAAS', 'AAAS', 'AS') $armMap
$armRTops = foreach ($el in $armR) { [System.Windows.Controls.Canvas]::GetTop($el) }

# sunglasses: two lenses and a bridge across the face; they slide on from his right hand
$shades = New-Object System.Windows.Controls.Canvas
$shades.IsHitTestVisible = $false
$shT = New-Object System.Windows.Media.TranslateTransform
$shades.RenderTransform = $shT
[void]$upper.Children.Add($shades)
$shadeShine = New-Brush '#6A6A72'
foreach ($b in @(@(5, 4, 4, 2), @(13, 4, 4, 2), @(9, 4, 4, 1), @(4, 4, 1, 1), @(17, 4, 1, 1))) { [void](Add-Px $shades $b[0] $b[1] $b[2] $b[3] $lidC) }
foreach ($b in @(@(5, 4), @(13, 4))) { [void](Add-Px $shades $b[0] $b[1] 1 1 $shadeShine) }
$shades.Visibility = 'Hidden'

# his right arm raised to the face, holding the glasses (a shade darker where it passes in front of the body)
$armUp = Add-Art $upper 16 4 @('..HH', '..HH', '..A.', '..A.', '.A..', 'A...') @{ A = $armC; H = $paw }
foreach ($el in $armUp) { $el.Visibility = 'Hidden' }

# a little sparkle on the glasses when he looks at you over them
$sparkle = Add-Art $scene 14 0 @('.W.', 'WWW', '.W.') @{ W = $logo }
foreach ($el in $sparkle) { $el.Visibility = 'Hidden' }

# coffee: a cream mug in his right hand, steam, happy closed eyes while he sips
$creamC = New-Brush '#F4E4C1'; $coffeeC = New-Brush '#4A2C1C'; $tanC = New-Brush '#C9A777'; $steamC = New-Brush '#E9DCC9'; $redC = New-Brush '#E5484D'
# the mug is held in front of his chest, between the eyes; the hand grips it under the handle
$cupArm = Add-Art $upper 17 9 @('A', 'A') @{ A = $armC }   # where the arm leaves the body, stays put when the mug goes up
$mug = New-Object System.Windows.Controls.Canvas
$mug.IsHitTestVisible = $false
$mugT = New-Object System.Windows.Media.TranslateTransform
$mug.RenderTransform = $mugT
[void]$upper.Children.Add($mug)
$mugEdge = New-Brush '#7A4E2C'
[void](Add-Art $mug 9 5 @('OOOOO...', 'OBBBO...', 'OCCCOO..', 'OCCTOHH.', 'OOOOO.A.', '.......A') @{ O = $mugEdge; B = $coffeeC; C = $creamC; T = $tanC; H = $paw; A = $armC })
$steamA = Add-Art $mug 10 2 @('.S.', 'S..') @{ S = $steamC }
$steamB = Add-Art $mug 10 2 @('S..', '.S.') @{ S = $steamC }
$happy = New-Object System.Windows.Controls.Canvas
$happy.IsHitTestVisible = $false
[void]$upper.Children.Add($happy)
foreach ($x in 6, 15) { [void](Add-Art $happy ($x - 1) 4 @('.K.', 'K.K') @{ K = $ink }) }
$heart = Add-Art $scene 15 -4 @('R.R', 'RRR', '.R.') @{ R = $redC }
foreach ($el in @($cupArm) + @($heart)) { $el.Visibility = 'Hidden' }
$mug.Visibility = 'Hidden'; $happy.Visibility = 'Hidden'
# nap: he packs the laptop away, lies down flat and pulls an open book over himself like a little roof
$pageC = $creamC; $pageShade = New-Brush '#E6CF9F'; $coverC = New-Brush '#A8642C'; $coverDark = New-Brush '#7A4E2C'
$napC = New-Object System.Windows.Controls.Canvas
$napC.IsHitTestVisible = $false
[void]$scene.Children.Add($napC)
[void](Add-Px $napC 3 12 16 3 $orange)    # lower half of the flat body, stays put
[void](Add-Px $napC 1 12 2 2 $orange)     # ears, flat on the floor
[void](Add-Px $napC 19 12 2 2 $orange)
foreach ($x in 5, 7, 14, 16) { [void](Add-Px $napC $x 15 1 1 $orange) }   # little feet peeking out
$napTop = New-Object System.Windows.Controls.Canvas
$napTopT = New-Object System.Windows.Media.TranslateTransform
$napTop.RenderTransform = $napTopT
[void]$napC.Children.Add($napTop)
[void](Add-Px $napTop 3 9 16 3 $orange)   # upper half, goes down a pixel when he breathes out
$napShut = @((Add-Px $napTop 6 11 2 1 $ink), (Add-Px $napTop 14 11 2 1 $ink))   # closed eyes
$napOpen = @((Add-Px $napTop 6 10 1 2 $ink), (Add-Px $napTop 15 10 1 2 $ink))   # open eyes: left, right
$book = New-Object System.Windows.Controls.Canvas
$bookT = New-Object System.Windows.Media.TranslateTransform
$book.RenderTransform = $bookT
[void]$napTop.Children.Add($book)
[void](Add-Art $book 1 4 @(
  '.......QPPPPQ.......',
  '....QPPPPSSPPPPQ....',
  '.QPPPPPPPSSPPPPPPPQ.',
  'CCCCCCCCCCCCCCCCCCCC',
  'D..................D') @{ P = $pageC; Q = $pageShade; S = $tanC; C = $coverC; D = $coverDark })
$zSmall = Add-Art $scene 13 0 @('ZZZZ', '..Z.', '.Z..', 'ZZZZ') @{ Z = $orange }
$zBig = Add-Art $scene 17 -5 @('ZZZZZ', '...Z.', '..Z..', '.Z...', 'ZZZZZ') @{ Z = $orange }
$napC.Visibility = 'Hidden'
foreach ($el in @($zSmall) + @($zBig)) { $el.Visibility = 'Hidden' }
# music: he puts the laptop away, big blue headphones go on, eyes closed, he dances on the spot, little notes float up
$navyC = New-Brush '#1E3A75'; $blueC = New-Brush '#3B6FD1'; $skyC = New-Brush '#8DB8F2'; $noteC = New-Brush '#E0A526'
$phones = New-Object System.Windows.Controls.Canvas
$phones.IsHitTestVisible = $false
$phT = New-Object System.Windows.Media.TranslateTransform
$phones.RenderTransform = $phT
[void]$upper.Children.Add($phones)
$phMap = @{ N = $navyC; B = $blueC; L = $skyC; W = $logo }
# the band over his head with the soft white strip under it, and the left ear cup
[void](Add-Art $phones 1 -3 @(
  '......NNNNNNNN......',
  '....NNBBBBBBBBNN....',
  '...NBBWWWWWWWWBBN...',
  '..NBN..........NBN..',
  'NNNN................',
  'NLBN................',
  'NLBN................',
  'NLBN................',
  'NNNN................') $phMap)
# the right ear cup on its own, so he can lift it off his ear when you come by
$phR = New-Object System.Windows.Controls.Canvas
$phRT = New-Object System.Windows.Media.TranslateTransform
$phR.RenderTransform = $phRT
[void]$phones.Children.Add($phR)
[void](Add-Art $phR 17 1 @('NNNN', 'NBLN', 'NBLN', 'NBLN', 'NNNN') $phMap)
$musicEyes = New-Object System.Windows.Controls.Canvas
$musicEyes.IsHitTestVisible = $false
[void]$upper.Children.Add($musicEyes)
[void](Add-Px $musicEyes 6 5 2 1 $ink); [void](Add-Px $musicEyes 14 5 2 1 $ink)
$noteMap = @{ X = $noteC }
$noteA = Add-Art $scene 19 -5 @('.XX', '.X.', 'XX.', 'XX.') $noteMap
$noteB = Add-Art $scene 1 -5 @('.XX', '.X.', 'XX.', 'XX.') $noteMap
$noteDots = @((Add-Px $scene 17 -5 1 1 $noteC), (Add-Px $scene 4 -3 1 1 $noteC))
$phones.Visibility = 'Hidden'; $musicEyes.Visibility = 'Hidden'
foreach ($el in @($noteA) + @($noteB) + @($noteDots)) { $el.Visibility = 'Hidden' }
# daydream: he stops typing, rests his cheek on his right hand, looks up, a thought bubble opens above him
$chinArm = Add-Art $upper 13 6 @('SHH..', 'SHH..', '.SSA.', '....A') @{ A = $armC; S = $armC; H = $paw }
$bubble = New-Object System.Windows.Controls.Canvas
$bubble.IsHitTestVisible = $false
[void]$scene.Children.Add($bubble)
[void](Add-Art $bubble 9 -9 @(
  '...KKKKKKK...',
  '.KKWWWWWWWKK.',
  'KWWWWWWWWWWWK',
  'KWWWWWWWWWWWK',
  'KWWWWWWWWWWWK',
  '.KKWWWWWWWKK.',
  '...KKKKKKK...') @{ K = $ink; W = $logo })
$trail = @((Add-Px $scene 10 -2 1 1 $ink), (Add-Px $scene 8 -1 1 1 $ink))
$thinkDots = foreach ($x in 12, 15, 18) { Add-Px $bubble $x -6 1 1 $orange }
$dream = @((Add-Px $bubble 12 -8 2 2 $orange), (Add-Px $bubble 14 -5 1 1 $orange), (Add-Px $bubble 16 -7 2 2 $orange))
$bubbleHeart = Add-Art $bubble 13 -8 @('RR.RR', 'RRRRR', '.RRR.', '..R..') @{ R = $redC }
foreach ($el in @($chinArm) + @($trail)) { $el.Visibility = 'Hidden' }
$bubble.Visibility = 'Hidden'
# payday: he holds a brown wallet in front of his chest, a green bill slides up out of it, little gold sparkles
$walletC = New-Brush '#7A4A2A'; $walletEdge = New-Brush '#4A2A16'; $goldC = New-Brush '#F2C14E'; $billC = New-Brush '#4CAF50'; $billLight = New-Brush '#A5D6A7'
$payArm = Add-Art $upper 14 8 @('H..', 'HA.', '..A') @{ A = $armC; H = $paw }
$bill = New-Object System.Windows.Controls.Canvas
$billT = New-Object System.Windows.Media.TranslateTransform
$bill.RenderTransform = $billT
[void]$upper.Children.Add($bill)
[void](Add-Art $bill 9 4 @('GGGG', 'GLLG', 'GLLG', 'GGGG') @{ G = $billC; L = $billLight })
$wallet = Add-Art $upper 8 6 @('DDDDDD.', 'DBBBBDD', 'DBBBBYD', 'DDDDDD.') @{ D = $walletEdge; B = $walletC; Y = $goldC }
# little green dollar signs pop up around him instead of sparkles
$dollar = @('.Y.', 'YYY', 'Y..', 'YYY', '..Y', 'YYY', '.Y.')
$spark1 = Add-Art $scene 18 -4 $dollar @{ Y = $billC }
$spark2 = Add-Art $scene 0 -3 $dollar @{ Y = $billC }
$spark3 = Add-Art $scene 13 -9 $dollar @{ Y = $billC }
foreach ($el in @($payArm) + @($wallet) + @($spark1) + @($spark2) + @($spark3)) { $el.Visibility = 'Hidden' }
$bill.Visibility = 'Hidden'
# task done: his right hand raises a pole with a checkered flag (the same raised arm as for the sunglasses), the flag waves
$poleC = New-Brush '#8A8A90'; $flagK = New-Brush '#1C1C1E'
$flagG = New-Object System.Windows.Controls.Canvas
$flagG.IsHitTestVisible = $false
$flagT = New-Object System.Windows.Media.TranslateTransform
$flagG.RenderTransform = $flagT
[void]$upper.Children.Insert(0, $flagG)   # behind the body and the hand
[void](Add-Px $flagG 19 -7 1 13 $poleC)
[void](Add-Px $flagG 19 -8 1 1 $goldC)    # little gold knob on top
$flagMap = @{ K = $flagK; W = $logo }
$flagA = Add-Art $flagG 13 -7 @('KKWWKK', 'KKWWKK', 'WWKKWW', 'WWKKWW') $flagMap
$flagB = Add-Art $flagG 13 -7 @('...WKK', 'KKWWKK', 'KKWKWW', 'WWKKWW', 'WWK...') $flagMap   # the far half dips a pixel: it waves
$confetti = foreach ($c in @(@(3, -3, $redC), @(8, -6, $goldC), @(12, -2, $blueC), @(21, -4, $billC), @(1, 1, $goldC), @(14, -8, $redC))) { Add-Px $scene $c[0] $c[1] 1 1 $c[2] }
foreach ($el in @($flagB) + @($confetti)) { $el.Visibility = 'Hidden' }
$flagG.Visibility = 'Hidden'
# wizard: a tall blue hat with a cream band and gold stars, a wand in his right hand, sparkles at its tip, a wink
$hatC = New-Brush '#2F4C9C'; $hatDark = New-Brush '#1E3270'; $wandC = New-Brush '#5A3A22'
$hat = New-Object System.Windows.Controls.Canvas
$hat.IsHitTestVisible = $false
$hatT = New-Object System.Windows.Media.TranslateTransform
$hat.RenderTransform = $hatT
[void]$upper.Children.Add($hat)
[void](Add-Art $hat 2 -9 @(
  '.....DD...........',
  '......DBB.........',
  '.......BBB........',
  '.......BBBB.......',
  '......BBBBBY......',
  '.....BBBBBBBB.....',
  '....BBBYBBBBBB....',
  '...CCCCCCCCCCCC...',
  'DDDDDDDDDDDDDDDDDD') @{ D = $hatDark; B = $hatC; C = $creamC; Y = $goldC })
# the wand: held in front of his chest, pointing up and out to the right
$wand = Add-Art $upper 14 3 @('......', '.....W', '....W.', '...W..', '..W...', '.W....', 'H.....', 'HA....', '..A...') @{ W = $wandC; H = $paw; A = $armC }
$wandTip = Add-Art $upper 19 1 @('.Y.', 'YYY', '.Y.') @{ Y = $goldC }
$wandSpark1 = @((Add-Px $scene 17 0 1 1 $goldC), (Add-Px $scene 21 4 1 1 $goldC))
$wandSpark2 = @((Add-Px $scene 18 -2 1 1 $goldC), (Add-Px $scene 21 -1 1 1 $goldC), (Add-Px $scene 16 2 1 1 $goldC))
$wink = Add-Px $upper 14 5 2 1 $ink   # right eye shut in a wink
foreach ($el in @($wand) + @($wandTip) + @($wandSpark1) + @($wandSpark2) + @($wink)) { $el.Visibility = 'Hidden' }
$hat.Visibility = 'Hidden'
# detective: a deerstalker with its ear flaps tied on top, a magnifying glass at his right eye (the eye looks big through it),
# the other eye squinting; he hunts for the bug: "?" ... then "!" when he finds it
$tweedC = New-Brush '#7A6E66'; $tweedDark = New-Brush '#5E544D'; $tweedBrim = New-Brush '#4A403A'; $lensC = New-Brush '#CFD8DC'; $ringC = New-Brush '#3A3A3C'
$deer = New-Object System.Windows.Controls.Canvas
$deer.IsHitTestVisible = $false
$deerT = New-Object System.Windows.Media.TranslateTransform
$deer.RenderTransform = $deerT
[void]$upper.Children.Add($deer)
[void](Add-Art $deer 2 -6 @(
  '....KK......KK....',
  '.....K......K.....',
  '....HHHHHHHHHH....',
  '...HHtHHHHtHHHH...',
  '..HHHHHtHHHHHtHH..',
  'DDDDDDDDDDDDDDDDDD',
  'DD..............DD') @{ K = $ink; H = $tweedC; t = $tweedDark; D = $tweedBrim })
# the magnifying glass with its handle, his hand and arm; the big eye inside moves when he looks around
$lens = New-Object System.Windows.Controls.Canvas
$lens.IsHitTestVisible = $false
[void]$upper.Children.Add($lens)
[void](Add-Art $lens 13 2 @('.GGG.', 'GWLLG', 'GLLLG', 'GLLLG', '.GGG.') @{ G = $ringC; L = $lensC; W = $logo })
[void](Add-Art $lens 17 6 @('G..', '.G.', '.HH', 'A..', 'A..') @{ G = $ringC; H = $paw; A = $armC })
$lensEye = Add-Px $lens 15 3 2 2 $ink
$squint = Add-Px $upper 6 5 2 1 $ink   # the other eye squints
$askMark = Add-Art $scene 18 -8 @('KKK', '..K', '.KK', '...', '.K.') @{ K = $orange }
$foundMark = @((Add-Px $scene 20 -8 1 3 $orange), (Add-Px $scene 20 -4 1 1 $orange))
foreach ($el in @($askMark) + @($foundMark) + @($squint)) { $el.Visibility = 'Hidden' }
$deer.Visibility = 'Hidden'; $lens.Visibility = 'Hidden'
# sunbath: laptop away, he pulls out a deck chair, plants a beach umbrella and opens it, lies down with sunglasses and a cocktail
$sunRed = New-Brush '#E5484D'; $sunYellow = New-Brush '#F2C14E'; $woodC = New-Brush '#8A5A33'; $poleC2 = New-Brush '#B0B0B6'
$stripeB = New-Brush '#3B6FD1'; $glassC = New-Brush '#E3F2F7'; $drinkC = New-Brush '#F28C6B'; $strawC = New-Brush '#4CAF50'
# props behind him: the umbrella and the deck chair, each can slide in
$sunProps = New-Object System.Windows.Controls.Canvas
$sunProps.IsHitTestVisible = $false
$scene.Children.Insert(1, $sunProps)
$umb = New-Object System.Windows.Controls.Canvas
$umbT = New-Object System.Windows.Media.TranslateTransform
$umb.RenderTransform = $umbT
[void]$sunProps.Children.Add($umb)
[void](Add-Px $umb 10 -4 1 20 $poleC2)   # the pole, stuck in the ground behind the chair
$umbOpen = Add-Art $umb 4 -9 @(
  '.....YYY.....',
  '...RRYYYRR...',
  '.YYRRYYYRRYY.',
  'YYYRRYYYRRYYY',
  'Y..R..Y..R..Y') @{ R = $sunRed; Y = $sunYellow }
$umbShut = Add-Art $umb 9 -9 @('.Y.', 'RYR', 'RYR', 'RYR', '.R.') @{ R = $sunRed; Y = $sunYellow }
$chair = New-Object System.Windows.Controls.Canvas
$chairT = New-Object System.Windows.Media.TranslateTransform
$chair.RenderTransform = $chairT
$chairLayer = New-Object System.Windows.Controls.Canvas
$chairLayer.IsHitTestVisible = $false
[void]$scene.Children.Add($chairLayer)
[void]$chairLayer.Children.Add($chair)
[void](Add-Art $chair 1 6 @(
  '.BW................',
  '.WB................',
  '..BW...............',
  '..WB...............',
  '...BW..............',
  '...WBWBWBWBWBWBWBW.',
  '...O.............O.',
  '...O.............O.',
  '..O...............O') @{ B = $stripeB; W = $logo; O = $woodC })
# him lying back on the chair: wide flat body, ears out to the sides, little feet hanging over the end
$sunBody = New-Object System.Windows.Controls.Canvas
$sunBody.IsHitTestVisible = $false
[void]$scene.Children.Add($sunBody)
$sunBody.RenderTransform = New-Object System.Windows.Media.TranslateTransform(0, (-1 * $PX))   # a pixel up, so the striped seat shows under him
[void](Add-Px $sunBody 5 7 14 5 $orange)
[void](Add-Px $sunBody 3 9 2 2 $orange); [void](Add-Px $sunBody 19 9 2 2 $orange)
[void](Add-Px $sunBody 16 12 1 2 $orange); [void](Add-Px $sunBody 18 12 1 2 $orange)
$sunShades = New-Object System.Windows.Controls.Canvas
$sunShadesT = New-Object System.Windows.Media.TranslateTransform
$sunShades.RenderTransform = $sunShadesT
[void]$sunBody.Children.Add($sunShades)
[void](Add-Art $sunShades 7 8 @('LLLBBBLLL', 'LLL...LLL') @{ L = $lidC; B = $lidC })
[void](Add-Px $sunShades 7 8 1 1 (New-Brush '#6A6A72')); [void](Add-Px $sunShades 13 8 1 1 (New-Brush '#6A6A72'))
$sunEyes = @((Add-Px $sunBody 8 8 1 1 $ink), (Add-Px $sunBody 14 8 1 1 $ink))   # peeking over the glasses
$cocktail = New-Object System.Windows.Controls.Canvas
$cocktailT = New-Object System.Windows.Media.TranslateTransform
$cocktail.RenderTransform = $cocktailT
[void]$sunBody.Children.Add($cocktail)
[void](Add-Art $cocktail 15 1 @('....S', '.Y.S.', 'GPPPG', 'GPPPG', '.GGG.', '...HH') @{ S = $strawC; Y = $sunYellow; G = $glassC; P = $drinkC; H = $paw })
[void](Add-Px $sunBody 18 7 1 1 $armC)
$sunHeart = Add-Art $scene 15 -5 @('RR.RR', 'RRRRR', '.RRR.', '..R..') @{ R = $sunRed }
foreach ($el in @($umbOpen) + @($sunEyes) + @($sunHeart)) { $el.Visibility = 'Hidden' }
$sunProps.Visibility = 'Hidden'; $sunBody.Visibility = 'Hidden'; $chairLayer.Visibility = 'Hidden'
# bug hunt: a green bug crawls along the top of the laptop lid, he slams a glass jar over it,
# lifts the jar (now right side up with a lid, the bug inside) to look at it, a green tick: fixed
$bugC = New-Brush '#3E8E41'; $bugLight = New-Brush '#8BD18F'; $jarEdge = New-Brush '#BFE3F0'
$bugMap = @{ G = $bugC; L = $bugLight; K = $ink }
$bugG = New-Object System.Windows.Controls.Canvas
$bugG.IsHitTestVisible = $false
$bugT = New-Object System.Windows.Media.TranslateTransform
$bugG.RenderTransform = $bugT
[void]$scene.Children.Add($bugG)
$bugA = Add-Art $bugG 0 7 @('.GLG.K', 'GGGGKK', 'K.K.K.') $bugMap
$bugB = Add-Art $bugG 0 7 @('.GLGK.', 'GGGGKK', '.K.K.K') $bugMap   # legs and antenna move: it crawls
# the jar coming down over the bug, his hand holding it from the right side
$jarDown = New-Object System.Windows.Controls.Canvas
$jarDown.IsHitTestVisible = $false
$jarDownT = New-Object System.Windows.Media.TranslateTransform
$jarDown.RenderTransform = $jarDownT
[void]$scene.Children.Add($jarDown)
[void](Add-Art $jarDown 3 6 @(
  'GGGGGGGG...',
  'GW.....GHH.',
  'G......GHH.',
  'G......G.A.',
  '..........A') @{ G = $jarEdge; W = $logo; H = $paw; A = $armC })
# the jar held up above his head, right side up with a grey lid, the bug inside; he looks up at it
$jarUp = New-Object System.Windows.Controls.Canvas
$jarUp.IsHitTestVisible = $false
[void]$upper.Children.Add($jarUp)
[void](Add-Art $jarUp 9 -5 @(
  '.LLLLLL...',
  'GGGGGGGG..',
  'GW.....G..',
  'G......GHH',
  'G......GHH',
  'GGGGGGGG.A') @{ G = $jarEdge; W = $logo; L = $poleC2; H = $paw; A = $armC })
[void](Add-Art $jarUp 10 -3 @('.GLG.K', 'GGGGKK', 'K.K.K.') $bugMap)
[void](Add-Px $jarUp 18 1 1 8 $armC)   # the arm down his right side
$tick = Add-Art $scene 17 -9 @('....G', '...G.', 'G.G..', '.G...') @{ G = $billC }
foreach ($el in @($bugB) + @($tick)) { $el.Visibility = 'Hidden' }
$bugG.Visibility = 'Hidden'; $jarDown.Visibility = 'Hidden'; $jarUp.Visibility = 'Hidden'
# lunch: a croissant in his right hand in front of his chest, three bites, crumbs fall onto the laptop
$crustC = New-Brush '#D9A55B'; $crustDark = New-Brush '#A8692E'; $crumbC = New-Brush '#E8C07A'
$lunch = New-Object System.Windows.Controls.Canvas
$lunch.IsHitTestVisible = $false
$lunchT = New-Object System.Windows.Media.TranslateTransform
$lunch.RenderTransform = $lunchT
[void]$upper.Children.Add($lunch)
$crustMap = @{ L = $crustC; D = $crustDark; O = (New-Brush '#5A3212'); Y = (New-Brush '#F2CF8A') }   # outlined, so it reads on his orange body
# a wide arch, thick in the middle with dark lines between the rolls, the two thin ends hanging down
$bite0 = Add-Art $lunch 5 5 @('....OOOO....', '..OOYYYYOO..', '.OLDLLLLDLO.', 'OLDOOOOOODLO', 'OLO......OLO', '.O........O.') $crustMap
$bite1 = Add-Art $lunch 5 5 @('....OOOO....', '....OYYYOO..', '....ODLLDLO.', '....OOOOODLO', '.........OLO', '..........O.') $crustMap
$bite2 = Add-Art $lunch 5 5 @('............', '.......OOO..', '.......ODLO.', '.......OODLO', '.........OLO', '..........O.') $crustMap
[void](Add-Art $lunch 16 8 @('HH', 'HH', '.A') @{ H = $paw; A = $armC })
# lunch at half past twelve: a sandwich instead, crust, bread, lettuce, tomato, cheese, bread; bitten from the left
$sandMap = @{ O = (New-Brush '#8A5A2B'); B = $creamC; G = (New-Brush '#5DBB63'); R = $redC; Y = $goldC }
$sand0 = Add-Art $lunch 8 4 @('.OOOOOO.', 'OBBBBBBO', 'GGGGGGGG', 'RRRRRRRR', 'YYYYYYYY', 'OBBBBBBO', '.OOOOOO.') $sandMap
$sand1 = Add-Art $lunch 8 4 @('...OOOO.', '..OBBBBO', '...GGGGG', '..RRRRRR', '...YYYYY', '..OBBBBO', '...OOOO.') $sandMap
$sand2 = Add-Art $lunch 8 4 @('........', '.....OOO', '....OBBO', '.....GGG', '....RRRR', '....OBBO', '.....OOO') $sandMap
$crumbsFall = @((Add-Px $scene 9 10 1 1 $crumbC), (Add-Px $scene 11 11 1 1 $crumbC), (Add-Px $scene 10 12 1 1 $crumbC))
$crumbsDown = @((Add-Px $scene 8 9 1 1 $crumbC), (Add-Px $scene 12 13 1 1 $crumbC), (Add-Px $scene 13 14 1 1 $crumbC))
foreach ($el in @($bite1) + @($bite2) + @($sand0) + @($sand1) + @($sand2) + @($crumbsFall) + @($crumbsDown)) { $el.Visibility = 'Hidden' }
$lunch.Visibility = 'Hidden'
# after eating: he looks around for a broom ("?"), sweeps the crumbs off the laptop, a little puff of dust
$broom = New-Object System.Windows.Controls.Canvas
$broom.IsHitTestVisible = $false
$broomT = New-Object System.Windows.Media.TranslateTransform
$broom.RenderTransform = $broomT
[void]$scene.Children.Add($broom)
[void](Add-Art $broom 8 5 @(
  '.........W',
  '........W.',
  '.......HH.',
  '......WHH.',
  '.....W..A.',
  '....W....A',
  '..RRR.....',
  '.YYYYY....',
  'YYDYDYY...') @{ W = (New-Brush '#4A2A16'); H = $paw; A = $armC; R = $redC; Y = $sunYellow; D = $crustDark })   # a dark handle, so it reads on his orange body
$dustC = New-Brush '#A9A39A'
$puff = @((Add-Px $scene 15 13 1 1 $dustC), (Add-Px $scene 17 12 1 1 $dustC), (Add-Px $scene 16 14 1 1 $dustC), (Add-Px $scene 18 14 1 1 $dustC))
foreach ($el in $puff) { $el.Visibility = 'Hidden' }
$broom.Visibility = 'Hidden'
# rain: drops start falling on him, one splashes on his head, he pulls out a blue umbrella and opens it over himself and the laptop
$rainC = New-Brush '#7FB2E5'; $umbC = New-Brush '#2E5AAC'; $umbLight = New-Brush '#5B86D9'; $umbEdge = New-Brush '#1E3E7A'; $shaftC = New-Brush '#8A8A90'
$rainSpots = @(@(2, -8), @(7, -5), @(12, -9), @(17, -7), @(20, -2), @(0, 1), @(5, -1), @(14, -3), @(19, 5), @(1, 7), @(9, 3), @(16, 1))
# two frames of falling drops, all over him (before the umbrella) ...
$rainA = foreach ($p in $rainSpots) { Add-Px $scene $p[0] $p[1] 1 2 $rainC }
$rainB = foreach ($p in $rainSpots) { Add-Px $scene $p[0] ($p[1] + 3) 1 2 $rainC }
# ... and only above and beside the open umbrella
$rainTopA = foreach ($p in @(@(3, -9), @(9, -9), @(15, -9), @(0, -3), @(21, 0), @(0, 4), @(21, 6))) { Add-Px $scene $p[0] $p[1] 1 2 $rainC }
$rainTopB = foreach ($p in @(@(6, -9), @(12, -9), @(18, -9), @(21, -4), @(0, 0), @(21, 2), @(0, 7))) { Add-Px $scene $p[0] $p[1] 1 2 $rainC }
$splash = Add-Art $upper 8 -2 @('R...R', '.R.R.') @{ R = $rainC }   # a drop splashing on his head
$rainUmb = New-Object System.Windows.Controls.Canvas
$rainUmb.IsHitTestVisible = $false
[void]$upper.Children.Add($rainUmb)
$umbMap = @{ D = $umbEdge; B = $umbC; L = $umbLight; S = $shaftC; H = $paw; A = $armC }
# closed, half open and open canopies; the shaft runs down in front of him to his right hand
$umbClosed = Add-Art $rainUmb 10 -4 @('.D.', '.D.', 'DBD', 'DBD', 'DBD', 'DBD', 'DLD', '.S.', '.S.', '.S.') $umbMap
$umbHalf = Add-Art $rainUmb 7 -5 @('...DD...', '..DBBD..', '.DBBLBD.', 'DBBBLBBD', 'D.D..D.D', '....S...', '....S...', '....S...', '....S...', '....S...', '....S...') $umbMap
$umbFull = Add-Art $rainUmb 1 -8 @(
  '.........DD.........',
  '.......DDBBDD.......',
  '....DDBBBLLBBBDD....',
  '..DDBBBBBLLBBBBBDD..',
  '.DBBLBBBBLLBBBBLBBD.',
  'DBBBLBBBBLLBBBBLBBBD',
  'DD.DDD.DDDDDD.DDD.DD') $umbMap
$umbShaft = Add-Px $rainUmb 11 -1 1 7 $shaftC
[void](Add-Art $rainUmb 11 6 @('HH..', 'HH..', '..A.', '...A', '....A') $umbMap)
foreach ($el in @($rainA) + @($rainB) + @($rainTopA) + @($rainTopB) + @($splash) + @($umbClosed) + @($umbHalf) + @($umbFull) + @($umbShaft)) { $el.Visibility = 'Hidden' }
$rainUmb.Visibility = 'Hidden'
# popcorn: when Claude Code works on a long task he sets a striped bucket on the laptop lid and watches, taking one piece at a time
$popRed = New-Brush '#E5484D'; $popWhite = $logo; $popC = New-Brush '#FFF4D6'; $popY = New-Brush '#F2C14E'
$popG = New-Object System.Windows.Controls.Canvas
$popG.IsHitTestVisible = $false
$popT = New-Object System.Windows.Media.TranslateTransform
$popG.RenderTransform = $popT
[void]$scene.Children.Add($popG)
[void](Add-Art $popG 1 3 @('.C.Y..', 'CYCCYC', 'YCYCCY', 'RWRWRW', 'RWRWRW', 'RWRWRW', '.WRWR.') @{ C = $popC; Y = $popY; R = $popRed; W = $popWhite })
# his right hand: down in the bucket, or up at his mouth with a piece
$popReach = Add-Art $scene 7 4 @('HH.....', 'HHA....', '...A...', '....A..', '.....A.', '......A') @{ H = $paw; A = $armC }
$popEat = Add-Art $scene 9 6 @('C...', 'HH..', 'HHA.', '...A', '....A') @{ H = $paw; A = $armC; C = $popC }
foreach ($el in @($popReach) + @($popEat)) { $el.Visibility = 'Hidden' }
$popG.Visibility = 'Hidden'
# newspaper: a watched job of yours is running (newsLock in settings.json): he opens the paper, reads left and right, a green tick
$paperC = $logo; $foldC = New-Brush '#C9C9C9'; $printC = New-Brush '#9A9A9A'; $picC = New-Brush '#5B86D9'
$paper = New-Object System.Windows.Controls.Canvas
$paper.IsHitTestVisible = $false
$paperT = New-Object System.Windows.Media.TranslateTransform
$paper.RenderTransform = $paperT
[void]$scene.Children.Add($paper)
[void](Add-Art $paper 3 6 @(
  '.WWWWWWWFWWWWWW.',
  'HWKKKKKWFWBBBBWH',
  'HWWWWWWWFWBBBBWH',
  '.WGGGGGWFWBBBBW.',
  '.WWWWWWWFWWWWWW.',
  '.WGGGGWWFWGGGGW.',
  '.WWWWWWWFWWWWWW.') @{ W = $paperC; F = $foldC; K = $ink; G = $printC; B = $picC; H = $paw })
$paper.Visibility = 'Hidden'
# the closed laptop put down on the floor beside him while he reads
$laptopAside = Add-Art $scene 0 13 @('GGGGGGGG', 'KKKWKKKK', 'DDDDDDDD') @{ G = $lidTop; K = $lidC; W = $logo; D = $hingeC }
foreach ($el in $laptopAside) { $el.Visibility = 'Hidden' }
# the closed laptop carried under his arm (the ear bump on top holds it), when he leaves and when he comes back
$laptopTuck = Add-Art $upper 0 8 @('GGGGGGGG', 'KKKWKKKK', 'DDDDDDDD') @{ G = $lidTop; K = $lidC; W = $logo; D = $hingeC }
foreach ($el in $laptopTuck) { $el.Visibility = 'Hidden' }
# weather looks, each shown while that weather is on:
# snow: white flakes and a red bobble hat; wind: leaves and streaks blowing past; clouds: a grey cloud drifting over him;
# heat: a sun in the corner and a drop of sweat (with the sunglasses); storm: a dark cloud with a lightning bolt (and the rain)
$snowC = $logo; $hatRed = New-Brush '#D6453D'; $leafA = New-Brush '#D98A2B'; $leafB = New-Brush '#A8692E'; $windC = New-Brush '#BFC5CC'
$cloudC = New-Brush '#C3C8CF'; $cloudDark = New-Brush '#6E7580'; $boltC = New-Brush '#F2C14E'; $sweatC = New-Brush '#7FB2E5'
$snowSpots = @(@(1, -8), @(6, -6), @(11, -9), @(16, -7), @(20, -4), @(0, -1), @(19, 2), @(2, 4), @(21, 7), @(8, -3), @(14, -2))
$flakeC = New-Brush '#BFD4EE'   # pale blue, so the flakes show on a white page too
$snowA = foreach ($p in $snowSpots) { Add-Px $scene $p[0] $p[1] 1 1 $flakeC }
$snowB = foreach ($p in $snowSpots) { Add-Px $scene ($p[0] + 1) ($p[1] + 2) 1 1 $flakeC }
$beanie = Add-Art $upper 4 -4 @('......WW......', '.....WWWW.....', '...RRRRRRRR...', '..RRRRRRRRRR..', 'WWWWWWWWWWWWWW') @{ R = $hatRed; W = $snowC }
$windA = @((Add-Art $scene 0 -6 @('SSSS....', '....SSS.') @{ S = $windC }), (Add-Art $scene 15 -3 @('LL', '.L') @{ L = $leafA }), (Add-Art $scene 2 3 @('L.', 'LL') @{ L = $leafB }), (Add-Art $scene 12 -8 @('SSSSS') @{ S = $windC }))
$windB = @((Add-Art $scene 3 -5 @('SSSS....', '....SSS.') @{ S = $windC }), (Add-Art $scene 19 -1 @('LL', '.L') @{ L = $leafA }), (Add-Art $scene 6 2 @('L.', 'LL') @{ L = $leafB }), (Add-Art $scene 15 -7 @('SSSSS') @{ S = $windC }))
$cloud = New-Object System.Windows.Controls.Canvas
$cloud.IsHitTestVisible = $false
$cloudT = New-Object System.Windows.Media.TranslateTransform
$cloud.RenderTransform = $cloudT
[void]$scene.Children.Add($cloud)
$cloudLight = Add-Art $cloud 6 -8 @('...CCC....', '.CCCCCCC..', 'CCCCCCCCCC', '.CCCCCCCC.') @{ C = $cloudC }
$cloudStorm = Add-Art $cloud 6 -8 @('...DDD....', '.DDDDDDD..', 'DDDDDDDDDD', '.DDDDDDDD.') @{ D = $cloudDark }
$bolt = Add-Art $scene 10 -4 @('.YY', 'YY.', '.YY', 'YY.') @{ Y = $boltC }
$sun = Add-Art $scene 17 -9 @('Y.Y.Y', '.YYY.', 'YYYYY', '.YYY.', 'Y.Y.Y') @{ Y = $boltC }
$sweat = Add-Art $upper 18 0 @('.S', 'SS') @{ S = $sweatC }
# the snow scene: a striped teal scarf, snow piling up on the lid and the ears, a tongue out for a flake, a little snowman beside him
$scarfC = New-Brush '#2E9C8F'; $tongueC = New-Brush '#E8738A'; $carrotC = New-Brush '#F28A2E'
$beanieT = New-Object System.Windows.Media.TranslateTransform
foreach ($el in $beanie) { $el.RenderTransform = $beanieT }
$scarf = Add-Art $upper 4 8 @('SSWSSWSSWSSWSS', '..........SS..', '..........SW..', '..........SS..') @{ S = $scarfC; W = $snowC }
$pile1 = @((Add-Px $scene 0 9 10 1 $snowC), (Add-Px $upper 1 5 3 1 $snowC), (Add-Px $upper 18 5 3 1 $snowC))
$pile2 = @((Add-Px $scene 1 8 7 1 $snowC), (Add-Px $upper 2 4 1 1 $snowC), (Add-Px $upper 19 4 1 1 $snowC))
$tongue = Add-Px $upper 10 7 2 1 $tongueC
$flakeTongue = Add-Px $upper 10 5 1 1 $snowC
# the snowman stands on the floor right of his feet; a blue-grey outline so he shows on a white screen too
$snowLine = New-Brush '#8FA3B8'
$snowman1 = Add-Art $scene 17 12 @('.GGG.', 'GWWWG', 'GWWWG', '.GGG.') @{ W = $snowC; G = $snowLine }
$snowman2 = Add-Art $scene 18 9 @('.G.', 'GWG', 'GWG') @{ W = $snowC; G = $snowLine }
$snowman3 = @((Add-Px $scene 19 10 1 1 $ink), (Add-Px $scene 20 10 2 1 $carrotC))
$buildHand = Add-Art $upper 16 5 @('A...', '.A..', '..HH', '..HH') @{ A = $armC; H = $paw }
# when the snow stops: he shakes the snow off (bits fly from his ears and the lid), the snowman melts into a puddle
$puddleC = New-Brush '#9CC7EE'
$shakeA = foreach ($p in @(@(0, 4), @(2, 2), @(21, 3), @(19, 1), @(3, 7), @(11, 7))) { Add-Px $scene $p[0] $p[1] 1 1 $flakeC }
$shakeB = foreach ($p in @(@(1, 3), @(0, 1), @(20, 4), @(21, 1), @(5, 6), @(9, 6))) { Add-Px $scene $p[0] $p[1] 1 1 $flakeC }
$melt1 = Add-Art $scene 17 13 @('.GGG.', 'GWWWG', '.PPP.') @{ W = $snowC; G = $snowLine; P = $puddleC }
$melt2 = Add-Art $scene 16 15 @('.GWG..', 'PPPPPP') @{ W = $snowC; G = $snowLine; P = $puddleC }
$puddle = Add-Art $scene 16 16 @('PPPPPP') @{ P = $puddleC }
foreach ($el in @($scarf) + @($pile1) + @($pile2) + @($tongue) + @($flakeTongue) + @($snowman1) + @($snowman2) + @($snowman3) + @($buildHand) + @($shakeA) + @($shakeB) + @($melt1) + @($melt2) + @($puddle)) { $el.Visibility = 'Hidden' }
foreach ($el in @($snowA) + @($snowB) + @($beanie) + @($windA) + @($windB) + @($cloudLight) + @($cloudStorm) + @($bolt) + @($sun) + @($sweat)) { foreach ($e in @($el)) { $e.Visibility = 'Hidden' } }
$cloud.Visibility = 'Hidden'
# the heat scene: the sun's rays pulse, a fan on the floor at his right blows at him (blades turn, his ear flaps, wind lines),
# an ice cream in his right hand, a pink drip. The fan's blades are a strong blue, so it reads as a fan and not as an eye
$fanFrame = $shaftC; $bladeC = New-Brush '#3B82C4'; $creamPink = New-Brush '#F2A7C3'; $coneC = New-Brush '#D9A55B'; $coneDark = New-Brush '#A8692E'
$sunRays = Add-Art $scene 16 -9 @('Y.....Y', '.......', '.......', '.......', 'Y.....Y') @{ Y = $boltC }
$fan = New-Object System.Windows.Controls.Canvas
$fan.IsHitTestVisible = $false
$fanT = New-Object System.Windows.Media.TranslateTransform
$fan.RenderTransform = $fanT
[void]$scene.Children.Add($fan)
[void](Add-Art $fan 17 9 @('.GGG.', 'G...G', 'G.G.G', 'G...G', '.GGG.', '..G..', '..G..', '.GGG.') @{ G = $fanFrame })   # a grey hub: a dark one looked like a pupil
$bladesA = Add-Art $fan 18 10 @('B.B', '...', 'B.B') @{ B = $bladeC }
$bladesB = Add-Art $fan 18 10 @('.B.', 'B.B', '.B.') @{ B = $bladeC }
$windLines = @((Add-Art $scene 13 10 @('SSS') @{ S = $windC }), (Add-Art $scene 14 12 @('SS') @{ S = $windC }))
$iceCream = Add-Art $upper 11 3 @('.WW..', 'PPPP.', 'PPPP.', 'CDCD.', '.DC..', '.HH..', '.HHA.', '....A') @{ W = $creamC; P = $creamPink; C = $coneC; D = $coneDark; H = $paw; A = $armC }
$iceHalf = Add-Art $upper 11 3 @('.....', '.PP..', 'PPPP.', 'CDCD.', '.DC..', '.HH..', '.HHA.', '....A') @{ P = $creamPink; C = $coneC; D = $coneDark; H = $paw; A = $armC }
$drip = Add-Px $scene 12 11 1 1 $creamPink
foreach ($el in @($sunRays) + @($bladesB) + @($windLines) + @($iceCream) + @($iceHalf) + @($drip)) { foreach ($e in @($el)) { $e.Visibility = 'Hidden' } }
$fan.Visibility = 'Hidden'
# the cloudy scene: a fluffy cloud drifts over him, stops a while, then drifts on (Katya: no heart, it's good as a cloud)
$puffW = $logo; $puffL = New-Brush '#D5DAE0'; $puffG = New-Brush '#AEB6C0'
$sky = New-Object System.Windows.Controls.Canvas
$sky.IsHitTestVisible = $false
$skyT = New-Object System.Windows.Media.TranslateTransform
$sky.RenderTransform = $skyT
[void]$scene.Children.Add($sky)
$puffMap = @{ W = $puffW; L = $puffL; G = $puffG }
$puffCloud = Add-Art $sky 6 -8 @('...LLL....', '.LLWWWLL..', 'LWWWWWWWLL', 'LWWWWWWWWL', '.GGGGGGGG.') $puffMap
$sky.Visibility = 'Hidden'
# the fog scene: see-through grey bands drift past in front of him, he squints, wipes the laptop with a cloth,
# switches on a little lamp on the floor at his right; when the fog lifts the bands thin out and the lamp goes off.
# The mist is a mid grey, see-through, so it shows on white pages and on dark ones
$mistC = New-Brush '#A3AAB4'; $lampShade = New-Brush '#2E7D5B'; $bulbOff = New-Brush '#8A8A90'; $glowC = New-Brush '#FFE9A8'
$mist = New-Object System.Windows.Controls.Canvas
$mist.IsHitTestVisible = $false
$mistT = New-Object System.Windows.Media.TranslateTransform
$mist.RenderTransform = $mistT
[void]$scene.Children.Add($mist)
$mistThick = foreach ($b in @(@(-6, -6, 14), @(4, -2, 12), @(-4, 2, 16), @(6, 6, 13), @(-2, 10, 15))) { $r = Add-Px $mist $b[0] $b[1] $b[2] 2 $mistC; $r.Opacity = 0.55; $r }   # bands two pixels thick
$mistThin = foreach ($b in @(@(-2, -3, 9), @(8, 4, 8))) { $r = Add-Px $mist $b[0] $b[1] $b[2] 1 $mistC; $r.Opacity = 0.45; $r }
$cloth = New-Object System.Windows.Controls.Canvas
$cloth.IsHitTestVisible = $false
$clothT = New-Object System.Windows.Media.TranslateTransform
$cloth.RenderTransform = $clothT
[void]$scene.Children.Add($cloth)
[void](Add-Art $cloth 5 8 @('WWW......', 'WWWHH....', '...HHA...', '......A..', '.......A.') @{ W = $logo; H = $paw; A = $armC })
$lamp = New-Object System.Windows.Controls.Canvas
$lamp.IsHitTestVisible = $false
$lampT = New-Object System.Windows.Media.TranslateTransform
$lamp.RenderTransform = $lampT
[void]$scene.Children.Add($lamp)
[void](Add-Art $lamp 17 9 @('.SSS.', 'SSSSS', '.....', '..P..', '..P..', '..P..', '.PPP.') @{ S = $lampShade; P = $shaftC })
$bulbDark = Add-Art $lamp 18 11 @('BBB') @{ B = $bulbOff }
$bulbLit = Add-Art $lamp 18 11 @('YYY') @{ Y = $boltC }
$lampGlow = Add-Art $lamp 15 11 @('G.....G', '.G...G.', 'G.....G') @{ G = $glowC }
foreach ($el in @($bulbLit) + @($lampGlow)) { $el.Visibility = 'Hidden' }
$mist.Visibility = 'Hidden'; $cloth.Visibility = 'Hidden'; $lamp.Visibility = 'Hidden'
# the drizzle scene: fine dots fall, one lands on his face, he pulls a yellow raincoat hood over his head,
# drops sit on the hood, a little puddle grows at his feet (the snow scene's puddle)
$hoodC = New-Brush '#F2C14E'
$hoodDark = New-Brush '#C99A2E'
$drizSpots = @(@(1, -8), @(4, -5), @(8, -9), @(11, -6), @(15, -8), @(19, -5), @(21, -2), @(0, -2), @(3, 2), @(20, 3), @(13, -3), @(7, -2), @(17, 0), @(2, 7), @(21, 8))
$drizA = foreach ($p in $drizSpots) { Add-Px $scene $p[0] $p[1] 1 1 $rainC }
$drizB = foreach ($p in $drizSpots) { Add-Px $scene $p[0] ($p[1] + 2) 1 1 $rainC }
$faceDrop = @((Add-Px $upper 9 3 1 1 $rainC), (Add-Px $upper 8 2 1 1 $rainC), (Add-Px $upper 10 2 1 1 $rainC))
# the raincoat outfit, put on piece by piece: a folded bundle in his hand, the coat (yellow body with a seam and buttons,
# the side bumps become sleeves), the hood with a dark edge round his face, yellow boots on his feet
$coatMap = @{ Y = $hoodC; D = $hoodDark; K = $ink }
$bundle = Add-Art $upper 12 6 @('YYYY..', 'DDDD..', 'YYYYHH', '....HH', '.....A') @{ Y = $hoodC; D = $hoodDark; H = $paw; A = $armC }
$coat = New-Object System.Windows.Controls.Canvas
$coat.IsHitTestVisible = $false
$coatT = New-Object System.Windows.Media.TranslateTransform
$coat.RenderTransform = $coatT
[void]$upper.Children.Add($coat)
[void](Add-Art $coat 1 6 @(
  'YYYYYYYYYYYYYYYYYYYY',
  'YYYYYYYYYKYYYYYYYYYY',
  '...YYYYYYDYYYYYYY...',
  '...YYYYYYKYYYYYYY...',
  '...YYYYYYDYYYYYYY...') $coatMap)
$hood = New-Object System.Windows.Controls.Canvas
$hood.IsHitTestVisible = $false
$hoodT = New-Object System.Windows.Media.TranslateTransform
$hood.RenderTransform = $hoodT
[void]$upper.Children.Add($hood)
[void](Add-Art $hood 1 -2 @(
  '......YYYYYYYY......',
  '....YYYYYYYYYYYY....',
  '...YYYYYYYYYYYYYY...',
  '...YDDDDDDDDDDDDY...',
  '...Y............Y...',
  '...Y............Y...',
  '...Y............Y...',
  '...Y............Y...') $coatMap)   # only a brim on top and thin sides: a frame all round looked like a diving mask
$hoodBeads = foreach ($p in @(@(6, -1), @(11, -2), @(15, 0))) { Add-Px $hood $p[0] $p[1] 1 1 $logo }
$boots = foreach ($x in 16, 17) { Add-Px $scene $x 12 1 2 $hoodC }   # only the feet you see: the left ones are behind the laptop
foreach ($el in @($drizA) + @($drizB) + @($faceDrop) + @($bundle) + @($hoodBeads) + @($boots)) { $el.Visibility = 'Hidden' }
$coat.Visibility = 'Hidden'; $hood.Visibility = 'Hidden'
# more life in the rain: a puddle grows at his feet with rings from the drops; when it stops he jumps in it in his boots, splash
$rainPudSmall = Add-Art $scene 15 16 @('PPPPP') @{ P = $puddleC }
$rainPudBig = Add-Art $scene 13 15 @('..PPPPPP.', 'PPPPPPPPP') @{ P = $puddleC }
$ringA = Add-Art $scene 14 14 @('R.....R..') @{ R = $rainC }
$ringB = Add-Art $scene 14 14 @('...R....R') @{ R = $rainC }
$jumpSplash = Add-Art $scene 12 12 @('R.......R', '.R..R..R.', '..R...R..') @{ R = $rainC }
foreach ($el in @($rainPudSmall) + @($rainPudBig) + @($ringA) + @($ringB) + @($jumpSplash)) { $el.Visibility = 'Hidden' }
# the storm scene: the dark cloud and the bolt (from the weather looks), heavy rain, and a white flash over the whole window
# when the lightning strikes; he jumps, then hides behind the laptop and peeks over it
$flash = Add-Px $scene 0 (-$OY) $GW ($GH + $OY) $logo
$flash.Opacity = 0.7; $flash.IsHitTestVisible = $false; $flash.Visibility = 'Hidden'
# the wind scene: gusts and leaves blow past from the right, both ears flap,
# a rose is snatched out of his hand, a leaf sticks on his face and he peels it off; when the wind drops, the last leaf lands on the lid and he flicks it away
$gustA = foreach ($s in @(@(14, -7, 6), @(2, -4, 5), @(16, 1, 5), @(0, 4, 4), @(10, 9, 4))) { Add-Px $scene $s[0] $s[1] $s[2] 1 $windC }
$gustB = foreach ($s in @(@(9, -6, 6), @(-2, -3, 5), @(11, 2, 5), @(17, 5, 4), @(5, 9, 4))) { Add-Px $scene $s[0] $s[1] $s[2] 1 $windC }
# green leaves: orange-brown ones disappeared on his orange body
$leafMap = @{ L = (New-Brush '#6BAF4E'); D = (New-Brush '#3E7D2E') }
$leavesA = @((Add-Art $scene 18 -5 @('LL', 'DL') $leafMap), (Add-Art $scene 6 -8 @('.L', 'LD') $leafMap), (Add-Art $scene 20 6 @('LD', '.L') $leafMap))
$leavesB = @((Add-Art $scene 13 -4 @('LD', '.L') $leafMap), (Add-Art $scene 1 -7 @('LL', 'DL') $leafMap), (Add-Art $scene 15 7 @('.L', 'LD') $leafMap))
$flyPaper = New-Object System.Windows.Controls.Canvas
$flyPaper.IsHitTestVisible = $false
$flyPaperT = New-Object System.Windows.Media.TranslateTransform
$flyPaper.RenderTransform = $flyPaperT
[void]$scene.Children.Add($flyPaper)
# the rose he smells (Katya: a rose, not a sheet of paper); the wind takes it, a few petals trail behind
[void](Add-Art $flyPaper 3 6 @('.RR.', 'RDRR', '.RR.', '..G.', '..GL', '..G.') @{ R = $redC; D = (New-Brush '#A8232A'); G = (New-Brush '#3E7D2E'); L = (New-Brush '#6BAF4E') })
$petals = foreach ($p in @(@(9, -2), @(12, 0), @(14, -3))) { Add-Px $scene $p[0] $p[1] 1 1 $redC }
# the hand holding the rose by its stem, before the wind takes it
$paperHand = Add-Art $upper 12 9 @('HH.', 'HHA', '..A') @{ H = $paw; A = $armC }
$faceLeaf = Add-Art $upper 13 3 @('.LL', 'LDL', 'LL.') $leafMap
$handLeaf = Add-Art $upper 19 1 @('.LL', 'LDL', 'LL.') $leafMap
$lidLeaf = Add-Art $scene 4 8 @('LL', 'DL') $leafMap
foreach ($el in @($gustA) + @($gustB) + @($faceLeaf) + @($handLeaf) + @($lidLeaf) + @($paperHand) + @($petals)) { foreach ($e in @($el)) { $e.Visibility = 'Hidden' } }
foreach ($g in @($leavesA) + @($leavesB)) { foreach ($e in $g) { $e.Visibility = 'Hidden' } }
$flyPaper.Visibility = 'Hidden'
# the cold scene: frost on the laptop lid, he shivers with puffs of breath, wraps the scarf (from the snow scene),
# drinks hot tea from a red mug with a tea-bag tag, rosy cheeks once he's warm; when it warms up the frost drips away
$frostC = New-Brush '#CFE3F5'
$frost = foreach ($p in @(@(0, 11), @(1, 11), @(0, 12), @(2, 11), @(8, 11), @(9, 11), @(9, 12), @(1, 15), @(0, 14), @(10, 15))) { Add-Px $scene $p[0] $p[1] 1 1 $frostC }
$frostDrip = foreach ($p in @(@(1, 12), @(9, 13))) { Add-Px $scene $p[0] $p[1] 1 1 $rainC }
$breathC = New-Brush '#DDE5EE'
# puffs of breath rise beside him, against the background (on his face they looked like a smudge)
$breathLine = New-Brush '#AEB6C0'
$breathA = Add-Art $upper 0 2 @('.GG', 'GBG', '.G.') @{ B = $breathC; G = $breathLine }
$breathB = Add-Art $upper 0 -2 @('.GGG', 'GBBG', 'GBG.', '.G..') @{ B = $breathC; G = $breathLine }
$teaMap = @{ O = (New-Brush '#7A2430'); B = (New-Brush '#9C5A1E'); C = (New-Brush '#C8414F'); W = $logo; Y = $boltC; H = $paw; A = $armC }
$tea = New-Object System.Windows.Controls.Canvas
$tea.IsHitTestVisible = $false
$teaT = New-Object System.Windows.Media.TranslateTransform
$tea.RenderTransform = $teaT
[void]$upper.Children.Add($tea)
[void](Add-Art $tea 9 5 @('OOOOO...', 'OBBBOW..', 'OCCCOYY.', 'OCCCOHH.', 'OOOOO.A.', '.......A') $teaMap)
$teaSteamA = Add-Art $tea 10 2 @('.S.', 'S..', '.S.') @{ S = $steamC }
$teaSteamB = Add-Art $tea 10 2 @('S..', '.S.', 'S..') @{ S = $steamC }
$cheeks = @((Add-Px $upper 5 6 2 1 $creamPink), (Add-Px $upper 15 6 2 1 $creamPink))
foreach ($el in @($frost) + @($frostDrip) + @($breathA) + @($breathB) + @($teaSteamA) + @($teaSteamB) + @($cheeks)) { $el.Visibility = 'Hidden' }
$tea.Visibility = 'Hidden'
# "!" when you catch him
$bang = New-Object System.Windows.Controls.Canvas
$bang.IsHitTestVisible = $false
[void]$scene.Children.Add($bang)
[void](Add-Px $bang 19 -4 1 3 $orange)
[void](Add-Px $bang 19 0 1 1 $orange)

# --- helpers --------------------------------------------------------------
function Set-Eyes([int]$dx, [int]$y, [bool]$blink) {
  $h = 2; $yy = $y
  if ($blink) { $h = 1; $yy = $y + 1 }
  foreach ($e in @(@($eyeL, 6), @($eyeR, 15))) {
    $e[0].Height = $h * $PX
    [System.Windows.Controls.Canvas]::SetLeft($e[0], ($e[1] + $dx) * $PX)
    Set-Top $e[0] $yy
  }
}
# $l = left arm lifted, $r = right arm lifted; the key under the right hand lights up when it comes down
function Set-Paws([int]$l, [int]$r, [bool]$pressL, [bool]$pressR) {

  for ($i = 0; $i -lt $armR.Count; $i++) { [System.Windows.Controls.Canvas]::SetTop($armR[$i], $armRTops[$i] - $r * $PX) }
  $keyGlow.Visibility = 'Hidden'   # no key flash: only the arm moves
}
function Set-Legs([int]$phase) {
  for ($i = 0; $i -lt $legs.Count; $i++) {
    $lift = 0
    if ($phase -ge 0 -and ($i % 2) -eq $phase) { $lift = 1 }
    Set-Top $legs[$i][0] ($legs[$i][1] - $lift)
  }
}
function Scroll-Code([int]$n) { }
# sunglasses on or off; $dx / $dy move them (slid down = 2, held in the hand = 3, 0)
function Set-Shades([bool]$on, [int]$dx, [int]$dy) { Show-If $shades $on; $shT.X = $dx * $PX; $shT.Y = $dy * $PX }
# the right arm up at the face instead of on the keyboard
function Set-ArmUp([bool]$on) {
  foreach ($el in $armUp) { Show-If $el $on }
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
}
# the right arm up holding the mug; $dx / $dy move the mug (a sip = 0 -1, cheers = 0 -2)
function Set-Cup([bool]$on, [int]$dx, [int]$dy) {
  foreach ($el in $cupArm) { Show-If $el $on }
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
  Show-If $mug $on; $mugT.X = $dx * $PX; $mugT.Y = $dy * $PX
}
function Set-Steam([int]$n) {
  foreach ($el in $steamA) { Show-If $el ($n % 2 -eq 0) }
  foreach ($el in $steamB) { Show-If $el ($n % 2 -eq 1) }
}
# happy closed eyes instead of the normal ones
function Set-Happy([bool]$on) { Show-If $happy $on; Show-If $eyeL (-not $on); Show-If $eyeR (-not $on) }
function Set-Heart([bool]$on) { foreach ($el in $heart) { Show-If $el $on } }
# nap art instead of the normal one (the laptop is already put away)
function Set-Nap([bool]$on) {
  Show-If $napC $on; Show-If $upper (-not $on)
  foreach ($lg in $legs) { Show-If $lg[0] (-not $on) }
}
# $dy moves the book up (negative) when it lands or when he peeks out from under it
function Set-Book([bool]$on, [int]$dy) { Show-If $book $on; $bookT.Y = $dy * $PX }
function Set-Breath([int]$out) { $napTopT.Y = $out * $PX }
# 0 = asleep, 1 = one eye open, 2 = both open
function Set-NapEyes([int]$mode) {
  Show-If $napShut[1] ($mode -eq 0); Show-If $napShut[0] ($mode -lt 2)
  Show-If $napOpen[0] ($mode -eq 2); Show-If $napOpen[1] ($mode -ge 1)
}
# z's above him: 0 none, 1 small, 2 small and big, 3 big
function Set-Zz([int]$phase) {
  foreach ($el in $zSmall) { Show-If $el ($phase -eq 1 -or $phase -eq 2) }
  foreach ($el in $zBig) { Show-If $el ($phase -ge 2) }
}# headphones on or off; $dy brings them down from above when he puts them on
function Set-Phones([bool]$on, [int]$dy) { Show-If $phones $on; $phT.Y = $dy * $PX }
# the right cup lifted off his ear (when you come by)
function Set-CupLift([bool]$up) { if ($up) { $phRT.X = $PX; $phRT.Y = -2 * $PX } else { $phRT.X = 0; $phRT.Y = 0 } }
# eyes closed, enjoying the music
function Set-MusicEyes([bool]$on) { Show-If $musicEyes $on; Show-If $eyeL (-not $on); Show-If $eyeR (-not $on) }
# notes: 0 none, 1-2 a note on the right, 3-4 a note on the left, dots on 2 and 4
function Set-Notes([int]$p) {
  foreach ($el in $noteA) { Show-If $el ($p -eq 1 -or $p -eq 2) }
  foreach ($el in $noteB) { Show-If $el ($p -eq 3 -or $p -eq 4) }
  Show-If $noteDots[0] ($p -eq 2); Show-If $noteDots[1] ($p -eq 4)
}# cheek on his hand instead of the hand on the keyboard
function Set-Chin([bool]$on) {
  foreach ($el in $chinArm) { Show-If $el $on }
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
}
# the bubble: 0 hidden, 1 only the little trail dot, 2 bubble; $dots = how many thinking dots, $what = 'dots', 'dream' or 'heart'
function Set-Bubble([int]$stage, [int]$dots, [string]$what) {
  foreach ($el in $trail) { Show-If $el ($stage -ge 1) }; Show-If $bubble ($stage -ge 2)
  for ($i = 0; $i -lt 3; $i++) { Show-If $thinkDots[$i] ($what -eq 'dots' -and $i -lt $dots) }
  foreach ($el in $dream) { Show-If $el ($what -eq 'dream') }
  foreach ($el in $bubbleHeart) { Show-If $el ($what -eq 'heart') }
}# the wallet in his right hand instead of the hand on the keyboard; $billUp: 2 = inside, 0 = peeking out, -2 = pulled up
function Set-Wallet([bool]$on, [int]$billUp) {
  foreach ($el in @($payArm) + @($wallet)) { Show-If $el $on }
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
  Show-If $bill $on; $billT.Y = $billUp * $PX
}
# sparkles: 0 none, 1 and 2 take turns, 3 all of them
function Set-PaySpark([int]$n) {
  foreach ($el in $spark1) { Show-If $el ($n -eq 1 -or $n -eq 3) }
  foreach ($el in $spark2) { Show-If $el ($n -eq 2 -or $n -eq 3) }
  foreach ($el in $spark3) { Show-If $el ($n -eq 3) }
}# the flag up in his right hand; $dy lowers it while he raises it, $wave picks the flag shape
function Set-Flag([bool]$on, [int]$dy, [int]$wave) {
  Show-If $flagG $on; $flagT.Y = $dy * $PX
  foreach ($el in $flagA) { Show-If $el ($wave % 2 -eq 0) }
  foreach ($el in $flagB) { Show-If $el ($wave % 2 -eq 1) }
}
function Set-Confetti([bool]$on) { foreach ($el in $confetti) { Show-If $el $on } }# the wizard hat; $dy brings it down from above when he puts it on
function Set-Hat([bool]$on, [int]$dy) { Show-If $hat $on; $hatT.Y = $dy * $PX }
# the wand in his right hand instead of the hand on the keyboard; $spark: 0 none, 1 and 2 take turns, 3 all
function Set-Wand([bool]$on, [int]$spark) {
  foreach ($el in $wand) { Show-If $el $on }
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
  foreach ($el in $wandTip) { Show-If $el ($on -and $spark -gt 0) }
  foreach ($el in $wandSpark1) { Show-If $el ($on -and ($spark -eq 1 -or $spark -eq 3)) }
  foreach ($el in $wandSpark2) { Show-If $el ($on -and $spark -ge 2) }
}
# the wink sits on the bottom row of the right eye, wherever the eye is looking at that moment
function Set-Wink([bool]$on) {
  $ex = [System.Windows.Controls.Canvas]::GetLeft($eyeR) / $PX
  $ey = [System.Windows.Controls.Canvas]::GetTop($eyeR) / $PX - $OY + $eyeR.Height / $PX - 1
  [System.Windows.Controls.Canvas]::SetLeft($wink, ($ex - 1) * $PX); Set-Top $wink $ey
  Show-If $wink $on; Show-If $eyeR (-not $on)
}
# the deerstalker; $dy brings it down from above
function Set-Deer([bool]$on, [int]$dy) { Show-If $deer $on; $deerT.Y = $dy * $PX }
# the magnifying glass at his right eye instead of the hand on the keyboard; $ex / $ey move the big eye inside the lens
function Set-Lens([bool]$on, [int]$ex, [int]$ey) {
  Show-If $lens $on; Show-If $squint $on; Show-If $eyeL (-not $on); Show-If $eyeR (-not $on)
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
  [System.Windows.Controls.Canvas]::SetLeft($lensEye, (15 + $ex) * $PX); Set-Top $lensEye (3 + $ey)
}
# "?" while he searches, "!" when he finds it
function Set-Clue([string]$m) {
  foreach ($el in $askMark) { Show-If $el ($m -eq '?') }
  foreach ($el in $foundMark) { Show-If $el ($m -eq '!') }
}# the deck chair and umbrella: $chairDx slides the chair in from the left, $umbDy pushes the pole up out of the ground
function Set-SunProps([bool]$on, [int]$chairDx, [int]$umbDy, [bool]$open) {
  Show-If $sunProps ($on -and $umbDy -lt 14); Show-If $chairLayer $on   # the umbrella only once its top is above the ground
  $chairT.X = $chairDx * $PX; $umbT.Y = $umbDy * $PX
  foreach ($el in $umbOpen) { Show-If $el $open }
  foreach ($el in $umbShut) { Show-If $el (-not $open) }
}
# him lying on the chair instead of standing; $sip moves the glass to his face, $peek lowers the glasses
function Set-SunBody([bool]$on, [int]$sip, [bool]$peek) {
  Show-If $sunBody $on; Show-If $upper (-not $on)
  foreach ($lg in $legs) { Show-If $lg[0] (-not $on) }
  $cocktailT.X = -3 * $sip * $PX; $cocktailT.Y = 2 * $sip * $PX
  $sunShadesT.Y = [int]$peek * $PX
  foreach ($el in $sunEyes) { Show-If $el $peek }
}
# the bug on the lid; $x moves it along, $step picks the leg frame
function Set-Bug([bool]$on, [int]$x, [int]$step) {
  Show-If $bugG $on; $bugT.X = $x * $PX
  foreach ($el in $bugA) { Show-If $el ($step % 2 -eq 0) }
  foreach ($el in $bugB) { Show-If $el ($step % 2 -eq 1) }
}
# the jar in his right hand instead of the hand on the keyboard: 'down' over the bug ($dy lifts it), 'up' held to look at it
function Set-Jar([string]$mode, [int]$dy) {
  Show-If $jarDown ($mode -eq 'down'); $jarDownT.Y = $dy * $PX
  Show-If $jarUp ($mode -eq 'up')
  foreach ($el in $armR) { Show-If $el ($mode -eq '' -and $S.lv -ge 4) }
}
# the croissant (or the sandwich) in his right hand instead of the hand on the keyboard
# $bites 0..2 eaten so far, 3 = all gone; $dy lifts it to his mouth
function Set-Lunch([bool]$on, [int]$bites, [int]$dy, [string]$food = 'croissant') {
  Show-If $lunch ($on -and $bites -lt 3); $lunchT.Y = $dy * $PX
  $cr = $food -eq 'croissant'
  foreach ($el in $bite0) { Show-If $el ($cr -and $bites -eq 0) }
  foreach ($el in $bite1) { Show-If $el ($cr -and $bites -eq 1) }
  foreach ($el in $bite2) { Show-If $el ($cr -and $bites -eq 2) }
  foreach ($el in $sand0) { Show-If $el ((-not $cr) -and $bites -eq 0) }
  foreach ($el in $sand1) { Show-If $el ((-not $cr) -and $bites -eq 1) }
  foreach ($el in $sand2) { Show-If $el ((-not $cr) -and $bites -eq 2) }
  foreach ($el in $armR) { Show-If $el ((-not ($on -and $bites -lt 3)) -and $S.lv -ge 4) }
}
# crumbs: 0 none, 1 falling, 2 lying on the laptop, 3 only the last one left (half swept)
function Set-Crumbs([int]$n) {
  foreach ($el in $crumbsFall) { Show-If $el ($n -eq 1) }
  for ($i = 0; $i -lt $crumbsDown.Count; $i++) { Show-If $crumbsDown[$i] ($n -eq 2 -or ($n -eq 3 -and $i -eq 2)) }
}
# the broom in his right hand instead of the hand on the keyboard; $dx sweeps it left and right, $dy lifts it
function Set-Broom([bool]$on, [int]$dx, [int]$dy) {
  Show-If $broom $on; $broomT.X = $dx * $PX; $broomT.Y = $dy * $PX
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
}
# rain: 0 none, 1 all over him, 2 only above and beside the open umbrella; $frame makes it fall
function Set-Rain([int]$mode, [int]$frame) {
  $b = $frame % 2 -eq 1
  foreach ($el in $rainA) { Show-If $el ($mode -eq 1 -and -not $b) }
  foreach ($el in $rainB) { Show-If $el ($mode -eq 1 -and $b) }
  foreach ($el in $rainTopA) { Show-If $el ($mode -eq 2 -and -not $b) }
  foreach ($el in $rainTopB) { Show-If $el ($mode -eq 2 -and $b) }
}
function Set-Splash([bool]$on) { foreach ($el in $splash) { Show-If $el $on } }
# the umbrella in his right hand instead of the hand on the keyboard: 0 none, 1 closed, 2 half open, 3 open
function Set-RainUmb([int]$open) {
  Show-If $rainUmb ($open -gt 0)
  foreach ($el in $umbClosed) { Show-If $el ($open -eq 1) }
  foreach ($el in $umbHalf) { Show-If $el ($open -eq 2) }
  foreach ($el in $umbFull) { Show-If $el ($open -eq 3) }
  Show-If $umbShaft ($open -eq 3)
  foreach ($el in $armR) { Show-If $el ($open -eq 0 -and $S.lv -ge 4) }
}
# the popcorn bucket on the lid; $hand: 0 none (hand on the keyboard), 1 in the bucket, 2 at his mouth; $dy lifts it in
function Set-Popcorn([bool]$on, [int]$hand, [int]$dy) {
  Show-If $popG $on; $popT.Y = $dy * $PX
  foreach ($el in $popReach) { Show-If $el ($on -and $hand -eq 1) }
  foreach ($el in $popEat) { Show-If $el ($on -and $hand -eq 2) }
  foreach ($el in $armR) { Show-If $el ((-not ($on -and $hand -gt 0)) -and $S.lv -ge 4) }
}
# the newspaper held up in front of him; $dy lowers it (raises it in from below)
function Set-Paper([bool]$on, [int]$dy) {
  Show-If $paper $on; $paperT.Y = $dy * $PX
  foreach ($el in $armR) { Show-If $el ((-not $on) -and $S.lv -ge 4) }
}
function Set-LaptopAside([bool]$on) { foreach ($el in $laptopAside) { Show-If $el $on } }
function Set-LaptopTuck([bool]$on) { foreach ($el in $laptopTuck) { Show-If $el $on } }
# the weather look: '' none, 'snow', 'wind', 'cloud', 'heat', 'storm'; $frame moves flakes, leaves and the cloud
function Set-Weather([string]$w, [int]$frame) {
  $b = $frame % 2 -eq 1
  foreach ($el in $snowA) { Show-If $el ($w -eq 'snow' -and -not $b) }
  foreach ($el in $snowB) { Show-If $el ($w -eq 'snow' -and $b) }
  foreach ($el in $beanie) { Show-If $el ($w -eq 'snow') }
  foreach ($g in $windA) { foreach ($el in $g) { Show-If $el ($w -eq 'wind' -and -not $b) } }
  foreach ($g in $windB) { foreach ($el in $g) { Show-If $el ($w -eq 'wind' -and $b) } }
  Show-If $cloud ($w -eq 'cloud' -or $w -eq 'storm'); $cloudT.X = ($frame % 3 - 1) * $PX
  foreach ($el in $cloudLight) { Show-If $el ($w -eq 'cloud') }
  foreach ($el in $cloudStorm) { Show-If $el ($w -eq 'storm') }
  foreach ($el in $bolt) { Show-If $el ($w -eq 'storm' -and $b) }
  foreach ($el in $sun) { Show-If $el ($w -eq 'heat') }
  foreach ($el in $sweat) { Show-If $el ($w -eq 'heat' -and -not $b) }
}
# the snow scene, piece by piece: falling flakes ($frame), the hat ($hatDy brings it down; 99 = off), the scarf,
# how much snow lies on the lid and the ears ($pile 0..2), the tongue out for a flake, the snowman ($man 0..3), the building hand
function Set-Snow([bool]$falling, [int]$frame, [int]$hatDy, [bool]$scarfOn, [int]$pile, [bool]$tongueOut, [int]$man, [bool]$building) {
  $b = $frame % 2 -eq 1
  foreach ($el in $snowA) { Show-If $el ($falling -and -not $b) }
  foreach ($el in $snowB) { Show-If $el ($falling -and $b) }
  foreach ($el in $beanie) { Show-If $el ($hatDy -ne 99) }; $beanieT.Y = $hatDy * $PX
  foreach ($el in $scarf) { Show-If $el $scarfOn }
  foreach ($el in $pile1) { Show-If $el ($pile -ge 1) }
  foreach ($el in $pile2) { Show-If $el ($pile -ge 2) }
  Show-If $tongue $tongueOut; Show-If $flakeTongue $tongueOut
  foreach ($el in $snowman1) { Show-If $el ($man -ge 1) }
  foreach ($el in $snowman2) { Show-If $el ($man -ge 2) }
  foreach ($el in $snowman3) { Show-If $el ($man -ge 3) }
  foreach ($el in $buildHand) { Show-If $el $building }
  foreach ($el in $armR) { Show-If $el ((-not $building) -and $S.lv -ge 4) }
}
# after the snow: $shake 0 none, 1 and 2 = snow flying off him (he wiggles left and right); $melt 1 half melted, 2 a lump in a puddle, 3 only the puddle
function Set-SnowEnd([int]$shake, [int]$melt) {
  foreach ($el in $shakeA) { Show-If $el ($shake -eq 1) }
  foreach ($el in $shakeB) { Show-If $el ($shake -eq 2) }
  $bob.X = @(0, -1, 1)[$shake] * $PX
  foreach ($el in $melt1) { Show-If $el ($melt -eq 1) }
  foreach ($el in $melt2) { Show-If $el ($melt -eq 2) }
  foreach ($el in $puddle) { Show-If $el ($melt -eq 3) }
}
# the heat scene: $sunOn with pulsing rays ($frame), the sweat drop, the fan ($fanDx slides it in from the right, 99 = away;
# $spinning turns the blades, flaps his ear and shows wind lines), the ice cream ($ice 0 none, 1 whole, 2 half), a drip
function Set-Heat([bool]$sunOn, [int]$frame, [bool]$sweating, [int]$fanDx, [bool]$spinning, [int]$ice, [bool]$dripping) {
  $b = $frame % 2 -eq 1
  foreach ($el in $sun) { Show-If $el $sunOn }
  foreach ($el in $sunRays) { Show-If $el ($sunOn -and $b) }
  foreach ($el in $sweat) { Show-If $el $sweating }
  Show-If $fan ($fanDx -ne 99); $fanT.X = $fanDx * $PX
  foreach ($el in $bladesA) { Show-If $el (-not ($spinning -and $b)) }
  foreach ($el in $bladesB) { Show-If $el ($spinning -and $b) }
  foreach ($g in $windLines) { foreach ($el in $g) { Show-If $el ($spinning -and -not $b) } }
  if ($spinning -and $b) { Set-Top $earR 5 } else { Set-Top $earR 6 }
  foreach ($el in $iceCream) { Show-If $el ($ice -eq 1) }
  foreach ($el in $iceHalf) { Show-If $el ($ice -eq 2) }
  Show-If $drip $dripping
  foreach ($el in $armR) { Show-If $el ($ice -eq 0 -and $S.lv -ge 4) }
}
# the cloud of the cloudy scene: $dx moves it across (0 = right above him, 99 = gone)
function Set-Sky([int]$dx) { Show-If $sky ($dx -ne 99); $skyT.X = $dx * $PX }
# the fog scene: $thick 0 none, 1 thin (lifting), 2 thick; $drift moves the bands; $wipe: 99 no cloth, else its offset;
# $lampDx: 99 no lamp, else it slides in from the right; $lit switches it on
function Set-Fog([int]$thick, [int]$drift, [int]$wipe, [int]$lampDx, [bool]$lit) {
  Show-If $mist ($thick -gt 0); $mistT.X = $drift * $PX
  foreach ($el in $mistThick) { Show-If $el ($thick -eq 2) }
  foreach ($el in $mistThin) { Show-If $el ($thick -ge 1) }
  Show-If $cloth ($wipe -ne 99); $clothT.X = $wipe * $PX
  Show-If $lamp ($lampDx -ne 99); $lampT.X = $lampDx * $PX
  foreach ($el in $bulbDark) { Show-If $el (-not $lit) }
  foreach ($el in $bulbLit) { Show-If $el $lit }
  foreach ($el in $lampGlow) { Show-If $el $lit }
  foreach ($el in $armR) { Show-If $el ($wipe -eq 99 -and $S.lv -ge 4) }
}
# the drizzle scene: $falling dots ($frame), a drop splashing on his face, drops on the hood, the puddle at his feet
function Set-Drizzle([bool]$falling, [int]$frame, [bool]$faceSplash, [bool]$beads, [bool]$puddleOn) {
  $b = $frame % 2 -eq 1
  foreach ($el in $drizA) { Show-If $el ($falling -and -not $b) }
  foreach ($el in $drizB) { Show-If $el ($falling -and $b) }
  foreach ($el in $faceDrop) { Show-If $el $faceSplash }
  foreach ($el in $hoodBeads) { Show-If $el $beads }
  foreach ($el in $puddle) { Show-If $el $puddleOn }
}
# the raincoat: the folded bundle in his hand, the coat ($coatDy pulls it up from below; 99 = off), the hood ($hoodDy; 99 = off), the boots
function Set-Raincoat([bool]$bundleOn, [int]$coatDy, [int]$hoodDy, [bool]$bootsOn) {
  foreach ($el in $bundle) { Show-If $el $bundleOn }
  foreach ($el in $armR) { Show-If $el ((-not $bundleOn) -and $S.lv -ge 4) }
  Show-If $coat ($coatDy -ne 99); $coatT.Y = $coatDy * $PX
  Show-If $hood ($hoodDy -ne 99); $hoodT.Y = $hoodDy * $PX
  foreach ($el in $boots) { Show-If $el $bootsOn }
}
# the rain puddle: $size 0 none, 1 small, 2 big; $ring 0 none, 1 or 2 = the drop rings take turns; $jump lifts him and splashes
function Set-RainPuddle([int]$size, [int]$ring, [bool]$jump) {
  foreach ($el in $rainPudSmall) { Show-If $el ($size -eq 1) }
  foreach ($el in $rainPudBig) { Show-If $el ($size -eq 2) }
  foreach ($el in $ringA) { Show-If $el ($ring -eq 1) }
  foreach ($el in $ringB) { Show-If $el ($ring -eq 2) }
  foreach ($el in $jumpSplash) { Show-If $el $jump }
  if ($jump) { $bob.Y = -2 * $PX; foreach ($lg in $legs) { Set-Top $lg[0] ($lg[1] - 2) } } else { $bob.Y = 0; Set-Legs -1 }
  foreach ($el in $boots) { if ($jump) { Set-Top $el 10 } else { Set-Top $el 12 } }   # the boots go up with his feet
}
# the storm: $cloudDx moves the dark cloud (99 = gone), $boltOn, $flashOn; $duck lowers him behind the laptop (0 up, 4 hidden), $jump lifts him
function Set-Storm([int]$cloudDx, [bool]$boltOn, [bool]$flashOn, [int]$duck, [int]$jump) {
  Show-If $cloud ($cloudDx -ne 99); $cloudT.X = $cloudDx * $PX
  foreach ($el in $cloudLight) { Show-If $el $false }
  foreach ($el in $cloudStorm) { Show-If $el ($cloudDx -ne 99) }
  foreach ($el in $bolt) { Show-If $el $boltOn }
  Show-If $flash $flashOn
  $bob.Y = ($duck - $jump) * $PX
}
# the wind: $blowing gusts and leaves ($frame), his ears flap and he leans into it ($lean);
# $paper: 'held' = he holds a rose, 'snatch' / 'away' = the wind takes it (petals trail), 'gone' (anything else) = no rose;
# the leaf on his face, the leaf in his hand (raised arm), the leaf landed on the lid
function Set-Wind([bool]$blowing, [int]$frame, [int]$lean, [string]$paper, [bool]$onFace, [bool]$inHand, [bool]$onLid) {
  $paperDx = 99; $paperDy = 0
  if ($paper -eq 'held') { $paperDx = 7; $paperDy = -2 } elseif ($paper -eq 'snatch') { $paperDx = 3; $paperDy = -6 } elseif ($paper -eq 'away') { $paperDx = -3; $paperDy = -12 }
  $b = $frame % 2 -eq 1
  foreach ($el in $gustA) { Show-If $el ($blowing -and -not $b) }
  foreach ($el in $gustB) { Show-If $el ($blowing -and $b) }
  foreach ($g in $leavesA) { foreach ($el in $g) { Show-If $el ($blowing -and -not $b) } }
  foreach ($g in $leavesB) { foreach ($el in $g) { Show-If $el ($blowing -and $b) } }
  if ($blowing -and $b) { Set-Top $earL 5; Set-Top $earR 5 } else { Set-Top $earL 6; Set-Top $earR 6 }
  $bob.X = $lean * $PX
  Show-If $flyPaper ($paperDx -ne 99); $flyPaperT.X = $paperDx * $PX; $flyPaperT.Y = $paperDy * $PX
  foreach ($el in $paperHand) { Show-If $el ($paper -eq 'held') }
  foreach ($el in $petals) { Show-If $el ($paper -eq 'away') }
  foreach ($el in $faceLeaf) { Show-If $el $onFace }
  foreach ($el in $handLeaf) { Show-If $el $inHand }
  Set-ArmUp ($inHand -or $paper -eq 'snatch' -or $paper -eq 'away')   # holds the leaf up, or reaches after the rose
  if ($paper -eq 'held') { foreach ($el in $armR) { Show-If $el $false } }
  foreach ($el in $lidLeaf) { Show-If $el $onLid }
}
# the cold: frost on the lid ($frost 0 none, 1 on, 2 melting), $shiver -1/0/1 shakes him, $breath 0/1/2 puffs,
# the scarf, the tea mug ($teaDy lifts it to sip, 99 = none) with steam ($frame), rosy cheeks
function Set-Cold([int]$frostOn, [int]$shiver, [int]$breath, [bool]$scarfOn, [int]$teaDy, [int]$frame, [bool]$rosy) {
  foreach ($el in $frost) { Show-If $el ($frostOn -eq 1) }
  foreach ($el in $frostDrip) { Show-If $el ($frostOn -eq 2) }
  $bob.X = $shiver * $PX
  foreach ($el in $breathA) { Show-If $el ($breath -eq 1) }
  foreach ($el in $breathB) { Show-If $el ($breath -eq 2) }
  foreach ($el in $scarf) { Show-If $el $scarfOn }
  Show-If $tea ($teaDy -ne 99); $teaT.Y = $teaDy * $PX
  foreach ($el in $teaSteamA) { Show-If $el ($frame % 2 -eq 0) }
  foreach ($el in $teaSteamB) { Show-If $el ($frame % 2 -eq 1) }
  foreach ($el in $armR) { Show-If $el ($teaDy -eq 99 -and $S.lv -ge 4) }
  foreach ($el in $cheeks) { Show-If $el $rosy }
}
function Set-Puff([bool]$on) { foreach ($el in $puff) { Show-If $el $on } }
function Set-Tick([bool]$on) { foreach ($el in $tick) { Show-If $el $on } }
function Set-SunHeart([bool]$on) { foreach ($el in $sunHeart) { Show-If $el $on } }function Set-Sparkle([bool]$on) { foreach ($el in $sparkle) { Show-If $el $on } }
# eyes hidden behind the glasses, shown when they slide down
function Show-Eyes([bool]$on) { Show-If $eyeL $on; Show-If $eyeR $on }
# 0 = laptop put away, then it comes back from the bottom row up; 4 = open
function Set-Laptop([int]$lv) {
  $show = @(0, 2, 4, 6, 7)[$lv]   # how many lid rows, counted from the bottom
  for ($i = 0; $i -lt $lidRows.Count; $i++) {
    $on = ($lidRows.Count - $i) -le $show
    foreach ($el in $lidRows[$i]) { Show-If $el $on }
  }
  foreach ($el in @($armR) + @($nubL) + @($logoDots)) { Show-If $el ($lv -ge 4) }   # logo only on the open lid
  if ($lv -lt 4) { $keyGlow.Visibility = 'Hidden' }
}

$glyphs = '{', '}', ';', '<', '/', '>', '(', ')', '=', '0', '1', '*', '#'
$floaters = New-Object System.Collections.ArrayList
$mono = New-Object System.Windows.Media.FontFamily 'Consolas'
function Add-Glyph {
  $tb = New-Object System.Windows.Controls.TextBlock
  $tb.Text = Get-Random -InputObject $glyphs
  $tb.FontFamily = $mono
  $tb.FontWeight = [System.Windows.FontWeights]::Bold
  $tb.FontSize = 2 * $PX
  $tb.Foreground = $orange
  $tb.IsHitTestVisible = $false
  [System.Windows.Controls.Canvas]::SetLeft($tb, (Get-Random -Minimum 3 -Maximum 12) * $PX)
  [void]$scene.Children.Add($tb)
  [void]$floaters.Add(@{ el = $tb; y = [double](($OY - 2) * $PX); life = 0 })
}
function Rand([int]$a, [int]$b) { Get-Random -Minimum $a -Maximum ($b + 1) }
$MIN = [int](60000 / 70)   # timer ticks in one minute

# --- state ------------------------------------------------------------------
# all window positions are in real screen pixels, the same units Windows uses for other windows
$S = @{
  state = 'hidden'; greet = $false; byeT = 0; byeWave = 0; fresh = $true; t = 0; hover = $false; dx = 0
  blink = 0; blinkIn = 40; glance = 0; glanceDx = 0; nextGlance = 90
  burst = 30; pause = 0; scroll = 0
  cool = $false; coolT = 0; nextCool = (Rand (4 * $MIN) (8 * $MIN)); shadeStep = 0; shadeDir = 1
  cup = 0; nextCup = (Rand (4 * $MIN) (8 * $MIN)); wantCup = $false
  dream = 0; nextDream = (Rand (10 * $MIN) (20 * $MIN))
  pay = 0; nextPay = (Rand (4 * $MIN) (8 * $MIN))
  flag = 0; flagWant = $false; doneSeen = [long]0; lastFlag = -100000
  wizPhase = ''; wizT = 0; wizLen = 0; nextWiz = (Rand 4500 7000); spell = 0; nextSpell = 0; wantWiz = $false
  det = 0; nextDet = (Rand (10 * $MIN) (20 * $MIN))
  bug = 0; nextBug = (Rand (10 * $MIN) (20 * $MIN))
  calm = 0; wasPosing = $false
  hot = $false; wxJob = $null; wxNext = 0; wxSeen = $false
  payAt = 0; payDone = $true; wizAt = 0; wizDone = $true; sunAt = 0; sunDone = $true
  act = ''; actK = 0; wx = ''; ambWas = ''; nextWep = 0; newsRunning = $false; newsWant = $false; busySince = [long]0; popAt = 0
  eat = 0; food = 'croissant'; mealDay = ''; croissantAt = 0; sandwichAt = 0; croissantDone = $false; sandwichDone = $false; minute = (Get-Date).Hour * 60 + (Get-Date).Minute
  sunPhase = ''; sunT = 0; sunLen = 0; nextSun = (Rand 5000 9000)
  busy = $false; waiting = $false; calling = $false; callT = 0; hour = (Get-Date).Hour; friday = $false
  napPhase = ''; napT = 0; napLen = 0; nextNap = (Rand (45 * $MIN) (90 * $MIN))
  musicPhase = ''; musicT = 0; musicLen = 0; nextMusic = (Rand (10 * $MIN) (20 * $MIN))
  bang = 0; hop = 0; lv = 4
  hwnd = [IntPtr]::Zero; w = 0; h = 0; margin = 40
  px = 0.0; py = 0.0; speed = 10.0; path = (New-Object System.Collections.ArrayList); target = $null
}

# his screen: the one you picked in the menu (remembered in screen.txt), the main screen if it isn't there
$screenFile = Join-Path $petDir 'screen.txt'
function Get-MyScreen {
  $areas = @([PetWin]::WorkAreas()); $main = @([PetWin]::Primaries())
  $i = -1; try { $i = [int](Get-Content $screenFile -ErrorAction Stop | Select-Object -First 1) } catch {}
  if ($i -lt 0 -or $i -ge $areas.Count) { $i = [Math]::Max(0, [Array]::IndexOf($main, $true)) }
  $areas[$i]
}
function Save-MyScreen([int]$i) { if ($TestSeconds -gt 0) { return }; try { Set-Content $screenFile $i } catch {} }
# his place: the bottom-right corner of his screen, just above the taskbar
function Get-HomeSpot {
  $wa = Get-MyScreen
  @{ x = $wa.Right - $S.w - $S.margin; y = $wa.Bottom - $S.h }
}
function Get-AreaAt([double]$x, [double]$y) {
  foreach ($wa in [PetWin]::WorkAreas()) {
    if ($x -ge $wa.Left -and $x -lt $wa.Right -and $y -ge $wa.Top -and $y -lt $wa.Bottom) { return $wa }
  }
  $null
}
# "Bye, Claude": he closes the lid, waves at you, takes the laptop under his arm and walks off the right edge of the screen;
# then the pet closes. The start is the same in reverse (Greet-Tick): in from the right edge, a wave, the laptop opens
function Start-Bye {
  if ($S.state -eq 'bye') { return }
  if ($S.state -eq 'nap') { End-Nap }; if ($S.state -eq 'music') { End-Music }; if ($S.state -eq 'sun') { End-Sun }
  if ($S.shadeStep -gt 0) { End-Shades }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  if ($S.calling) { $S.calling = $false }
  Set-ArmUp $false; Set-Paws 0 0 $false $false; Set-Legs -1; $flip.ScaleX = 1; $bob.Y = 0
  if ($S.lv -lt 1) { $S.lv = 1; Set-Laptop 1 }
  Set-LaptopTuck $false; $win.Opacity = 1
  $S.byeT = 0; $S.state = 'bye'
}
function Close-Bye { $script:byeChosen = $true; $timer.Stop(); $win.Close() }
function Bye-Tick {
  $S.byeT++; $k = $S.byeT
  $bang.Visibility = 'Hidden'
  if ($S.lv -gt 1) {
    # the lid comes down, a step every two ticks
    Set-Eyes 0 3 $false
    if ($k % 2 -eq 0) { $S.lv--; Set-Laptop $S.lv }
    $S.byeWave = $k
    return
  }
  $w = $k - $S.byeWave
  if ($w -lt 36) {
    # looks at you and waves: hand up, down, up
    Set-Eyes -1 2 $false; Set-Happy ($w -ge 6); Set-ArmUp ([Math]::Floor($w / 6) % 2 -eq 0)
    return
  }
  if ($w -lt 46) {
    # takes the closed laptop under his arm
    Set-ArmUp $false; Set-Happy $false; Set-Eyes 0 3 $false
    $S.lv = 0; Set-Laptop 0; Set-LaptopTuck $true
    $cur = [PetWin]::GetRect($S.hwnd); $S.px = [double]$cur.Left; $S.py = [double]$cur.Top
    return
  }
  # walks off the right edge of the screen, then the pet closes (at most 20 s, in case the window can't go further)
  $flip.ScaleX = -1; Set-Eyes 1 3 $false
  Set-Legs ([int][Math]::Floor($k / 3) % 2); $bob.Y = ([int][Math]::Floor($k / 3) % 2) * $PX
  $S.px += $S.speed
  [PetWin]::MoveTo($S.hwnd, [int]$S.px, [int]$S.py)
  $edge = (Get-MyScreen).Right
  if ($S.px -gt $edge + 4 -or $k -gt 300) { Close-Bye }
}
function Greet-Tick {
  $S.byeT++; $k = $S.byeT
  $bang.Visibility = 'Hidden'
  if ($k -lt 30) {
    # stops in his corner, looks at you and waves hi
    Set-Legs -1; $bob.Y = 0
    Set-Eyes -1 2 $false; Set-Happy ($k -ge 4); Set-ArmUp ([Math]::Floor($k / 6) % 2 -eq 0)
    return
  }
  # puts the laptop down and opens it (unpack lifts the lid the rest of the way)
  Set-ArmUp $false; Set-Happy $false
  Set-LaptopTuck $false; $S.lv = 1; Set-Laptop 1
  $S.state = 'unpack'
}
# walk along the taskbar: straight to the edge of this screen, hop onto the other screen's taskbar, walk on
function Start-Walk($tx, $ty) {
  $cur = [PetWin]::GetRect($S.hwnd)
  $S.px = [double]$cur.Left; $S.py = [double]$cur.Top
  $S.path.Clear()
  $src = Get-AreaAt ($S.px + $S.w / 2) ($S.py + $S.h / 2)
  $dst = Get-AreaAt ($tx + $S.w / 2) ($ty + $S.h / 2)
  if ($src -and $dst -and ($src.Left -ne $dst.Left -or $src.Top -ne $dst.Top)) {
    if ($tx -gt $S.px) { $bx = $src.Right - $S.w / 2 } else { $bx = $src.Left - $S.w / 2 }
    [void]$S.path.Add(@{ x = $bx; y = $S.py; hop = $false })
    [void]$S.path.Add(@{ x = $bx; y = $ty; hop = $true })
  }
  [void]$S.path.Add(@{ x = $tx; y = $ty; hop = $false })
  Set-LaptopTuck $true
  $S.state = 'walk'
}

# typing: calm bursts, the arms take turns slowly, little pauses to think
function Type-Tick {
  $t = $S.t
  if ($S.busy) { $S.pause = 0; if ($S.burst -lt 5) { $S.burst = 60 } }   # Claude Code is working: he types along, no breaks
  if ($S.pause -gt 0) {
    $S.pause--
    Set-Paws 0 0 $false $false
    $bob.Y = 0
    return
  }
  $S.burst--
  if ($S.burst -le 0) { $S.burst = Rand 30 70; $S.pause = Rand 15 40 }
  $rate = 3; if ($S.busy) { $rate = 2 }
  $step = [Math]::Floor($t / $rate) % 4   # near hand up, down on a key, far hand up, down on a key
  if ($step -eq 0) { Set-Paws 1 0 $false $false } elseif ($step -eq 1) { Set-Paws 0 0 $true $false }
  elseif ($step -eq 2) { Set-Paws 0 1 $false $false } else { Set-Paws 0 0 $false $true }
  if ($t % 12 -eq 0) { $S.scroll++; Scroll-Code $S.scroll }
  $bob.Y = 0
  if ($t % 30 -eq 0 -and $win.Opacity -gt 0) { Add-Glyph }
}
# sunglasses: his right hand brings them to his face (or takes them off), two ticks per frame
# each frame: arm up, glasses offset to the right, glasses shown, eyes shown
$shadeFrames = @(
  @($true, 3, $true, $true), @($true, 3, $true, $true), @($true, 2, $true, $true), @($true, 1, $true, $true),
  @($true, 0, $true, $false), @($true, 0, $true, $false), @($false, 0, $true, $false))
function Start-Shades([bool]$on) {
  $S.shadeDir = 1; if (-not $on) { $S.shadeDir = -1 }
  $S.shadeStep = 1
}
function End-Shades {
  $S.shadeStep = 0
  Set-ArmUp $false
  if ($S.shadeDir -gt 0) { $S.cool = $true; $S.coolT = Rand 600 1100 }
  else {
    $S.cool = $false; Set-Shades $false 0 0; $S.nextCool = Rand (4 * $MIN) (8 * $MIN)
    if ($S.hot) { $S.nextCool = Rand (1 * $MIN) (3 * $MIN) }   # a hot day: the glasses go back on soon
    if ($S.wantCup) { $S.wantCup = $false; $S.cup = 1 }
    if ($S.wantWiz) { $S.wantWiz = $false; Start-Wizard }   # glasses off first, then the hat   # glasses off first, then the coffee asked for in the menu
  }
}
# returns $true while the put-on / take-off animation is running
function Shades-Tick {
  if ($S.shadeStep -le 0) {
    if (-not $S.cool) { if ($S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') { $S.nextCool-- }; if ($S.nextCool -le 0) { Start-Shades $true } }
    else { $S.coolT--; if ($S.coolT -le 0) { Start-Shades $false } }
    if ($S.shadeStep -le 0) { return $false }
  }
  $n = $shadeFrames.Count
  $k = [Math]::Floor(($S.shadeStep - 1) / 2)
  if ($k -ge $n) { End-Shades; return $false }
  if ($S.shadeDir -gt 0) { $fr = $shadeFrames[$k] } else { $fr = $shadeFrames[$n - 1 - $k] }
  Set-Paws 0 0 $false $false
  Set-ArmUp $fr[0]
  Set-Shades $fr[2] $fr[1] 0
  Show-Eyes $fr[3]
  Set-Eyes 0 4 $false
  $bob.Y = 0
  $S.shadeStep++
  return $true
}
# coffee break, about ten seconds: lifts the mug and looks at it, a sip with happy eyes, enjoys it, puts it down
function End-Coffee {
  $S.cup = 0; $S.nextCup = Rand (4 * $MIN) (8 * $MIN)
  Set-Cup $false 0 0; Set-Steam -1; Set-Happy $false; Set-Heart $false
}
# nap: puts the laptop away, lies down, the book comes down on him, sleeps a minute or so, gets up again
function Start-Nap {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  $S.state = 'nap'; $S.napPhase = 'down'; $S.napT = 0
}
function End-Nap {
  Set-Nap $false; Set-Book $false 0; Set-Zz 0; Set-Breath 0
  $S.napPhase = ''; $S.nextNap = Rand (45 * $MIN) (90 * $MIN)
}
# daydream, about nine seconds: cheek on his hand, eyes up, a bubble with thinking dots, then a little dream
function End-Dream {
  $S.dream = 0; $S.nextDream = Rand (10 * $MIN) (20 * $MIN)
  Set-Bubble 0 0 'dots'; Set-Chin $false; Set-Happy $false
}
# returns $true while he is daydreaming
function Dream-Tick {
  if ($S.dream -le 0) {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') { $S.nextDream--; if ($S.nextDream -le 0) { $S.dream = 1 } }
    if ($S.dream -le 0) { return $false }
  }
  $k = $S.dream
  if ($k -gt 125) { End-Dream; return $false }
  Set-Paws 0 0 $false $false; $bob.Y = 0
  Set-Chin $true; Set-Happy $false
  if ($k -le 6) { Set-Bubble 1 0 'dots' }
  elseif ($k -le 62) { Set-Bubble 2 ([int]([Math]::Floor(($k - 7) / 8) % 4)) 'dots' }   # . .. ... and again
  elseif ($k -le 115) { Set-Bubble 2 0 'dream' }
  else { Set-Bubble 1 0 'dots' }
  Set-Eyes 1 2 ($k -gt 62 -and ($k % 30) -lt 4)   # looking up; slow blinks while dreaming
  $S.dream++
  return $true
}
# payday, about eight seconds, on its own only in the last week of the month: wallet out, the bill slides up, green dollar signs
function Test-PayWeek { $d = Get-Date; $d.Day -gt ([DateTime]::DaysInMonth($d.Year, $d.Month) - 7) }
function End-Pay {
  $S.pay = 0; $S.nextPay = Rand (4 * $MIN) (8 * $MIN)
  Set-Wallet $false 2; Set-PaySpark 0; Set-Happy $false
}
# returns $true while he is showing his wallet
function Pay-Tick {
  if ($S.pay -le 0) {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') {
      if (-not $S.payDone -and $S.minute -ge $S.payAt -and $S.minute -lt 1140) { $S.payDone = $true; $S.pay = 1 }
    }
    if ($S.pay -le 0) { return $false }
  }
  $k = $S.pay
  if ($k -gt 112) { End-Pay; return $false }
  Set-Paws 0 0 $false $false; $bob.Y = 0
  if ($k -le 10) { Set-Wallet $true 2; Set-Happy $false; Set-PaySpark 0; Set-Eyes 0 5 $false }
  elseif ($k -le 20) { Set-Wallet $true 1; Set-Happy $false; Set-PaySpark 0; Set-Eyes 0 5 $false }
  elseif ($k -le 100) { Set-Wallet $true 0; Set-Happy $true; Set-PaySpark (1 + [int]([Math]::Floor($k / 8) % 2)) }
  else { Set-Wallet $true 2; Set-Happy $false; Set-PaySpark 0; Set-Eyes 0 5 $false }
  $S.pay++
  return $true
}
# task done: Claude Code writes the time into done.txt when it finishes a task (a Stop hook), he sees it and waves a checkered flag
$doneFile = Join-Path $petDir 'done.txt'
function Get-DoneStamp { try { if (Test-Path $doneFile) { return (Get-Item $doneFile).LastWriteTimeUtc.Ticks } } catch {}; [long]0 }
$S.doneSeen = Get-DoneStamp   # no wave for what happened before he started
# a new task finished: wave as soon as he is back at his laptop (at most once a minute)
# what Claude Code is doing right now, from the times its hooks write: busy.txt when you send a message or a tool finishes,
# wait.txt when it needs your answer (a permission or a question), done.txt when it finishes
$busyFile = Join-Path $petDir 'busy.txt'
$waitFile = Join-Path $petDir 'wait.txt'
$askFile = Join-Path $petDir 'ask.txt'
function Get-Stamp($path) { try { if (Test-Path $path) { return (Get-Item $path).LastWriteTimeUtc.Ticks } } catch {}; [long]0 }
# your own settings, optional: %USERPROFILE%\ClaudePet\settings.json, for example
#   { "place": "Lyon", "latitude": 45.764, "longitude": 4.836, "weatherModel": "meteofrance_seamless", "newsLock": "C:\\path\\to\\job\\.lock" }
# place/latitude/longitude: where the weather comes from. weatherModel: an Open-Meteo model name ("best_match" picks one for you;
# "meteofrance_seamless" is the closest for France). newsLock: a file that exists while some job of yours runs; he reads the newspaper
# all that time (empty = no newspaper). Environment variables like %USERPROFILE% work in the path.
$Cfg = @{ place = 'Lyon'; latitude = 45.764; longitude = 4.836; weatherModel = 'best_match'; newsLock = '' }
$cfgFile = Join-Path $petDir 'settings.json'
try {
  if (Test-Path $cfgFile) {
    $mine = Get-Content $cfgFile -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($key in @($Cfg.Keys)) { if ($null -ne $mine.$key) { $Cfg[$key] = $mine.$key } }
  }
} catch { Write-PetLog "settings.json could not be read: $($_.Exception.Message)" }
# the weather, every 15 minutes from Open-Meteo (free, no key; only the coordinates are sent):
# it picks the weather scene (see Act-Tick and Ambient-Tick); 28 degrees or more also brings the sunglasses. The request runs in the background,
# so a slow network never stops him; offline he simply keeps the last answer
$inv = [Globalization.CultureInfo]::InvariantCulture
$wxUrl = 'https://api.open-meteo.com/v1/forecast?latitude={0}&longitude={1}&models={2}&current=temperature_2m,precipitation,weather_code,wind_speed_10m,cloud_cover,direct_radiation,shortwave_radiation,is_day' -f ([double]$Cfg.latitude).ToString($inv), ([double]$Cfg.longitude).ToString($inv), [Uri]::EscapeDataString([string]$Cfg.weatherModel)
# which scene the weather calls for, one at a time, the strongest wins ('' = clear, nothing special).
# Codes are Open-Meteo's (WMO): 95-99 thunderstorm, 71-77 and 85-86 snow, 61-67 and 80-82 rain, 51-57 drizzle,
# 45/48 fog, 3 overcast, 2 partly cloudy, 0-1 clear. $sunny: the sun gets through (see Weather-Tick); then no clouds,
# whatever the cloud code says (thin or breaking cloud the model still counts). Overcast is clouds, not fog (Katya)
function Get-WxKind([int]$code, [double]$temp, [double]$wind, [bool]$sunny = $false) {
  if ($code -ge 95) { return 'storm' }
  if (($code -ge 71 -and $code -le 77) -or $code -eq 85 -or $code -eq 86) { return 'snow' }
  if (($code -ge 61 -and $code -le 67) -or ($code -ge 80 -and $code -le 82)) { return 'rain' }
  if ($code -ge 51 -and $code -le 57) { return 'drizzle' }
  if ($wind -ge 35) { return 'wind' }
  if ($temp -le 3) { return 'cold' }
  if ($temp -ge 25) { return 'heat' }
  if ($code -eq 45 -or $code -eq 48) { return 'fog' }
  if (($code -eq 2 -or $code -eq 3) -and -not $sunny) { return 'cloudy' }
  ''
}
function Weather-Tick {
  if ($S.wxJob) {
    if (-not $S.wxJob.Handle.IsCompleted) {
      # a request that hangs (the laptop went to sleep in the middle, say): drop it after 2 minutes and ask again
      if ($S.t - $S.wxJob.At -gt 2 * $MIN) { try { [void]$S.wxJob.Ps.BeginStop($null, $null) } catch {}; $S.wxJob = $null; $S.wxNext = 0; Write-PetLog 'weather: no answer, asking again' }
      return
    }
    try {
      $now = ([string]($S.wxJob.Ps.EndInvoke($S.wxJob.Handle) | Select-Object -First 1) | ConvertFrom-Json).current
      # an empty or broken answer changes nothing: empty fields would read as 0 degrees and bring the cold scene by mistake
      if ($null -eq $now -or $null -eq $now.temperature_2m -or $null -eq $now.weather_code -or $null -eq $now.wind_speed_10m) { throw 'incomplete weather answer' }
      $code = [int]$now.weather_code
      $temp = [double]$now.temperature_2m; $wind = [double]$now.wind_speed_10m
      # the sun gets through when at least 40 % of the daylight comes straight from it (direct / total radiation)
      $sunShare = 0
      if ([int]$now.is_day -eq 1 -and [double]$now.shortwave_radiation -gt 0) { $sunShare = [Math]::Round(100 * [double]$now.direct_radiation / [double]$now.shortwave_radiation) }
      $w = Get-WxKind $code $temp $wind ($sunShare -ge 40)
      if ($w -ne $S.wx -or -not $S.wxSeen) {   # in pet.log: the first answer, then every change
        $S.wxSeen = $true
        Write-PetLog ("weather in {7}: {0} C, {1} mm, wind {2} km/h, code {3}, clouds {4}%, sun {5}% -> {6}" -f $temp, $now.precipitation, $wind, $code, $now.cloud_cover, $sunShare, $(if ($w) { $w } else { 'clear' }), $Cfg.place)
        if ($w) { $S.nextWep = Rand (1 * $MIN) (3 * $MIN) }   # it just started: he notices soon
      }
      $S.wx = $w
      $warm = $temp -ge 28
      if ($warm -and -not $S.hot -and -not $S.cool) { $S.nextCool = Rand (1 * $MIN) (3 * $MIN) }
      $S.hot = $warm
    } catch {}
    $S.wxJob.Ps.Dispose(); $S.wxJob = $null
    return
  }
  if ($S.t -lt $S.wxNext) { return }
  $S.wxNext = $S.t + 15 * $MIN
  $ps = [powershell]::Create()
  [void]$ps.AddScript('param($u) [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadString($u)').AddArgument($wxUrl)
  $S.wxJob = @{ Ps = $ps; Handle = $ps.BeginInvoke(); At = $S.t }
}
function Watch-Claude {
  $b = Get-Stamp $busyFile; $d = Get-DoneStamp; $w = Get-Stamp $waitFile
  $now = [DateTime]::UtcNow.Ticks; $minute = [long]600000000
  $S.busy = ($b -gt $d) -and ($now - $b -lt 30 * $minute)                     # forgets it after half an hour, in case a stop got lost
  if ($S.busy) { if ($S.busySince -eq 0) { $S.busySince = $now } } else { $S.busySince = [long]0; $S.popAt = 0 }
  $S.waiting = ($w -gt $b) -and ($w -gt $d) -and ($now - $w -lt 15 * $minute)
  # in the desktop app most questions come at the end of a turn (Stop), not as a separate prompt (Notification).
  # The Stop hook writes ask.txt only when that turn ended with a question for you (not for every turn, not for routines):
  # then, once the flag is down, he calls you for a minute, until you write
  $a = Get-Stamp $askFile; $second = [long]10000000
  if (($a -ge $d - 5 * $second) -and ($a -gt $b) -and ($now - $a -gt 8 * $second) -and ($now - $a -lt 70 * $second)) { $S.waiting = $true }
}
# Claude Code waits for you: he drops what he is doing and waves at you with a "!" (until you answer a prompt, a minute after a turn)
function Call-Tick {
  if (-not $S.waiting -or $S.shadeStep -gt 0 -or $S.flag -gt 0) {
    if ($S.calling) { $S.calling = $false; Set-ArmUp $false }
    return $false
  }
  if (-not $S.calling) { if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }; $S.calling = $true; $S.callT = 0 }
  $S.callT++; $k = $S.callT
  Set-Paws 0 0 $false $false; $bob.Y = 0
  Set-ArmUp ([Math]::Floor($k / 6) % 2 -eq 0)   # hand up, down, up: waving
  Set-Eyes -1 2 $false                           # looks out at you
  if (($k % 20) -lt 12) { $bang.Visibility = 'Visible' }
  return $true
}
function Watch-Done {
  $stamp = Get-DoneStamp
  if ($stamp -gt $S.doneSeen) {
    $S.doneSeen = $stamp
    if ($S.t - $S.lastFlag -gt 850) { $S.flagWant = $true }
  }
}
function Start-Flag {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
  $S.flag = 1; $S.flagWant = $false; $S.lastFlag = $S.t
}
function End-Flag {
  $S.flag = 0
  Set-Flag $false 0 0; Set-Confetti $false; Set-ArmUp $false; Set-Happy $false; $bob.Y = 0
}
# returns $true while the flag is up, about seven seconds
function Flag-Tick {
  if ($S.flag -le 0) {
    if ($S.flagWant -and $S.shadeStep -eq 0 -and $S.act -eq '') { Start-Flag } else { return $false }
  }
  $k = $S.flag
  if ($k -gt 98) { End-Flag; return $false }
  Set-Paws 0 0 $false $false; Set-ArmUp $true; Set-Confetti $false
  if ($k -le 8) { Set-Flag $true ([int][Math]::Max(0, 3 - [Math]::Floor($k / 2))) 0; Set-Happy $false; Set-Eyes 0 2 $false; $bob.Y = 0 }
  elseif ($k -le 90) {
    $w = [int]([Math]::Floor($k / 4) % 2)
    Set-Flag $true 0 $w; Set-Happy (-not $S.cool); $bob.Y = $w * $PX   # waves it and bounces
  }
  else { Set-Flag $true ([int][Math]::Min(3, [Math]::Floor(($k - 90) / 2))) 0; Set-Happy $false; Set-Eyes 0 2 $false; $bob.Y = 0 }
  $S.flag++
  return $true
}
# wizard: the hat stays on for a minute or two while he types; now and then he raises his wand, sparkles, a wink, code flies out
function Start-Wizard {
  $S.wizPhase = 'on'; $S.wizT = 0; $S.wizLen = Rand 850 1700; $S.spell = 0; $S.nextSpell = 60
}
function End-Wizard {
  Set-Hat $false 0; Set-Wand $false 0; Set-Wink $false
  $S.wizPhase = ''; $S.spell = 0; $S.nextWiz = Rand 4500 7000
}
# returns $true while the hat goes on or off or a spell is cast; with the hat simply on he keeps typing
function Wizard-Tick {
  if ($S.wizPhase -eq '') {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') {
      if (-not $S.wizDone -and $S.minute -ge $S.wizAt -and $S.minute -lt 1140) { $S.wizDone = $true; Start-Wizard }
    }
    if ($S.wizPhase -eq '') { return $false }
  }
  $S.wizT++; $k = $S.wizT
  $free = $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0
  if ($S.wizPhase -eq 'on') {
    $dy = [int][Math]::Min(0, -3 + [Math]::Floor($k / 2))
    Set-Hat $true $dy; Set-Paws 0 0 $false $false; Set-Eyes 0 2 $false; $bob.Y = 0
    if ($dy -ge 0) { $S.wizPhase = 'stay'; $S.wizT = 0 }
    return $true
  }
  if ($S.wizPhase -eq 'off') {
    Set-Wand $false 0; Set-Wink $false; Set-Eyes 0 2 $false; $bob.Y = 0
    Set-Hat ($k -lt 6) ([int](-1 - [Math]::Floor($k / 2)))
    if ($k -ge 8) { End-Wizard; return $false }
    return $true
  }
  Set-Hat $true 0
  if ($S.spell -gt 0) {
    $step = $S.spell
    Set-Paws 0 0 $false $false; $bob.Y = 0
    if ($step -le 6) { Set-Wand $true 0; Set-Wink $false; Set-Eyes 0 2 $false }
    elseif ($step -le 40) {
      Set-Wand $true (1 + [int]([Math]::Floor($step / 5) % 2)); Set-Wink ($step -gt 18 -and $step -le 30); Set-Eyes 0 2 $false
      if (($step -eq 12 -or $step -eq 16 -or $step -eq 20) -and $win.Opacity -gt 0) { Add-Glyph }   # a little code flies out of the laptop
    }
    else { Set-Wand $false 0; Set-Wink $false; $S.spell = 0; $S.nextSpell = Rand 250 450; return $false }
    $S.spell++
    return $true
  }
  if ($wand[0].Visibility -eq 'Visible') { Set-Wand $false 0; Set-Wink $false }   # after you came by
  if ($free -and $k -ge $S.wizLen) { $S.wizPhase = 'off'; $S.wizT = 0; return $true }
  if ($free) { $S.nextSpell--; if ($S.nextSpell -le 0) { $S.spell = 1; return $true } }
  return $false
}
# detective, about eight seconds: deerstalker on, magnifying glass up, he hunts for the bug ("?"), finds it ("!"), hat off again
function End-Det {
  $S.det = 0; $S.nextDet = Rand (10 * $MIN) (20 * $MIN)
  Set-Deer $false 0; Set-Lens $false 0 0; Set-Clue ''
}
# returns $true while he is on the case
function Det-Tick {
  if ($S.det -le 0) {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') {
      $S.nextDet--; if ($S.nextDet -le 0) { $S.det = 1 }
    }
    if ($S.det -le 0) { return $false }
  }
  $k = $S.det
  if ($k -gt 118) { End-Det; return $false }
  Set-Paws 0 0 $false $false; $bob.Y = 0
  if ($k -le 8) { Set-Deer $true ([int][Math]::Min(0, -3 + [Math]::Floor($k / 2))); Set-Lens $false 0 0; Set-Clue ''; Set-Eyes 0 2 $false }
  elseif ($k -le 14) { Set-Deer $true 0; Set-Lens $true 0 0; Set-Clue '' }
  elseif ($k -le 60) {
    # looks down at the laptop, around, down again
    $look = @(@(-1, 1), @(0, 0), @(-1, 0), @(0, 1))[[int]([Math]::Floor($k / 10) % 4)]
    Set-Deer $true 0; Set-Lens $true $look[0] $look[1]; Set-Clue '?'
  }
  elseif ($k -le 100) { Set-Deer $true 0; Set-Lens $true 0 0; Set-Clue '!' }
  elseif ($k -le 108) { Set-Deer $true 0; Set-Lens $false 0 0; Set-Clue ''; Set-Eyes 0 2 $false }
  else { Set-Deer ($k -lt 116) ([int](-1 - [Math]::Floor(($k - 108) / 2))); Set-Lens $false 0 0; Set-Eyes 0 2 $false }
  $S.det++
  return $true
}
# bug hunt, about eight seconds: a bug crawls along the lid, "!", the jar comes down on it, he holds it up, a green tick
function End-Bug {
  $S.bug = 0; $S.nextBug = Rand (10 * $MIN) (20 * $MIN)
  Set-Bug $false 0 0; Set-Jar '' 0; Set-Tick $false; Set-Happy $false
}
# returns $true while he is after the bug
function Bug-Tick {
  if ($S.bug -le 0) {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') {
      $S.nextBug--; if ($S.nextBug -le 0) { $S.bug = 1 }
    }
    if ($S.bug -le 0) { return $false }
  }
  $k = $S.bug
  if ($k -gt 118) { End-Bug; return $false }
  $legStep = [int]([Math]::Floor($k / 2) % 2)
  $bob.Y = 0; Set-Tick $false; Set-Happy $false   # the hover shows the tick early; take it away again
  if ($k -le 40) {
    # it crawls in from the left; he keeps typing at first, then looks at it
    Set-Jar '' 0; Set-Bug $true ([int](-6 + [Math]::Floor($k / 4))) $legStep
    if ($k -le 16) { Type-Tick; Set-Eyes 0 4 $false } else { Set-Paws 0 0 $false $false; Set-Eyes -1 4 $false }
  }
  elseif ($k -le 52) { Set-Jar '' 0; Set-Paws 0 0 $false $false; Set-Bug $true 4 $legStep; Set-Eyes -1 4 $false; $bang.Visibility = 'Visible' }
  elseif ($k -le 60) { Set-Bug $true 4 $legStep; Set-Jar 'down' ([int][Math]::Min(0, -4 + [Math]::Floor(($k - 52) / 2))); Set-Eyes -1 4 $false }
  elseif ($k -le 76) { Set-Bug $true 4 $legStep; Set-Jar 'down' 0; Set-Eyes -1 4 $false }
  elseif ($k -le 112) {
    # holds the jar up and looks at the bug; then a tick, happy
    Set-Bug $false 0 0; Set-Jar 'up' 0
    if ($k -le 88) { Set-Eyes 0 3 $false } else { Set-Tick $true; Set-Happy $true }
  }
  else { Set-Tick $false; Set-Happy $false; Set-Jar '' 0; Set-Paws 0 0 $false $false; Set-Eyes 0 4 $false }
  $S.bug++
  return $true
}
# --- acts: longer scenes played step by step, like their storyboards ----------------------------------------
# the weather scenes ('w:snow', 'w:heat', ...), the newspaper ('news') and the popcorn ('pop').
# Each act is a list of steps: d = how many ticks, f = what to show; inside f, $j = ticks into the step,
# $k = ticks into the act, $alt = 0/1 every three ticks (falling flakes, drops, steam). A step with loop = 'busy'
# repeats while Claude Code is still working (the popcorn), loop = 'news' while the newspaper job is running (the newspaper).
function St([int]$d, [scriptblock]$f, [string]$loop = '') { @{ d = $d; f = $f; loop = $loop } }
function Show-All($list, [bool]$on) { foreach ($el in $list) { foreach ($e in @($el)) { Show-If $e $on } } }
# everything an act may have shown, put back: props away, eyes and ears back, laptop open
function Reset-ActLooks {
  Set-Snow $false 0 99 $false 0 $false 0 $false; Set-SnowEnd 0 0
  Set-Heat $false 0 $false 99 $false 0 $false; $tongue.Visibility = 'Hidden'
  Set-Sky 99
  Set-Fog 0 0 99 99 $false
  Set-Drizzle $false 0 $false $false $false; Set-Raincoat $false 99 99 $false
  Set-Rain 0 0; Set-RainUmb 0; Set-Splash $false; Set-RainPuddle 0 0 $false
  Set-Storm 99 $false $false 0 0
  Set-Wind $false 0 0 'gone' $false $false $false
  Set-Cold 0 0 0 $false 99 0 $false
  Set-Paper $false 0; Set-LaptopAside $false; Set-Popcorn $false 0 0
  Set-Tick $false; Set-Happy $false; Set-ArmUp $false
  foreach ($el in $askMark) { $el.Visibility = 'Hidden' }
  if (-not $S.cool) { Set-Shades $false 0 0; Show-Eyes $true }
  $bob.X = 0; $bob.Y = 0; Set-Legs -1; Set-Top $earL 6; Set-Top $earR 6
  $S.lv = 4; Set-Laptop 4
}
$acts = @{
  'w:snow' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Snow $true $alt 99 $false 0 $false 0 $false }),
    (St 14 { Set-Snow $true $alt 99 $false 0 $false 0 $false; Set-Eyes 0 2 $false; $bang.Visibility = 'Visible' }),
    (St 10 { Set-Snow $true $alt ([int][Math]::Min(0, -4 + [Math]::Floor($j / 2))) $false 0 $false 0 $false }),
    (St 18 { Set-Snow $true $alt 0 $true 0 $false 0 $false; Set-Happy $true }),
    (St 40 { Set-Happy $false; Type-Tick; Set-Eyes 0 4 $false; Set-Snow $true $alt 0 $true 1 $false 0 $false }),
    (St 20 { Set-Eyes 0 2 $false; Set-Snow $true $alt 0 $true 1 $true 0 $false }),
    (St 18 { Set-Eyes 1 4 $false; Set-Snow $true $alt 0 $true 2 $false 1 $true }),
    (St 18 { Set-Snow $true $alt 0 $true 2 $false 2 $true }),
    (St 24 { Set-Snow $true $alt 0 $true 2 $false 3 $false; Set-Happy $true; Set-Heart $true }),
    (St 40 { Set-Happy $false; Type-Tick; Set-Eyes 0 4 $false; Set-Snow $true $alt 0 $true 2 $false 3 $false }),
    (St 16 { Set-Snow $true $alt 0 $true 2 $false 3 $false; Set-Eyes 0 2 $false }),
    (St 8 { Set-Snow $true $alt 0 $true 1 $false 3 $false; Set-SnowEnd 1 0; Set-Eyes -1 3 $true }),
    (St 8 { Set-Snow $true $alt 0 $true 0 $false 3 $false; Set-SnowEnd 2 0; Set-Eyes 1 3 $true }),
    (St 8 { Set-SnowEnd 1 0; Set-Eyes -1 3 $true }),
    (St 8 { Set-SnowEnd 2 0; Set-Eyes 1 3 $true }),
    (St 14 { Set-SnowEnd 0 0; Set-ArmUp $true; Set-Snow $true $alt -3 $true 0 $false 3 $false; Set-Eyes 0 3 $false }),
    (St 16 { Set-ArmUp $false; Set-Snow $true $alt 99 $false 0 $false 0 $false; Set-SnowEnd 0 1; Set-Eyes 1 4 $false }),
    (St 16 { Set-Snow $true $alt 99 $false 0 $false 0 $false; Set-SnowEnd 0 2 }),
    (St 16 { Set-Snow $true $alt 99 $false 0 $false 0 $false; Set-SnowEnd 0 3; Set-Eyes 0 4 $false }))
  'w:heat' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Heat $true $alt $false 99 $false 0 $false }),
    (St 14 { Set-Heat $true $alt $true 99 $false 0 $false; Set-Eyes 0 2 $false }),
    (St 14 { Set-Heat $true $alt $true 99 $false 0 $false; Set-ArmUp $true; Set-Eyes 0 3 $true }),
    (St 10 { Set-ArmUp $false; Set-Heat $true $alt $true ([int][Math]::Max(0, 4 - [Math]::Floor($j / 2))) $false 0 $false; Set-Eyes 1 4 $false }),
    (St 24 { Set-Heat $true $alt $true 0 $true 0 $false; Set-Eyes 1 3 $false }),
    (St 20 { Set-Heat $true $alt $false 0 $true 0 $false; Set-Shades $true 0 0; Show-Eyes $false }),
    (St 20 { Set-Heat $true $alt $false 0 $true 1 $false; Show-Eyes $false }),
    (St 24 { Set-Heat $true $alt $false 0 $true 2 $true; Show-Eyes $false; $tongue.Visibility = 'Visible' }),
    (St 20 { $tongue.Visibility = 'Hidden'; Set-Heat $true $alt $false 0 $true 0 $false; Show-Eyes $false; Set-Heart $true }),
    (St 40 { Type-Tick; Set-Heat $true $alt $false 0 $true 0 $false; Show-Eyes $false }),
    (St 14 { Set-Heat $false 0 $false 0 $false 0 $false; Show-Eyes $false }),
    (St 10 { Set-Shades $false 0 0; Show-Eyes $true; Set-Eyes 0 3 $false; Set-Heat $false 0 $false ([int][Math]::Min(5, [Math]::Floor($j / 2))) $false 0 $false }),
    (St 10 { Set-Heat $false 0 $false 99 $false 0 $false; Set-Eyes 0 4 $false }))
  'w:cloudy' = @(
    (St 30 { Type-Tick; Set-Eyes 0 4 $false; Set-Sky ([int](-14 + [Math]::Floor($j / 4))) }),
    (St 18 { Set-Sky ([int](-7 + [Math]::Floor($j / 3))); Set-Eyes -1 2 $false }),
    (St 20 { Set-Sky 0; Set-Eyes 0 2 $false }),
    (St 40 { Set-Sky 0; Type-Tick; Set-Eyes 0 4 $false }),
    (St 24 { Set-Sky ([int][Math]::Floor($j / 3)); Set-Eyes 1 2 $false }),
    (St 16 { Set-Sky 99; Set-Eyes 0 4 $false }))
  'w:fog' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Fog 1 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 99 $false }),
    (St 18 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 99 $false; Set-Eyes 0 4 $true }),
    (St 14 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 99 $false; Set-Eyes -1 4 $true }),
    (St 10 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) -1 99 $false; Set-Eyes -1 5 $false }),
    (St 10 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 1 99 $false }),
    (St 10 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) -1 99 $false }),
    (St 10 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 1 99 $false }),
    (St 10 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 ([int][Math]::Max(0, 3 - [Math]::Floor($j / 3))) $false; Set-Eyes 1 4 $false }),
    (St 16 { Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 0 $true; Set-Happy $true }),
    (St 40 { Set-Happy $false; Type-Tick; Set-Eyes 0 4 $false; Set-Fog 2 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 0 $true }),
    (St 16 { Set-Fog 1 ([int]([Math]::Floor($k / 8) % 9) - 4) 99 0 $true; Set-Eyes 0 2 $false }),
    (St 12 { Set-Fog 0 0 99 0 $false }),
    (St 10 { Set-Fog 0 0 99 ([int][Math]::Min(5, [Math]::Floor($j / 2))) $false; Set-Eyes 0 4 $false }))
  'w:drizzle' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Drizzle $true $alt $false $false $false }),
    (St 12 { Set-Drizzle $true $alt $true $false $false; Set-Eyes 0 4 $true }),
    (St 14 { Set-Drizzle $true $alt $false $false $false; Set-Raincoat $true 99 99 $false; Set-Eyes 1 4 $false }),
    (St 10 { Set-Drizzle $true $alt $false $false $false; Set-Raincoat $false ([int][Math]::Max(0, 3 - [Math]::Floor($j / 3))) 99 $false; Set-Eyes 0 4 $false }),
    (St 12 { Set-Drizzle $true $alt $false $false $false; Set-Raincoat $false 0 99 $true; Set-Eyes 0 5 $false }),
    (St 10 { Set-Drizzle $true $alt $false $false $false; Set-Raincoat $false 0 ([int][Math]::Min(0, -3 + [Math]::Floor($j / 3))) $true; Set-Eyes 0 2 $false }),
    (St 16 { Set-Drizzle $true $alt $false $false $false; Set-Raincoat $false 0 0 $true; Set-Happy $true }),
    (St 40 { Set-Happy $false; Type-Tick; Set-Eyes 0 4 $false; Set-Drizzle $true $alt $false $true $true }),
    (St 14 { Set-Drizzle $true $alt $false $true $true; Set-Eyes 0 2 $false }),
    (St 8 { Set-Drizzle $true $alt $false $false $true; Set-Raincoat $false 0 -3 $true; Set-SnowEnd 1 0; Set-Eyes -1 3 $true }),
    (St 8 { Set-SnowEnd 2 0; Set-Raincoat $false 3 99 $true; Set-Eyes 1 3 $true }),
    (St 12 { Set-SnowEnd 0 0; Set-Raincoat $false 99 99 $false; Set-Drizzle $true $alt $false $false $false; Set-Eyes 0 4 $false }))
  'w:rain' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Rain 1 $alt }),
    (St 14 { Set-Rain 1 $alt; Set-Splash $true; Set-Eyes 0 2 $false; $bang.Visibility = 'Visible' }),
    (St 10 { Set-Splash $false; Set-Rain 1 $alt; Set-RainUmb 1 }),
    (St 8 { Set-Rain 1 $alt; Set-RainUmb 2 }),
    (St 20 { Set-Rain 2 $alt; Set-RainUmb 3; Set-RainPuddle 1 (1 + $alt) $false; Set-Eyes 0 3 $false }),
    (St 24 { Set-Rain 2 $alt; Set-RainUmb 3; Set-RainPuddle 2 (1 + $alt) $false; Set-Eyes 1 5 $false }),
    (St 50 { Set-Rain 2 $alt; Set-RainUmb 3; Set-RainPuddle 2 (1 + $alt) $false; Set-Happy $true }),
    (St 14 { Set-Happy $false; Set-Rain 0 0; Set-RainUmb 2; Set-RainPuddle 2 0 $false; Set-Eyes 0 2 $false }),
    (St 10 { Set-RainUmb 1; Set-RainPuddle 2 0 $false; Set-SnowEnd 1 0; Set-Eyes -1 3 $true }),
    (St 14 { Set-SnowEnd 0 0; Set-RainUmb 0; Set-RainPuddle 2 0 $false; Set-Raincoat $false 99 99 $true; Set-Eyes 1 5 $false }),
    (St 8 { Set-RainPuddle 2 0 $true; Set-Happy $true }),
    (St 14 { Set-RainPuddle 1 0 $false }),
    (St 10 { Set-Happy $false; Set-Raincoat $false 99 99 $false; Set-RainPuddle 0 0 $false; Set-Eyes 0 4 $false }))
  'w:storm' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Storm ([int](-6 + [Math]::Floor($j / 3))) $false $false 0 0 }),
    (St 14 { Set-Storm 0 $false $false 0 0; Set-Rain 1 $alt; Set-Eyes 0 2 $false }),
    (St 6 { Set-Storm 0 $true ($j -lt 3) 0 1; Set-Rain 1 $alt; Set-Eyes 0 1 $false; $bang.Visibility = 'Visible' }),
    (St 20 { Set-Storm 0 $false $false 4 0; Set-Rain 1 $alt; Set-Eyes 0 4 $true }),
    (St 16 { Set-Storm 0 $true ($j -lt 2) 4 0; Set-Rain 1 $alt; Set-Eyes 0 4 $true }),
    (St 14 { Set-Storm 0 $false $false 4 0; Set-Rain 1 $alt; Set-Eyes -1 4 $false }),
    (St 14 { Set-Storm 0 $false $false 4 0; Set-Rain 1 $alt; Set-Eyes 1 4 $false }),
    (St 16 { Set-Storm ([int][Math]::Floor($j / 2)) $false $false 2 0; Set-Rain 0 0; Set-Eyes 1 3 $false }),
    (St 16 { Set-Storm 99 $false $false 0 0; Set-ArmUp $true; Set-Eyes 0 3 $true }),
    (St 16 { Set-ArmUp $false; Set-Happy $true; Set-Heart $true }),
    (St 8 { Set-Happy $false; Set-Eyes 0 4 $false }))
  'w:wind' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Wind $true $alt 0 'gone' $false $false $false }),
    (St 14 { Set-Wind $true $alt 0 'gone' $false $false $false; Set-Eyes 0 4 $true }),
    (St 22 { Set-Wind $true $alt 0 'held' $false $false $false; Set-Happy $true; Set-Heart $true }),
    (St 10 { Set-Happy $false; Set-Wind $true $alt 0 'snatch' $false $false $false; Set-Eyes -1 2 $false; $bang.Visibility = 'Visible' }),
    (St 12 { Set-Wind $true $alt 0 'away' $false $false $false; Set-Eyes -1 2 $false }),
    (St 16 { Set-Wind $true $alt 0 'gone' $false $false $false; foreach ($el in $askMark) { $el.Visibility = 'Visible' }; Set-Eyes -1 3 $false }),
    (St 16 { foreach ($el in $askMark) { $el.Visibility = 'Hidden' }; Set-Wind $true $alt 0 'gone' $true $false $false; Set-Eyes 0 4 $true }),
    (St 16 { Set-Wind $true $alt 0 'gone' $false $true $false; Set-Eyes 0 3 $false }),
    (St 40 { Set-Wind $true $alt -1 'gone' $false $false $false; Type-Tick; Set-Eyes 0 4 $true }),
    (St 16 { Set-Wind $false 0 0 'gone' $false $false $true; Set-Eyes -1 4 $false }),
    (St 14 { Set-Wind $false 0 0 'gone' $false $false $false; Set-Happy $true }),
    (St 8 { Set-Happy $false; Set-Eyes 0 4 $false }))
  'w:cold' = @(
    (St 16 { Type-Tick; Set-Eyes 0 4 $false; Set-Cold 1 0 0 $false 99 $alt $false }),
    (St 6 { Set-Cold 1 -1 1 $false 99 $alt $false; Set-Eyes 0 4 $true }),
    (St 6 { Set-Cold 1 1 2 $false 99 $alt $false; Set-Eyes 0 4 $true }),
    (St 6 { Set-Cold 1 -1 1 $false 99 $alt $false; Set-Eyes 0 4 $true }),
    (St 6 { Set-Cold 1 1 2 $false 99 $alt $false; Set-Eyes 0 4 $true }),
    (St 18 { Set-Cold 1 0 1 $true 99 $alt $false; Set-Eyes 0 3 $false }),
    (St 16 { Set-Cold 1 0 0 $true 0 $alt $false; Set-Eyes 0 5 $false }),
    (St 18 { Set-Cold 1 0 0 $true -1 $alt $false; Set-Happy $true }),
    (St 20 { Set-Cold 1 0 0 $true 0 $alt $true; Set-Happy $true; Set-Heart $true }),
    (St 40 { Set-Happy $false; Type-Tick; Set-Eyes 0 4 $false; Set-Cold 1 0 0 $true 99 $alt $true }),
    (St 16 { Set-Cold 2 0 0 $true 99 0 $true; Set-Eyes -1 5 $false }),
    (St 14 { Set-Cold 0 0 0 $false 99 0 $false; Set-Eyes 0 3 $false }),
    (St 8 { Set-Eyes 0 4 $false }))
  'news' = @(
    (St 10 { Set-Eyes 0 4 $false }),
    (St 14 { Set-Eyes 0 2 $false; $bang.Visibility = 'Visible' }),
    (St 8 { $S.lv = [int][Math]::Max(0, 4 - [Math]::Floor($j / 2)); Set-Laptop $S.lv; Set-Legs -1 }),
    (St 14 { $S.lv = 0; Set-Laptop 0; Set-LaptopAside $true; Set-Eyes -1 4 $false }),
    (St 8 { Set-Paper $true ([int][Math]::Max(0, 3 - [Math]::Floor($j / 2))); Set-Eyes 0 3 $false }),
    (St 60 {
      # reads the left page, then the right one, now and then a little nod; again and again while the routine works
      if ($j -lt 26) { Set-Paper $true 0; Set-Eyes -1 3 $false } elseif ($j -lt 52) { Set-Paper $true 0; Set-Eyes 1 3 $false } else { Set-Paper $true 1; Set-Eyes 0 3 $true }
    } 'news'),
    (St 24 { Set-Paper $true 0; Set-Tick $true; Set-Happy $true }),
    (St 12 { Set-Paper $false 0; Set-Tick $false; Set-Happy $false; Set-Eyes 0 3 $false }),
    (St 10 { Set-LaptopAside $false; $S.lv = [int][Math]::Min(4, [Math]::Floor($j / 2)); Set-Laptop $S.lv; Set-Eyes 0 4 $false }))
  'pop' = @(
    (St 8 { Set-Popcorn $true 1 ([int][Math]::Min(0, -3 + [Math]::Floor($j / 2))); Set-Eyes -1 4 $false }),
    (St 10 { Set-Popcorn $true 1 0 }),
    (St 120 {
      if ($j -lt 12) { Set-Popcorn $true 1 0; Set-Happy $false; Set-Eyes -1 4 $false }
      elseif ($j -lt 30) { Set-Popcorn $true 2 0; Set-Happy $true }
      else { Set-Popcorn $true 0 0; Set-Happy $false; Set-Eyes 0 4 $false }
    } 'busy'),
    (St 10 { Set-Popcorn $true 0 ([int](-[Math]::Floor($j / 3))); Set-Happy $false; Set-Eyes 0 4 $false }))
}
function Start-Act([string]$name) {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
  Reset-ActLooks
  $S.act = $name; $S.actK = 0
  if ($name -eq 'news' -or $name -like 'w:*') { Write-PetLog "act: $name" }   # so a newspaper or a weather scene can be checked afterwards
}
function End-Act {
  $was = $S.act; $S.act = ''; $S.actK = 0
  Reset-ActLooks
  if ($was -like 'w:*') { $S.nextWep = Rand (20 * $MIN) (40 * $MIN) }   # the same weather again in a while
  if ($was -eq 'pop') { $S.popAt = $S.t + (Rand (3 * $MIN) (5 * $MIN)) }   # a short bowl, then other poses, then popcorn again if it still works
}
# returns $true while an act plays; starts one when it is due: the newspaper just came out, Claude Code has been working
# for more than ten minutes (popcorn), or the weather calls for its scene
function Act-Tick {
  if ($S.act -eq '') {
    $free = -not $S.waiting -and -not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0
    if (-not $free) { return $false }
    if ($S.newsWant) { $S.newsWant = $false; Start-Act 'news' }
    elseif ($S.busy -and $S.busySince -gt 0 -and ([DateTime]::UtcNow.Ticks - $S.busySince) -gt [long]6000000000 -and $S.t -ge $S.popAt) { Start-Act 'pop' }
    elseif ($S.wx -ne '') { $S.nextWep--; if ($S.nextWep -le 0) { Start-Act "w:$($S.wx)" } }
    if ($S.act -eq '') { return $false }
  }
  $k = $S.actK; $start = 0; $step = $null
  foreach ($st in $acts[$S.act]) { if ($k -lt $start + $st.d) { $step = $st; break }; $start += $st.d }
  if (-not $step) { End-Act; return $false }
  $j = $k - $start; $alt = [int]([Math]::Floor($k / 3) % 2)
  Set-Paws 0 0 $false $false
  . $step.f
  $S.actK++
  # the popcorn goes on while Claude Code works, about a minute a bowl; the newspaper as long as the newspaper job
  if ($S.actK -ge $start + $step.d) {
    if ($step.loop -eq 'busy' -and $S.busy -and -not $S.waiting -and $S.actK -lt $MIN) { $S.actK = $start }
    if ($step.loop -eq 'news' -and $S.newsRunning -and $S.actK -lt 120 * $MIN) { $S.actK = $start }   # (a run left hanging: two hours at most)
  }
  return $true
}
# the weather all the time it lasts, between the scenes: flakes, drops, mist, the sun, frost... (no props in his hands)
function Clear-Ambient {
  Show-All @($snowA, $snowB, $drizA, $drizB, $rainA, $rainB, $cloudStorm, $bolt, $gustA, $gustB, $sun, $sunRays, $mistThin, $mistThick, $frost, $breathA) $false
  foreach ($g in @($leavesA) + @($leavesB)) { Show-All $g $false }
  $cloud.Visibility = 'Hidden'; $flash.Visibility = 'Hidden'; $sky.Visibility = 'Hidden'; $mist.Visibility = 'Hidden'
}
function Ambient-Tick {
  if ($S.act -like 'w:*') { return }   # a weather scene shows its own
  $w = $S.wx; $t = $S.t; $alt = [Math]::Floor($t / 3) % 2 -eq 1
  if ($w -ne $S.ambWas) { Clear-Ambient; $S.ambWas = $w }
  switch ($w) {
    'snow' { Show-All $snowA (-not $alt); Show-All $snowB $alt }
    'drizzle' { Show-All $drizA (-not $alt); Show-All $drizB $alt }
    'rain' { Show-All $rainA (-not $alt); Show-All $rainB $alt }
    'storm' {
      $cloud.Visibility = 'Visible'; $cloudT.X = 0; Show-All $cloudLight $false; Show-All $cloudStorm $true
      Show-All $rainA (-not $alt); Show-All $rainB $alt
      Show-All $bolt (($t % 280) -lt 6); Show-If $flash (($t % 280) -lt 2)   # now and then a strike
    }
    'wind' {
      Show-All $gustA (-not $alt); Show-All $gustB $alt
      foreach ($g in $leavesA) { Show-All $g (-not $alt) }; foreach ($g in $leavesB) { Show-All $g $alt }
    }
    'heat' { Show-All $sun $true; Show-All $sunRays ([Math]::Floor($t / 8) % 2 -eq 1) }
    'cloudy' { $x = ([Math]::Floor($t / 6) % 60) - 18; Show-If $sky ($x -le 16); $skyT.X = $x * $PX }   # drifts across, then a pause
    'fog' { $mist.Visibility = 'Visible'; Show-All $mistThin $true; Show-All $mistThick $false; $mistT.X = (([Math]::Floor($t / 10) % 9) - 4) * $PX }
    'cold' { Show-All $frost ($S.lv -ge 4); Show-All $breathA (($t % 140) -lt 18) }   # frost only on the open lid
  }
}
# the newspaper: while a job of yours runs, it holds a lock file (newsLock in settings.json; for example a scraping routine
# creates it at its start and deletes it at its end). He starts reading when it appears and folds the paper when it's gone.
# A lock older than two hours is one a crashed run left behind.
$newsLock = [Environment]::ExpandEnvironmentVariables([string]$Cfg.newsLock)
function Watch-News {
  $on = $false
  try { if ($newsLock -and (Test-Path -LiteralPath $newsLock)) { $on = ((Get-Date) - (Get-Item -LiteralPath $newsLock).LastWriteTime).TotalHours -lt 2 } } catch {}
  if ($on -and -not $S.newsRunning) { Write-PetLog 'the newspaper job started' }
  if (-not $on -and $S.newsRunning) { Write-PetLog 'the newspaper job ended' }
  # while a run works he reads (back to it after anything that interrupted him); once it's over, no late newspaper
  $S.newsWant = $on -and $S.act -ne 'news'
  $S.newsRunning = $on
}
# the day's plan, made once a day: the meals, and the rare poses that run by the clock (payday, the wizard, the Friday beach)
# (he waits for a free moment, until 11:00 and 13:30); he eats in three bites, then finds a broom and sweeps the crumbs away
function New-MealDay {
  $S.mealDay = (Get-Date).ToString('yyyy-MM-dd')
  $S.croissantAt = Rand 510 645; $S.sandwichAt = Rand 740 770
  $S.croissantDone = $false; $S.sandwichDone = $false
  $S.payAt = Rand 600 1020; $S.payDone = -not (Test-PayWeek)          # 10:00-17:00, only in the last week of the month
  $S.wizAt = Rand 570 1050; $S.wizDone = (Rand 1 5) -ne 1             # 9:30-17:30, on about one day in five
  $S.sunAt = Rand 960 1050; $S.sunDone = (Get-Date).DayOfWeek -ne 'Friday'   # Friday 16:00-17:30
}
function Start-Meal([string]$food) {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
  $S.food = $food; $S.eat = 1
}
function End-Meal {
  $S.eat = 0
  Set-Lunch $false 3 0; Set-Crumbs 0; Set-Broom $false 0 0; Set-Puff $false; Set-Clue ''; Set-Happy $false
}
# returns $true while he eats or sweeps
function Meal-Tick {
  if ($S.eat -le 0) {
    if ($S.mealDay -ne (Get-Date).ToString('yyyy-MM-dd')) { New-MealDay }
    $free = -not $S.waiting -and -not $S.cool -and $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq ''
    if ($free -and -not $S.croissantDone -and $S.minute -ge $S.croissantAt -and $S.minute -lt 660) { $S.croissantDone = $true; Start-Meal 'croissant' }
    elseif ($free -and -not $S.sandwichDone -and $S.minute -ge $S.sandwichAt -and $S.minute -lt 810) { $S.sandwichDone = $true; Start-Meal 'sandwich' }
    if ($S.eat -le 0) { return $false }
  }
  $k = $S.eat
  if ($k -gt 176) { End-Meal; return $false }
  Set-Paws 0 0 $false $false; $bob.Y = 0; Set-Clue ''; Set-Puff $false
  if ($k -le 76) {
    # eating: looks at it, three bites with happy eyes, crumbs fall onto the laptop, a heart when it's gone
    Set-Broom $false 0 0
    $bites = 0; $dy = 0; $crumbs = 0
    if ($k -le 10) { }
    elseif ($k -le 20) { $dy = -2 }
    elseif ($k -le 36) { $bites = 1; $crumbs = 1 }
    elseif ($k -le 46) { $bites = 1; $dy = -2; $crumbs = 2 }
    elseif ($k -le 62) { $bites = 2; $crumbs = 1 }
    else { $bites = 3; $crumbs = 2; Set-Heart $true }
    Set-Lunch $true $bites $dy $S.food; Set-Crumbs $crumbs
    if ($k -le 10) { Set-Happy $false; Set-Eyes 0 5 $false } else { Set-Happy $true }
  }
  else {
    # the crumbs: looks around for a broom, sweeps left and right, clean
    Set-Lunch $false 3 0; Set-Happy ($k -gt 160)
    if ($k -le 88) { Set-Crumbs 2; Set-Broom $false 0 0; Set-Eyes -1 5 $false }
    elseif ($k -le 100) { Set-Crumbs 2; Set-Broom $false 0 0; Set-Clue '?'; Set-Eyes 1 2 $false }
    elseif ($k -le 112) { Set-Crumbs 2; Set-Broom $false 0 0; Set-Clue '?'; Set-Eyes -1 2 $false }
    elseif ($k -le 122) { Set-Crumbs 2; Set-Clue '!'; Set-Broom $true 0 ([int][Math]::Min(0, -3 + [Math]::Floor(($k - 113) / 3))); Set-Eyes 0 4 $false }
    elseif ($k -le 160) {
      $right = [Math]::Floor(($k - 123) / 6) % 2 -eq 1
      if ($right) { Set-Broom $true 2 0 } else { Set-Broom $true -2 0 }
      if ($k -le 134) { Set-Crumbs 2 } elseif ($k -le 148) { Set-Crumbs 3 } else { Set-Crumbs 0 }
      Set-Puff ($right -and $k -gt 134); Set-Eyes -1 5 $false
    }
    else { Set-Crumbs 0; Set-Broom $true 0 0 }
  }
  $S.eat++
  return $true
}
# sunbath: laptop away, the deck chair slides in, the umbrella comes up and opens, he lies back with his cocktail; then all of it backwards
function Start-Sun {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  $S.state = 'sun'; $S.sunPhase = 'down'; $S.sunT = 0
}
function End-Sun {
  Set-SunBody $false 0 $false; Set-SunProps $false 0 20 $false; Set-SunHeart $false
  $S.sunPhase = ''; $S.nextSun = Rand 5000 9000
}
function Sun-Tick {
  $S.sunT++; $k = $S.sunT
  Set-SunHeart $false
  if ($S.sunPhase -eq 'down') {
    Set-Paws 0 0 $false $false; Set-Eyes 0 3 $false; $bob.Y = 0
    if ($k % 2 -eq 0 -and $S.lv -gt 0) { $S.lv--; Set-Laptop $S.lv }
    if ($S.lv -le 0 -and $k -ge 10) { $S.sunPhase = 'chair'; $S.sunT = 0 }
  }
  elseif ($S.sunPhase -eq 'chair') {
    $dx = [int][Math]::Min(0, -8 + [Math]::Floor($k / 2))
    Set-SunProps $true $dx 20 $false; Set-Legs -1; Set-Eyes -1 2 $false   # looks at the chair he pulls in
    if ($dx -ge 0) { $S.sunPhase = 'umb'; $S.sunT = 0 }
  }
  elseif ($S.sunPhase -eq 'umb') {
    $dy = [int][Math]::Max(0, 20 - 2 * $k)
    Set-SunProps $true 0 $dy $false; Set-Eyes 0 2 $false
    if ($dy -le 0) { $S.sunPhase = 'open'; $S.sunT = 0 }
  }
  elseif ($S.sunPhase -eq 'open') {
    Set-SunProps $true 0 0 ($k -ge 4)
    if ($k -ge 8) { $S.sunPhase = 'lie'; $S.sunT = 0; $S.sunLen = Rand 700 1300 }
  }
  elseif ($S.sunPhase -eq 'lie') {
    Set-SunProps $true 0 0 $true
    $sip = 0; if (($k % 150) -ge 100 -and ($k % 150) -lt 120) { $sip = 1 }   # a sip every ten seconds or so
    Set-SunBody $true $sip $false
    if ($k -ge $S.sunLen) { $S.sunPhase = 'up'; $S.sunT = 0 }
  }
  else {
    # gets up, the umbrella closes and goes down, the chair slides away, then the laptop comes back
    Set-SunBody $false 0 $false; Set-Legs -1; Set-Eyes 0 2 $false; $bob.Y = 0
    if ($k -le 6) { Set-SunProps $true 0 0 $false }
    elseif ($k -le 16) { Set-SunProps $true 0 (2 * ($k - 6)) $false }
    elseif ($k -le 32) { Set-SunProps $true ([int](-[Math]::Floor(($k - 16) / 2))) 20 $false }
    else { End-Sun; $S.state = 'unpack' }
  }
}
# music: puts the laptop away, headphones come down, dances with his eyes closed, then back to work
function Start-Music {
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  $S.state = 'music'; $S.musicPhase = 'down'; $S.musicT = 0
}
function End-Music {
  Set-Phones $false 0; Set-CupLift $false; Set-MusicEyes $false; Set-Notes 0; Set-Legs -1; $bob.Y = 0
  $S.musicPhase = ''; $S.nextMusic = Rand (10 * $MIN) (20 * $MIN)
}
function Music-Tick {
  $S.musicT++; $k = $S.musicT
  if ($S.musicPhase -eq 'down') {
    Set-Paws 0 0 $false $false; Set-Eyes 0 3 $false; $bob.Y = 0
    if ($k % 2 -eq 0 -and $S.lv -gt 0) { $S.lv--; Set-Laptop $S.lv }
    if ($S.lv -le 0 -and $k -ge 10) { $S.musicPhase = 'on'; $S.musicT = 0 }
  }
  elseif ($S.musicPhase -eq 'on') {
    $dy = [int][Math]::Min(0, -4 + [Math]::Floor($k / 2))
    Set-Phones $true $dy; Set-CupLift $false; Set-Eyes 0 2 $false; Set-Legs -1; $bob.Y = 0
    if ($dy -ge 0) { $S.musicPhase = 'dance'; $S.musicT = 0; $S.musicLen = Rand 550 1000 }
  }
  elseif ($S.musicPhase -eq 'dance') {
    Set-Phones $true 0; Set-CupLift $false
    Set-MusicEyes (-not $S.cool)   # with sunglasses on the eyes stay behind them
    # one step every 5 ticks: left foot up, down and bounce, right foot up, down and bounce
    $beat = [int]([Math]::Floor($k / 5) % 4)
    if ($beat -eq 0) { Set-Legs 0; $bob.Y = 0 } elseif ($beat -eq 2) { Set-Legs 1; $bob.Y = 0 } else { Set-Legs -1; $bob.Y = $PX }
    Set-Notes ([int]([Math]::Floor($k / 10) % 5))
    if ($k -ge $S.musicLen) { $S.musicPhase = 'off'; $S.musicT = 0 }
  }
  else {
    # headphones go up and away, then he gets the laptop out
    Set-MusicEyes $false; Set-Notes 0; Set-Legs -1; $bob.Y = 0; Set-Eyes 0 3 $false
    Set-Phones ($k -lt 8) ([int](-1 - [Math]::Floor($k / 2)))
    if ($k -ge 10) { End-Music; $S.state = 'unpack' }
  }
}
function Nap-Tick {
  $S.napT++; $k = $S.napT
  if ($S.napPhase -eq 'down') {
    Set-Paws 0 0 $false $false; Set-Eyes 0 4 $true; $bob.Y = 0   # sleepy eyes
    if ($k % 2 -eq 0 -and $S.lv -gt 0) { $S.lv--; Set-Laptop $S.lv }
    if ($S.lv -le 0 -and $k -ge 14) { Set-Nap $true; Set-NapEyes 0; Set-Zz 0; Set-Breath 0; $S.napPhase = 'fall'; $S.napT = 0 }
  }
  elseif ($S.napPhase -eq 'fall') {
    $dy = [int][Math]::Min(0, -5 + [Math]::Floor($k / 2))
    Set-Book $true $dy; Set-NapEyes 0; Set-Zz 0; Set-Breath 0
    if ($dy -ge 0) { $S.napPhase = 'sleep'; $S.napT = 0; $S.napLen = Rand 550 1100 }
  }
  elseif ($S.napPhase -eq 'sleep') {
    Set-Book $true 0; Set-NapEyes 0
    Set-Breath ([int]([Math]::Floor($k / 18) % 2))
    Set-Zz ([int]([Math]::Floor($k / 10) % 5))
    if ($k -ge $S.napLen) { $S.napPhase = 'up'; $S.napT = 0 }
  }
  else {
    # wakes up: eyes open, the book flies off, then he stands up and gets the laptop out
    Set-Zz 0; Set-Breath 0; Set-NapEyes 2
    Set-Book ($k -lt 8) ([int](-1 - [Math]::Floor($k / 2)))
    if ($k -ge 14) { End-Nap; Set-Eyes 0 3 $false; $S.state = 'unpack' }
  }
}
# returns $true while he has the mug in his hand
function Coffee-Tick {
  if ($S.cup -le 0) {
    if (-not $S.cool -and $S.shadeStep -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '') { $S.nextCup--; if ($S.nextCup -le 0) { $S.cup = 1 } }
    if ($S.cup -le 0) { return $false }
  }
  $k = $S.cup
  if ($k -gt 140) { End-Coffee; return $false }
  $sip = ($k -gt 40 -and $k -le 66) -or ($k -gt 100 -and $k -le 120)
  $dy = 0; if ($sip) { $dy = -1 }
  Set-Paws 0 0 $false $false
  Set-Cup $true 0 $dy
  Set-Steam ([Math]::Floor($k / 6))
  Set-Happy ($sip -or ($k -gt 66 -and $k -le 84))   # eyes still closed for a moment after the sip
  Set-Eyes 0 5 $false   # looking at the mug
  $bob.Y = 0
  $S.cup++
  return $true
}

# --- behaviour ------------------------------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(70)
$tickBody = {
  $S.t++
  $t = $S.t
  $check = $S.fresh -or ($t % 12 -eq 0)
  if ($t % 12 -eq 6) { Watch-Done; Watch-Claude; Weather-Tick; Watch-News }
  if ($t % 120 -eq 0) { $now = Get-Date; $S.hour = $now.Hour; $S.minute = $now.Hour * 60 + $now.Minute; $S.friday = $now.DayOfWeek -eq 'Friday'; if ($S.mealDay -ne $now.ToString('yyyy-MM-dd')) { New-MealDay } }
  if ($Log -and ($t % 6 -eq 0)) {
    $c = [PetWin]::GetRect($S.hwnd)
    Add-Content $Log ("{0} state={1} opacity={2} lv={3} rect=({4},{5})" -f $t, $S.state, $win.Opacity, $S.lv, $c.Left, $c.Top)
  }

  if ($S.blink -gt 0) { $S.blink-- }
  else {
    $S.blinkIn--
    # a blink is three ticks (about a fifth of a second, long enough to see); one in four is a double blink
    if ($S.blinkIn -le 0) { $S.blink = 3; if ((Rand 1 4) -eq 1) { $S.blinkIn = 5 } else { $S.blinkIn = Rand 40 90 } }
  }
  $blinking = $S.blink -gt 0
  $bang.Visibility = 'Hidden'
  Set-Sparkle $false
  Set-Heart $false
  Ambient-Tick

  # he stays on top of every window, even ones that also want to be on top (the taskbar, other overlays)
  if ($check -and $S.hwnd -ne [IntPtr]::Zero) { [PetWin]::KeepOnTop($S.hwnd) }

  if ($S.state -eq 'bye') { Bye-Tick }
  elseif ($S.state -eq 'greet') { Greet-Tick }
  elseif ($S.hover -and $win.Opacity -gt 0) {
    # caught! stop and look at you
    Set-Paws 0 0 $false $false
    Set-Legs -1
    Set-Eyes $S.dx 2 $blinking
    $bob.Y = 0
    if ($S.hop -gt 0) { $S.hop--; $bob.Y = -$PX; foreach ($lg in $legs) { Set-Top $lg[0] ($lg[1] - 1) }; Set-Paws 0 1 $false $false }
    if ($S.shadeStep -gt 0) { End-Shades }
    if ($S.state -eq 'nap' -and $S.napPhase -ne 'down') {
      # peeks out from under the book with one eye
      Set-Book $true -2; Set-NapEyes 1; Set-Zz 0; Set-Breath 0
      if ($S.bang -gt 0) { $S.bang--; $bang.Visibility = 'Visible' }
    }
    elseif ($S.state -eq 'sun' -and $S.sunPhase -eq 'lie') {
      # peeks over his sunglasses at you, a heart over the cocktail
      Set-SunBody $true 0 $true; Set-SunHeart $true
    }
    elseif ($S.state -eq 'music' -and $S.musicPhase -ne 'down') {
      # lifts one ear cup off and looks at you
      Set-Phones $true 0; Set-CupLift $true; Set-MusicEyes $false; Set-Notes 0
    }
    elseif ($S.cool) {
      Set-Shades $true 0 2; Show-Eyes $true; Set-Eyes $S.dx 3 $blinking   # looks at you over the glasses
      Set-Sparkle ([Math]::Floor($t / 4) % 2 -eq 0)
    }
    elseif ($S.flag -gt 0) {
      # confetti!
      Set-ArmUp $true; Set-Flag $true 0 ([int]([Math]::Floor($t / 3) % 2)); Set-Confetti $true; Set-Happy (-not $S.cool)
    }
    elseif ($S.pay -gt 0) {
      # pulls the bill up to show you, all the dollar signs at once
      Set-Wallet $true -2; Set-PaySpark 3; Set-Happy $true
    }
    elseif ($S.dream -gt 0) {
      # a heart in the bubble, just for you
      Set-Chin $true; Set-Bubble 2 0 'heart'; Set-Happy $true
    }
    elseif ($S.act -ne '') {
      # a scene, the newspaper or the popcorn: he goes on with it, only looking at you
    }
    elseif ($S.eat -gt 0 -and $S.eat -le 62) {
      # offers you a bite
      $b = 0; if ($S.eat -gt 46) { $b = 2 } elseif ($S.eat -gt 20) { $b = 1 }
      Set-Broom $false 0 0; Set-Lunch $true $b -2 $S.food; Set-Happy $true; Set-Heart $true
    }
    elseif ($S.eat -gt 62) {
      # proud of the clean laptop, broom in hand
      Set-Lunch $false 3 0; Set-Clue ''; Set-Puff $false; Set-Broom $true 0 0; Set-Happy $true
    }
    elseif ($S.bug -gt 0) {
      # shows you the bug in the jar: caught, fixed
      Set-Bug $false 0 0; Set-Jar 'up' 0; Set-Tick $true; Set-Happy $true
    }
    elseif ($S.det -gt 8 -and $S.det -le 100) {
      # the big eye in the glass looks right at you
      Set-Deer $true 0; Set-Lens $true -1 0; Set-Clue '!'
    }
    elseif ($S.wizPhase -ne '' -and $S.cup -eq 0) {
      # all the sparkles and a wink
      Set-Hat $true 0; Set-Wand $true 3; Set-Wink $true
    }
    elseif ($S.cup -gt 0) {
      # raises the mug to you, cheers! and a little heart
      Set-Cup $true 0 -2; Set-Happy $true; Set-Steam ([Math]::Floor($t / 6))
      Set-Heart ([Math]::Floor($t / 5) % 3 -ne 0)
    }
    elseif ($S.bang -gt 0) { $S.bang--; $bang.Visibility = 'Visible' }
  }
  elseif ($S.state -eq 'hidden') {
    # only at the start: he comes in from the right edge of his screen with the laptop under his arm and says hi
    $win.Opacity = 0
    $spot = Get-HomeSpot
    $S.fresh = $false
    $S.lv = 0; Set-Laptop 0
    [PetWin]::MoveTo($S.hwnd, (Get-MyScreen).Right, $spot.y)
    $S.greet = $true
    Start-Walk $spot.x $spot.y
  }
  elseif ($S.state -eq 'pack') {
    if ($S.shadeStep -gt 0) { End-Shades }
    if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
    Set-ArmUp $false
    Set-Paws 0 0 $false $false
    Set-Eyes 0 2 $blinking
    $bob.Y = 0
    if ($t % 2 -eq 0 -and $S.lv -gt 0) { $S.lv--; Set-Laptop $S.lv }
    if ($S.lv -le 0) { Start-Walk $S.target.x $S.target.y }
  }
  elseif ($S.state -eq 'walk') {
    if ($win.Opacity -lt 1) { $win.Opacity = [Math]::Min(1.0, $win.Opacity + 0.2) }
    $wp = $S.path[0]
    $ddx = $wp.x - $S.px; $ddy = $wp.y - $S.py
    $dist = [Math]::Sqrt($ddx * $ddx + $ddy * $ddy)
    if ($wp.hop -or $dist -le $S.speed) { $S.px = $wp.x; $S.py = $wp.y; $S.path.RemoveAt(0) }
    else { $S.px += $ddx / $dist * $S.speed; $S.py += $ddy / $dist * $S.speed }
    if ($ddx -gt 0.5) { $flip.ScaleX = -1 } elseif ($ddx -lt -0.5) { $flip.ScaleX = 1 }
    [PetWin]::MoveTo($S.hwnd, [int]$S.px, [int]$S.py)
    Set-Legs ([int][Math]::Floor($t / 3) % 2)
    Set-Eyes -1 2 $blinking
    $bob.Y = ([int][Math]::Floor($t / 3) % 2) * $PX
    if ($S.path.Count -eq 0) { Set-Legs -1; $flip.ScaleX = 1; if ($S.greet) { $S.greet = $false; $S.state = 'greet'; $S.byeT = 0 } else { $S.state = 'unpack' } }
  }
  elseif ($S.state -eq 'unpack') {
    Set-LaptopTuck $false
    Set-Eyes 0 3 $blinking
    $bob.Y = 0
    if ($t % 2 -eq 0) { $S.lv++; Set-Laptop $S.lv }
    if ($S.lv -ge 4) { $S.state = 'code'; $win.Opacity = 1; Set-Paws 0 0 $false $false }
  }
  elseif ($S.state -eq 'nap') {
    if ($S.waiting -and ($S.napPhase -eq 'fall' -or $S.napPhase -eq 'sleep')) { $S.napPhase = 'up'; $S.napT = 0 }   # you are needed: wake up
    Nap-Tick
  }
  elseif ($S.state -eq 'music') {
    if ($S.waiting -and ($S.musicPhase -eq 'on' -or $S.musicPhase -eq 'dance')) { $S.musicPhase = 'off'; $S.musicT = 0 }
    Music-Tick
  }
  elseif ($S.state -eq 'sun') {
    if ($S.waiting -and $S.sunPhase -eq 'lie') { $S.sunPhase = 'up'; $S.sunT = 0 }
    Sun-Tick
  }
  else {
    # coding
    if ($S.calm -gt 0) { $S.calm-- }
    if ($S.waiting -or $S.calm -gt 0) {
      # Claude Code waits for you, or he has just done something: nothing new starts on its own (while Claude Code works he goes on as usual: that is when you watch him)
      # (each counter below goes down one, this puts it back)
      foreach ($n in 'nextNap', 'nextSun', 'nextMusic', 'nextCool', 'nextCup', 'nextDream', 'nextPay', 'nextWiz', 'nextDet', 'nextBug') { $S[$n]++ }
    }
    else {
      # the time of day: coffee in the morning, a nap after lunch, music in the evening, the beach on Friday afternoon
      if ($S.hour -ge 8 -and $S.hour -lt 11) { $S.nextCup-- }
      if ($S.hour -ge 13 -and $S.hour -lt 15) { $S.nextNap-- }
      if ($S.hour -ge 18) { $S.nextMusic-- }
    }
    if ($S.cup -eq 0 -and $S.shadeStep -eq 0) { $S.nextNap--; if ($S.nextNap -le 0) { Start-Nap } }
    if ($S.state -eq 'code' -and $S.cup -eq 0 -and $S.dream -eq 0 -and $S.pay -eq 0 -and $S.flag -eq 0 -and $S.wizPhase -eq '' -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '' -and $S.shadeStep -eq 0) { if (-not $S.sunDone -and $S.minute -ge $S.sunAt -and $S.minute -lt 1140) { $S.sunDone = $true; Start-Sun } }
    if ($S.state -eq 'code' -and $S.cup -eq 0 -and $S.shadeStep -eq 0 -and -not $S.cool) { $S.nextMusic--; if ($S.nextMusic -le 0) { Start-Music } }
    if (Call-Tick) { }
    elseif (Shades-Tick) { }
    elseif (Flag-Tick) { }
    elseif (Wizard-Tick) { }
    elseif (Det-Tick) { }
    elseif (Bug-Tick) { }
    elseif (Meal-Tick) { }
    elseif (Act-Tick) { }
    elseif (Coffee-Tick) { }
    elseif (Dream-Tick) { }
    elseif (Pay-Tick) { }
    elseif ($S.glance -gt 0) {
      # looks up from the screen for a moment
      $S.glance--
      Set-Paws 0 0 $false $false
      Set-Eyes $S.glanceDx 2 $blinking
      $bob.Y = 0
    }
    else {
      $S.nextGlance--
      if ($S.nextGlance -le 0) { $S.glance = 24; $S.glanceDx = Get-Random -InputObject @(-1, 0, 1); $S.nextGlance = Rand 150 300 }
      Type-Tick
      Set-Eyes 0 4 $blinking   # looking down at the laptop
    }
    # the normal eyes back, unless happy ^ ^ eyes (flag, payday) or a wink, a lens or a mug are in their place
    $eyesFree = $S.shadeStep -eq 0 -and $S.cup -eq 0 -and $S.spell -eq 0 -and $S.det -eq 0 -and $S.bug -eq 0 -and $S.eat -eq 0 -and $S.act -eq '' -and $happy.Visibility -ne 'Visible'
    if ($eyesFree) { Show-Eyes (-not $S.cool); if ($S.cool) { Set-Shades $true 0 0 } }
  }

  # a pose just ended: 2 minutes of plain typing before the next random one (the laptop stays his normal place)
  $posing = $S.state -eq 'nap' -or $S.state -eq 'music' -or $S.state -eq 'sun' -or $S.cool -or $S.shadeStep -gt 0 -or $S.cup -gt 0 -or $S.dream -gt 0 -or $S.pay -gt 0 -or $S.flag -gt 0 -or $S.wizPhase -ne '' -or $S.det -gt 0 -or $S.bug -gt 0 -or $S.eat -gt 0 -or $S.act -ne ''
  if ($S.wasPosing -and -not $posing) { $S.calm = 2 * $MIN }
  $S.wasPosing = $posing

  foreach ($g in @($floaters)) {
    $g.life++
    $g.y -= 1.2
    [System.Windows.Controls.Canvas]::SetTop($g.el, $g.y)
    $g.el.Opacity = [Math]::Max(0.0, 1 - $g.life / 22)
    if ($g.life -ge 22) { $scene.Children.Remove($g.el); $floaters.Remove($g) }
  }
}
# an error in one tick goes to pet.log (the same one at most once a minute) and he carries on with the next tick
$timer.Add_Tick({
  try { . $tickBody }
  catch {
    $msg = "error: $($_.Exception.Message) at line $($_.InvocationInfo.ScriptLineNumber)"
    if ($msg -ne $S.lastErr -or $S.t - $S.lastErrT -gt 850) { Write-PetLog $msg; $S.lastErr = $msg; $S.lastErrT = $S.t }
  }
})

$scene.Add_MouseEnter({
  if (-not $S.hover) { $S.hover = $true; $S.bang = 15; $S.hop = 3 }
})
$scene.Add_MouseLeave({ $S.hover = $false })
$scene.Add_MouseMove({
  param($src, $ev)
  $x = $ev.GetPosition($scene).X
  $cx = 11 * $PX
  if ($x -lt $cx - 3 * $PX) { $S.dx = -1 }
  elseif ($x -gt $cx + 3 * $PX) { $S.dx = 1 }
  else { $S.dx = 0 }
})
$scene.Add_MouseLeftButtonDown({
  param($src, $ev)
  # a double click: he does something at random from the "Do something" menu
  if ($ev.ClickCount -ge 2) {
    $items = @($miDo.Items | Where-Object { $_ -is [System.Windows.Controls.MenuItem] -and $_.Items.Count -eq 0 }) + @($miWeather.Items)
    $pick = Get-Random -InputObject $items
    $pick.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.MenuItem]::ClickEvent)))
    return
  }
  if ($S.state -eq 'bye') { return }
  try { $win.DragMove() } catch {}
  if ($S.state -eq 'nap') { End-Nap }
  if ($S.state -eq 'music') { End-Music }
  if ($S.state -eq 'sun') { End-Sun }
  if ($S.dream -gt 0) { End-Dream }
  if ($S.pay -gt 0) { End-Pay }
  if ($S.flag -gt 0) { End-Flag }
  if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  $S.lv = 4; Set-Laptop 4; Set-LaptopTuck $false; Set-Legs -1; $flip.ScaleX = 1
  $S.state = 'code'
})

$menu = New-Object System.Windows.Controls.ContextMenu
# "Screen": pick the screen he lives on; he packs up, walks there and stays (also after a restart)
$miHome = New-Object System.Windows.Controls.MenuItem
$miHome.Header = 'Screen'
$miHome.Add_SubmenuOpened({
  $miHome.Items.Clear()
  $areas = @([PetWin]::WorkAreas()); $main = @([PetWin]::Primaries()); $mine = Get-MyScreen
  for ($i = 0; $i -lt $areas.Count; $i++) {
    $wa = $areas[$i]
    $it = New-Object System.Windows.Controls.MenuItem
    # named by where it stands, since Windows' own screen numbers don't follow left to right
    $rank = @($areas | Where-Object { $_.Left -lt $wa.Left }).Count
    if ($areas.Count -eq 1) { $label = 'This screen' }
    elseif ($areas.Count -eq 2) { $label = @('Left screen', 'Right screen')[$rank] }
    else { $label = 'Screen {0} from the left' -f ($rank + 1) }
    if ($main[$i]) { $label += ' (main)' }
    $it.Header = $label; $it.Tag = $i
    $it.IsCheckable = $true; $it.IsChecked = ($wa.Left -eq $mine.Left -and $wa.Top -eq $mine.Top)
    $it.Add_Click({
      param($src, $ev)
      Save-MyScreen ([int]$src.Tag)
      $spot = Get-HomeSpot
      if ($S.state -eq 'nap') { End-Nap }; if ($S.state -eq 'music') { End-Music }; if ($S.state -eq 'sun') { End-Sun }
      $S.target = $spot; $S.state = 'pack'
    })
    [void]$miHome.Items.Add($it)
  }
})
[void]$miHome.Items.Add((New-Object System.Windows.Controls.MenuItem))   # a placeholder, so the submenu arrow shows
$miQuit = New-Object System.Windows.Controls.MenuItem
$miQuit.Header = 'Bye, Claude'
$miQuit.Add_Click({ Start-Bye })
[void]$menu.Items.Add($miHome)
$miShades = New-Object System.Windows.Controls.MenuItem
$miShades.Header = 'Sunglasses on / off'
$miShades.Add_Click({ if ($S.shadeStep -eq 0 -and $S.state -eq 'code') { Start-Shades (-not $S.cool) } })
[void]$menu.Items.Add($miShades)
$miCoffee = New-Object System.Windows.Controls.MenuItem
$miCoffee.Header = 'Coffee break'
$miCoffee.Add_Click({
  if ($S.state -ne 'code' -or $S.cup -gt 0 -or $S.shadeStep -gt 0) { return }
  if ($S.cool) { $S.wantCup = $true; Start-Shades $false } else { $S.cup = 1 }
})
[void]$menu.Items.Add($miCoffee)
$miNap = New-Object System.Windows.Controls.MenuItem
$miNap.Header = 'Nap / wake up'
$miNap.Add_Click({
  if ($S.state -eq 'nap') { if ($S.napPhase -eq 'fall' -or $S.napPhase -eq 'sleep') { $S.napPhase = 'up'; $S.napT = 0 } }
  elseif ($S.state -eq 'code' -and $S.shadeStep -eq 0) { Start-Nap }
})
[void]$menu.Items.Add($miNap)
$miMusic = New-Object System.Windows.Controls.MenuItem
$miMusic.Header = 'Music on / off'
$miMusic.Add_Click({
  if ($S.state -eq 'music') { if ($S.musicPhase -eq 'on' -or $S.musicPhase -eq 'dance') { $S.musicPhase = 'off'; $S.musicT = 0 } }
  elseif ($S.state -eq 'code' -and $S.shadeStep -eq 0) { Start-Music }
})
[void]$menu.Items.Add($miMusic)
$miDream = New-Object System.Windows.Controls.MenuItem
$miDream.Header = 'Daydream'
$miDream.Add_Click({
  if ($S.state -ne 'code' -or $S.dream -gt 0 -or $S.shadeStep -gt 0) { return }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.pay -gt 0) { End-Pay }
  $S.dream = 1
})
[void]$menu.Items.Add($miDream)
$miPay = New-Object System.Windows.Controls.MenuItem
$miPay.Header = 'Payday'
$miPay.Add_Click({
  if ($S.state -ne 'code' -or $S.pay -gt 0 -or $S.shadeStep -gt 0) { return }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }
  $S.pay = 1
})
[void]$menu.Items.Add($miPay)
$miFlag = New-Object System.Windows.Controls.MenuItem
$miFlag.Header = 'Task done!'
$miFlag.Add_Click({ if ($S.state -eq 'code' -and $S.flag -eq 0 -and $S.shadeStep -eq 0) { Start-Flag } })
[void]$menu.Items.Add($miFlag)
$miWiz = New-Object System.Windows.Controls.MenuItem
$miWiz.Header = 'Wizard hat on / off'
$miWiz.Add_Click({
  if ($S.state -ne 'code' -or $S.shadeStep -gt 0) { return }
  if ($S.wizPhase -eq 'stay') { $S.spell = 0; Set-Wand $false 0; Set-Wink $false; $S.wizPhase = 'off'; $S.wizT = 0 }
  elseif ($S.wizPhase -eq '') {
    if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
    if ($S.cool) { $S.wantWiz = $true; Start-Shades $false } else { Start-Wizard }
  }
})
[void]$menu.Items.Add($miWiz)
$miDet = New-Object System.Windows.Controls.MenuItem
$miDet.Header = 'Detective'
$miDet.Add_Click({
  if ($S.state -ne 'code' -or $S.det -gt 0 -or $S.shadeStep -gt 0 -or $S.cool -or $S.wizPhase -ne '') { return }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
  $S.det = 1
})
[void]$menu.Items.Add($miDet)
$miBug = New-Object System.Windows.Controls.MenuItem
$miBug.Header = 'Bug hunt'
$miBug.Add_Click({
  if ($S.state -ne 'code' -or $S.bug -gt 0 -or $S.det -gt 0 -or $S.shadeStep -gt 0 -or $S.cool -or $S.wizPhase -ne '') { return }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }
  $S.bug = 1
})
[void]$menu.Items.Add($miBug)
# acts from the menu, any time: the weather scenes in their own submenu, the newspaper, the popcorn
function New-ActItem([string]$header, [string]$act) {
  $it = New-Object System.Windows.Controls.MenuItem
  $it.Header = $header; $it.Tag = $act
  $it.Add_Click({
    param($src, $ev)
    if ($S.state -ne 'code' -or $S.act -ne '' -or $S.eat -gt 0 -or $S.bug -gt 0 -or $S.det -gt 0 -or $S.shadeStep -gt 0 -or $S.cool -or $S.wizPhase -ne '') { return }
    Start-Act ([string]$src.Tag)
  })
  $it
}
$miWeather = New-Object System.Windows.Controls.MenuItem
$miWeather.Header = 'Weather'
foreach ($p in @(@('Snow', 'w:snow'), @('Heat', 'w:heat'), @('Clouds', 'w:cloudy'), @('Fog', 'w:fog'), @('Drizzle', 'w:drizzle'), @('Rain', 'w:rain'), @('Storm', 'w:storm'), @('Wind', 'w:wind'), @('Cold', 'w:cold'))) {
  [void]$miWeather.Items.Add((New-ActItem $p[0] $p[1]))
}
$miNews = New-ActItem 'Newspaper' 'news'
$miPop = New-ActItem 'Popcorn' 'pop'
# croissant and sandwich from the menu, any time of day
$miCroissant = New-Object System.Windows.Controls.MenuItem
$miCroissant.Header = 'Croissant'
$miCroissant.Add_Click({
  if ($S.state -ne 'code' -or $S.eat -gt 0 -or $S.bug -gt 0 -or $S.det -gt 0 -or $S.shadeStep -gt 0 -or $S.cool -or $S.wizPhase -ne '') { return }
  Start-Meal 'croissant'
})
$miSandwich = New-Object System.Windows.Controls.MenuItem
$miSandwich.Header = 'Sandwich'
$miSandwich.Add_Click({
  if ($S.state -ne 'code' -or $S.eat -gt 0 -or $S.bug -gt 0 -or $S.det -gt 0 -or $S.shadeStep -gt 0 -or $S.cool -or $S.wizPhase -ne '') { return }
  Start-Meal 'sandwich'
})
$miSun = New-Object System.Windows.Controls.MenuItem
$miSun.Header = 'Sunbath / get up'
$miSun.Add_Click({
  if ($S.state -eq 'sun') { if ($S.sunPhase -eq 'lie') { $S.sunPhase = 'up'; $S.sunT = 0 } }
  elseif ($S.state -eq 'code' -and $S.shadeStep -eq 0) { Start-Sun }
})
[void]$menu.Items.Add($miSun)
[void]$menu.Items.Add($miQuit)
# short menu: the corner, the poses in one submenu, bye
$menu.Items.Clear()
$miDo = New-Object System.Windows.Controls.MenuItem
$miDo.Header = 'Do something'
foreach ($m in @($miCoffee, $miCroissant, $miSandwich, $miDream, $miShades, $miWiz, $miDet, $miBug, $miNews, $miPop, $miPay, $miFlag, $miNap, $miMusic, $miSun, $miWeather)) { [void]$miDo.Items.Add($m) }
[void]$menu.Items.Add($miHome)
[void]$menu.Items.Add($miDo)
[void]$menu.Items.Add((New-Object System.Windows.Controls.Separator))
[void]$menu.Items.Add($miQuit)
$scene.ContextMenu = $menu

$win.Add_SourceInitialized({
  # keep it out of Alt+Tab
  $h = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
  $ex = [PetWin]::GetWindowLong($h, -20)
  [void][PetWin]::SetWindowLong($h, -20, (($ex -bor 0x80) -band (-bnot 0x40000)))
})
$win.Add_Loaded({
  $S.hwnd = (New-Object System.Windows.Interop.WindowInteropHelper $win).Handle
  $r = [PetWin]::GetRect($S.hwnd)
  $S.w = $r.Right - $r.Left
  $S.h = $r.Bottom - $r.Top
  $S.margin = [int](40 * $S.w / $win.Width)
  $S.speed = 10.0 * $S.w / $win.Width
  Set-Laptop 4; Set-Paws 0 0 $false $false; Scroll-Code 0
  $bang.Visibility = 'Hidden'
  $timer.Start()
})

if ($TestSeconds -gt 0) {
  $stop = New-Object System.Windows.Threading.DispatcherTimer
  $stop.Interval = [TimeSpan]::FromSeconds($TestSeconds)
  $stop.Add_Tick({ $stop.Stop(); $timer.Stop(); $win.Close() })
  $stop.Start()
}

# any other error that reaches the window: log it and keep him alive
$win.Dispatcher.Add_UnhandledException({
  param($from, $ev)
  Write-PetLog "unhandled: $($ev.Exception.Message)"
  $ev.Handled = $true
})

[void]$win.ShowDialog()
$mutex.ReleaseMutex()
# exit 0 = you said bye (the launcher stops); anything else = he closed by himself (the launcher starts him again)
if ($script:byeChosen -or $TestSeconds -gt 0) { Write-PetLog 'bye (from the menu)'; exit 0 }
Write-PetLog 'window closed without bye'
exit 3
