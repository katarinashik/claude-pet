' Lives in the Windows Startup folder. Starts the installed pet launcher at logon.
' On 2026-10-30 the plain shortcut ran before %LOCALAPPDATA%\ClaudePet could be read and showed
' "Can not find script file": so this waits for the launcher, up to two minutes, and then stays quiet.
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
launcher = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\ClaudePet\Start-ClaudePet.vbs"
For i = 1 To 24
  If fso.FileExists(launcher) Then
    sh.Run "wscript.exe """ & launcher & """", 0, False
    WScript.Quit 0
  End If
  WScript.Sleep 5000
Next
