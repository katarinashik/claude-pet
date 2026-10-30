# Plays every pose of the pet once, in a copy that runs next to the real one, and reports what broke.
#   powershell -Sta -NoProfile -File tools\Test-AllPoses.ps1 [-Ticks 220]
# The copy: its own lock and window type, a faster clock (15 ms a tick), its log in a temp folder, no Windows files touched.
# For every item of the right-click menu (Do something, Weather, the top-level poses) it puts him back at the laptop,
# clicks the item, lets it play for -Ticks ticks and notes what he is doing. At the end it says "Bye, Claude".
# Checks: no error in the log, every item started something, after each reset nothing is left on screen
# (laptop under the arm, laptop on the floor), the goodbye closes the window with exit code 0.
param([int]$Ticks = 220)
$root = Split-Path $PSScriptRoot
$work = Join-Path $env:TEMP 'claudepet-test'
New-Item -ItemType Directory -Force $work | Out-Null
$log = Join-Path $work 'test.log'; if (Test-Path $log) { Remove-Item $log }

$src = [IO.File]::ReadAllText((Join-Path $root 'ClaudePet.ps1')).Replace("`r`n", "`n")
function Swap([string]$a, [string]$b) {
  if (-not $script:src.Contains($a)) { throw "the test can't find this line in ClaudePet.ps1 any more: $a" }
  $script:src = $script:src.Replace($a, $b)
}
Swap "'Local\ClaudeDesktopPet'" "'Local\ClaudePetTest'"
Swap 'public static class PetWin' 'public static class PetWinTest'
$src = $src.Replace('[PetWin]::', '[PetWinTest]::')
# its own log, written in test mode too
Swap "`$petLog = Join-Path `$petDir 'pet.log'" "`$petLog = '$log'"
Swap "function Write-PetLog([string]`$msg) {`n  if (`$TestSeconds -gt 0) { return }" "function Write-PetLog([string]`$msg) {"
Swap "if (`$script:byeChosen -or `$TestSeconds -gt 0) { Write-PetLog 'bye (from the menu)'; exit 0 }" "if (`$script:byeChosen) { Write-PetLog 'bye (from the menu)'; exit 0 }`nif (`$TestSeconds -gt 0) { exit 4 }"

$driver = @'
# --- the test driver ---
$timer.Interval = [TimeSpan]::FromMilliseconds(15)
$T = @{ items = New-Object System.Collections.ArrayList; i = -1; at = 0; started = $false }
function Walk-Menu($items, [string]$path) {
  foreach ($it in $items) {
    if ($it -isnot [System.Windows.Controls.MenuItem]) { continue }
    $name = [string]$it.Header
    if ($name -eq 'Bye, Claude' -or $name -eq 'Screen' -or $name -eq '') { continue }
    if ($it.Items.Count -gt 0) { Walk-Menu $it.Items "$path$name > " } else { [void]$T.items.Add(@{ name = "$path$name"; item = $it }) }
  }
}
function Reset-Pet {
  if ($S.state -eq 'nap') { End-Nap }; if ($S.state -eq 'music') { End-Music }; if ($S.state -eq 'sun') { End-Sun }
  if ($S.shadeStep -gt 0) { End-Shades }
  if ($S.cup -gt 0) { End-Coffee }; if ($S.dream -gt 0) { End-Dream }; if ($S.pay -gt 0) { End-Pay }; if ($S.flag -gt 0) { End-Flag }; if ($S.wizPhase -ne '') { End-Wizard }; if ($S.det -gt 0) { End-Det }; if ($S.bug -gt 0) { End-Bug }; if ($S.eat -gt 0) { End-Meal }; if ($S.act -ne '') { End-Act }
  $S.lv = 4; Set-Laptop 4; Set-LaptopTuck $false; Set-Legs -1; $flip.ScaleX = 1; Set-ArmUp $false
  $S.state = 'code'; $S.calm = 0
}
function Busy-Now { $o = @(); foreach ($k in 'cup','dream','pay','flag','det','bug','eat','shadeStep') { if ($S[$k] -gt 0) { $o += $k } }; if ($S.wizPhase) { $o += 'wizard' }; if ($S.act) { $o += "act:$($S.act)" }; if ($S.cool) { $o += 'sunglasses' }; if ($S.state -ne 'code') { $o += "state:$($S.state)" }; ($o -join ',') }
$drive = {
  if ($S.state -eq 'hidden' -or $S.state -eq 'walk' -or $S.state -eq 'greet' -or $S.state -eq 'unpack') { return }
  if (-not $T.started) { $T.started = $true; Walk-Menu $menu.Items ''; Write-PetLog "TEST hello ok, at the laptop after $($S.t) ticks; $($T.items.Count) menu items to play"; $T.at = $S.t }
  if ($S.state -eq 'bye') { return }
  $since = $S.t - $T.at
  if ($T.i -ge 0 -and $since -eq 12) { Write-PetLog ("TEST after '{0}': {1}" -f $T.items[$T.i].name, $(if ((Busy-Now)) { Busy-Now } else { 'NOTHING' })) }
  if ($since -lt $Ticks -and $T.i -ge 0) { return }
  if ($since -lt 5) { return }
  Reset-Pet
  $left = @(@($laptopTuck) + @($laptopAside) | Where-Object { $_.Visibility -eq 'Visible' }).Count
  if ($left -gt 0 -and $T.i -ge 0) { Write-PetLog "TEST left on screen after '$($T.items[$T.i].name)': $left laptop pixels" }
  $T.i++
  if ($T.i -ge $T.items.Count) { Write-PetLog "TEST all $($T.items.Count) items played, saying bye"; Start-Bye; return }
  $T.at = $S.t
  $T.items[$T.i].item.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.MenuItem]::ClickEvent)))
}
'@
$driver = $driver.Replace('$Ticks', [string]$Ticks)
Swap "`$timer.Add_Tick({`n  try { . `$tickBody }" "$driver`n`$timer.Add_Tick({`n  try { . `$drive; . `$tickBody }"
$run = Join-Path $work 'pet-under-test.ps1'
[IO.File]::WriteAllText($run, $src)

$p = Start-Process powershell.exe -ArgumentList '-Sta', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$run`"", '-TestSeconds', '900' -WindowStyle Hidden -PassThru -Wait
$lines = @(Get-Content $log)
$errors = @($lines | Where-Object { $_ -match 'error|unhandled' })
$nothing = @($lines | Where-Object { $_ -match "TEST after .*: NOTHING$" })
$left = @($lines | Where-Object { $_ -match 'TEST left on screen' })
$played = @($lines | Where-Object { $_ -match "TEST after " }).Count
$lines | Where-Object { $_ -match 'TEST|error|unhandled|bye' } | ForEach-Object { $_.Substring(21) }
''
"exit code: $($p.ExitCode) (0 = the goodbye closed him)"
"items played: $played   errors: $($errors.Count)   items that started nothing: $($nothing.Count)   leftovers: $($left.Count)"
if ($played -ge 10 -and $p.ExitCode -eq 0 -and $errors.Count -eq 0 -and $nothing.Count -eq 0 -and $left.Count -eq 0) { 'PASS' } else { 'FAIL' }
