import Lyceum.Core.Environment
import Lyceum.Types
import Lyceum.Core.Interface
import Lyceum.Core.IO

namespace Lyceum.Test.PhysicalIOTest

open Lyceum.Core
open Lyceum.Core.Environment

/-- ファイルシステム境界テスト -/
def testFileSystemRobustness : IO Bool := do
  let testPath := "/tmp/lyceum_test_boundary.txt"
  
  -- 1. 存在しないファイルの読み込み
  let nonExistent := System.FilePath.mk "/tmp/non_existent_file_123456789.txt"
  let readRes ← try
    let _ ← IO.FS.readFile nonExistent
    pure true
  catch _ => pure false
  if readRes then return false -- 成功してはいけない

  -- 2. 書き込み権限テスト
  let handle ← IO.FS.Handle.mk (System.FilePath.mk testPath) .write
  handle.putStr "test"
  handle.flush
  Lyceum.Core.IO.close handle
  Lyceum.Core.IO.chmod (System.FilePath.mk testPath) 0o444
  
  -- 読み取り専用ファイルへの書き込み試行
  let writeRes ← try
    IO.FS.writeFile (System.FilePath.mk testPath) "attempt"
    pure true
  catch _ => pure false
  
  Lyceum.Core.IO.chmod (System.FilePath.mk testPath) 0o644
  IO.FS.removeFile (System.FilePath.mk testPath)
  return !writeRes

/-- プロセス実行境界テスト -/
def testProcessRobustness : IO Bool := do
  let res ← try
    let _ ← IO.Process.run { cmd := "/usr/bin/non_existent_command_123456789", args := #[] }
    pure "some output"
  catch _ => pure ""
  match res with
  | "" => return true
  | _ => return false -- Any output means something ran (unexpected)

def runPhysicalIOTests : IO Int := do
  let fsOk ← testFileSystemRobustness
  let procOk ← testProcessRobustness
  if fsOk && procOk then return 0 else return 1
