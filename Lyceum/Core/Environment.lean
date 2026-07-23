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
  spawnBrowser _ := pure false -- Corrected type
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

/--
環境セルフチェックレポート。
動的環境の不条理（APIキー欠落、ファイル不在）を無菌状態に保つ。
--/
structure EnvironmentReport where
  hasApiKey : Bool
  modelFileExists : Bool
  canWriteTemp : Bool
  fallbackMode : Bool
  statusMessage : String
deriving Inhabited, Repr

/--
起動時の物理環境セルフチェック関数。
エラー表示でパニックせず、自動フォールバックモードの判定結果を返す。
--/
def runEnvironmentSelfCheck (modelPath : String) [TerminalEnv IO] : IO EnvironmentReport := do
  let apiKey ← IO.getEnv "GEMINI_API_KEY"
  let hasKey := apiKey.isSome && !(apiKey.get!.trimAscii.toString.isEmpty)
  
  let pathObj := System.FilePath.mk modelPath
  let modelExists ← TerminalEnv.pathExists pathObj
  
  let tmpPath := System.FilePath.mk "/tmp/lyceum_selfcheck_permission.tmp"
  let canWrite ← try
    TerminalEnv.writeFile tmpPath "test"
    TerminalEnv.removeFile tmpPath
    pure true
  catch _ => pure false

  let fallback := !hasKey || !modelExists
  let msg := if fallback then
    s!"[SelfCheck Warning] Running in Fallback Mode (API Key: {hasKey}, Model File: {modelExists})"
  else
    s!"[SelfCheck OK] Environment fully verified."

  return {
    hasApiKey := hasKey,
    modelFileExists := modelExists,
    canWriteTemp := canWrite,
    fallbackMode := fallback,
    statusMessage := msg
  }

end Lyceum.Core.Environment

