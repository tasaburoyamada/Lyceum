import Nomos.Laws
import Lyceum.Types.ServerTypes

namespace Lyceum.NomosContract

open Nomos

/--
  MCP プロトコルの不変条件を定義する Nomos の法。
  サーバーの状態遷移が正当であることを物理的に保証する。
-/

/-- 初期化済みであることの法 -/
def isInitialized (s : ServerState) : Bool :=
  match s with
  | .Initialized _ => true
  | _ => false

/-- ツール実行は初期化済み状態でのみ許可される -/
def toolCallLaw : Nomos.Law ServerState Input Action :=
  { description := "Tools can only be called if the server is initialized"
    invariant := fun s i _ =>
      match i with
      | .Request reqJson =>
          match (fromJson? reqJson : Except String JsonRpc.Request) with
          | .ok req =>
              if req.method == "tools/call" then
                isInitialized s
              else true
          | .error _ => true
      | _ => true
  }

/-- サーバーの全契約セット -/
def serverLaws : List (Nomos.Law ServerState Input Action) :=
  [ toolCallLaw ]

end Lyceum.NomosContract
