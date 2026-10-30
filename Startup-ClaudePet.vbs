' Lives in the Windows Startup folder. Starts the installed pet launcher at logon.
' It waits for the launcher, up to two minutes, and then stays quiet instead of showing "Can not find script file".
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
launcher = sh.ExpandEnvironmentStrings("%USERPROFILE%") & "\ClaudePet\Start-ClaudePet.vbs"
For i = 1 To 24
  If fso.FileExists(launcher) Then
    sh.Run "wscript.exe """ & launcher & """", 0, False
    WScript.Quit 0
  End If
  WScript.Sleep 5000
Next
