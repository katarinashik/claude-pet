' Starts the Claude desktop pet without a console window, and starts him again if he closes by himself.
' He returns 0 when you choose "Bye, Claude" (or when another copy already runs): then this stops too.
' Anything else (a crash, a closed window) brings him back after 5 seconds, at most 20 times.
Set sh = CreateObject("WScript.Shell")
dir = CreateObject("Scripting.FileSystemObject").GetParentFolderName(WScript.ScriptFullName)
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File """ & dir & "\ClaudePet.ps1"""
restarts = 0
Do
  code = sh.Run(cmd, 0, True)
  If code = 0 Then Exit Do
  restarts = restarts + 1
  If restarts > 20 Then Exit Do
  WScript.Sleep 5000
Loop
