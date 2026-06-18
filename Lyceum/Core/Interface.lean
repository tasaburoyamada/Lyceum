import Lean
import Init.System.IO
import Init.System.FilePath

namespace Lyceum.Core

-- Define a specific StdioConfig for processes spawned via TerminalEnv
def terminalStdioConfig : IO.Process.StdioConfig := {
  stdin := .inherit,
  stdout := .piped,
  stderr := .piped
}

abbrev ProcessChild := IO.Process.Child terminalStdioConfig
abbrev ProcessOutput := IO.Process.Output

/-- 
物理環境とのインターフェース。
-/
class TerminalEnv (m : Type → Type) where
  print : String → m Unit
  println : String → m Unit
  readLine : m String
  readChar : m UInt8
  enableRawMode : m (Except String Bool)
  disableRawMode : m Unit
  isRawMode : m Bool
  spawnBrowser : String → m Bool
  getTerminalSize : m (Nat × Nat)
  loadHistory : System.FilePath → m (List String)
  appendHistory : System.FilePath → String → m Unit
  readFile : System.FilePath → m String
  readBinFile : System.FilePath → m ByteArray
  writeFile : System.FilePath → String → m Unit
  createDirAll : System.FilePath → m Unit
  rename : System.FilePath → System.FilePath → m Unit
  removeFile : System.FilePath → m Unit
  pathExists : System.FilePath → m Bool
  writeBinFile : System.FilePath → ByteArray → m Unit
  isDir : System.FilePath → m Bool
  readDir : System.FilePath → m (List System.FilePath)
  getFileName : System.FilePath → m String
  spawnProcess : IO.Process.SpawnArgs → m (Except String ProcessChild) -- Simplified signature
  getEnv : String → m (Option String)
  getCurrentDir : m System.FilePath
  runProcess : IO.Process.SpawnArgs → m (Except String ProcessOutput)

end Lyceum.Core
