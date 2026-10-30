# Claude Code "Stop" hook: a turn is over (in any session, scheduled routines too).
# done.txt: the turn is over, the pet waves his flag. Not for a turn that a background agent's report started
# (origin task-notification or peer): the session is still waiting for the rest of its agents. Unless that turn
# wrapped up (wrap_up), which means the work is done.
# ask.txt: only when that turn ended with a question for Katya, so the pet calls her with a "!".
# A question = buttons with a question at the end of the turn (wrap_up with an "ask"), a question dialog (AskUserQuestion),
# or the turn's last text ending in "?". Installed to %USERPROFILE%\ClaudePet\stop-hook.ps1.
$dir = Join-Path $env:USERPROFILE 'ClaudePet'
$stamp = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'
$asks = $false; $wrapped = $false; $byAgent = $false
try {
  $in = [Console]::In.ReadToEnd() | ConvertFrom-Json
  $lines = @(Get-Content -LiteralPath $in.transcript_path -Tail 300 -Encoding UTF8)
  $lastTextSeen = $false
  # walk back through this turn, up to the message that started it
  for ($i = $lines.Count - 1; $i -ge 0; $i--) {
    try { $o = $lines[$i] | ConvertFrom-Json } catch { continue }
    if ($o.type -eq 'user') {
      $c = $o.message.content
      if ($c -is [string] -or -not @($c | Where-Object { $_.type -eq 'tool_result' })) {
        $byAgent = $o.origin.kind -eq 'task-notification' -or $o.origin.kind -eq 'peer'
        break
      }
      continue
    }
    if ($o.type -ne 'assistant') { continue }
    $blocks = @($o.message.content)
    for ($j = $blocks.Count - 1; $j -ge 0; $j--) {
      $b = $blocks[$j]
      if ($b.type -eq 'tool_use' -and $b.name -like '*wrap_up') { $wrapped = $true; if ($b.input.ask) { $asks = $true } }
      if ($b.type -eq 'tool_use' -and $b.name -eq 'AskUserQuestion') { $asks = $true }
      if ($b.type -eq 'text' -and -not $lastTextSeen) {
        $lastTextSeen = $true
        if ($b.text.Trim().EndsWith('?')) { $asks = $true }
      }
    }
  }
} catch {}
if (-not $byAgent -or $wrapped) { Set-Content (Join-Path $dir 'done.txt') $stamp }
if ($asks) { Set-Content (Join-Path $dir 'ask.txt') $stamp }
