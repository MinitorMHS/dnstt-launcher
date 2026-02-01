Set objShell = CreateObject("WScript.Shell") 
Set objFSO = CreateObject("Scripting.FileSystemObject")

strScriptPath = objFSO.GetParentFolderName(WScript.ScriptFullName)
strBinPath = objFSO.BuildPath(strScriptPath, "bin")

objShell.CurrentDirectory = strBinPath

objShell.Run "powershell -NoProfile -ExecutionPolicy Bypass -File ""launcher.ps1""", 0, False