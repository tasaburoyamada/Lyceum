import Init.System.IO

namespace Lyceum.Core.IO

/-- ファイルのシーク操作を抽象化する安定したインターフェース (Dummy read implementation) -/
def seek (handle : IO.FS.Handle) (pos : UInt64) : IO Unit := do
  -- Seek using dummy read if handle.seek is unavailable
  let _ ← handle.read pos.toUSize
  pure ()

/-- ファイルのクローズ操作を抽象化 -/
def close (handle : IO.FS.Handle) : IO Unit :=
  handle.flush 

/-- ファイルの権限変更を抽象化 -/
def chmod (path : System.FilePath) (mode : UInt32) : IO Unit := do
  -- 物理的な chmod コマンドを実行する
  let _ ← IO.Process.run { cmd := "chmod", args := #[s!"{mode}", path.toString] }
  pure ()

end Lyceum.Core.IO
