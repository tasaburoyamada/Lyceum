import Lean
import Init.System.IO
import Init.System.FilePath
import Lyceum.Core.Interface

namespace Lyceum.Core.Environment

open Lyceum.Core

/-- 実機 (IOモナド) 用の物理環境実装 -/
instance : TerminalEnv IO where
  print s := IO.print s
  println s := IO.println s
  readLine := do
    let line ← (← IO.getStdin).getLine
    return line.trimAscii.toString
  readChar := pure (0 : UInt8) -- Corrected type
  enableRawMode := pure (Except.ok false) -- Corrected type
  disableRawMode := pure ()
  isRawMode := pure false -- Corrected type
  spawnBrowser url := pure false -- Corrected type
  getTerminalSize := pure (0, 0) -- Corrected type
  loadHistory path := do
    if !(← path.pathExists) then
      return []
    let content ← IO.FS.readFile path
    return content.splitOn "
" |>.filter (!·.isEmpty)
  appendHistory path line := do
    if line.trimAscii.toString.isEmpty then return
    let h ← IO.FS.Handle.mk path .append
    h.putStrLn line
    h.flush
  readFile path := IO.FS.readFile path
  readBinFile path := IO.FS.readBinFile path
  writeFile path content := IO.FS.writeFile path content
  createDirAll path := IO.FS.createDirAll path
  rename old new := IO.FS.rename old new
  removeFile path := IO.FS.removeFile path
  pathExists path := path.pathExists
  writeBinFile path data := IO.FS.writeBinFile path data
  isDir path := path.isDir
  readDir path := do
    let entries ← path.readDir
    return entries.map (fun e => e.path) |>.toList
  getFileName path := pure (path.fileName.getD "")
  spawnProcess args := do
    try
      let child ← IO.Process.spawn { args with stdin := terminalStdioConfig.stdin, stdout := terminalStdioConfig.stdout, stderr := terminalStdioConfig.stderr }
      return .ok child
    catch e =>
      return .error (s!"Process spawn failed: {e}")
  getEnv var := IO.getEnv var
  getCurrentDir := IO.currentDir
  runProcess args := do
    try
      let out ← IO.Process.run { args with stdin := terminalStdioConfig.stdin, stdout := terminalStdioConfig.stdout, stderr := terminalStdioConfig.stderr }
      return .ok { exitCode := 0, stdout := out, stderr := "" }
    catch e =>
      return .error (s!"Process run failed: {e}")

end Lyceum.Core.Environment
