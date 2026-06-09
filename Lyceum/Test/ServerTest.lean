import Lyceum.Server
import Nomos.Laws

namespace Lyceum.Test

open Lyceum
open Nomos

/-- 正常な初期化と終了のシーケンス -/
def normalTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request { id := 1, method := "initialize", jsonrpc := "2.0", params := .null }, .Respond { id := 1, jsonrpc := "2.0", result := some (Lean.toJson { protocolVersion := "2024-11-05", capabilities := Lean.Json.mkObj [], serverInfo := { name := "Lyceum", version := "0.1.0" } : InitializeResult }), error := none }),
  (.Initialized { apiKey := "", modelName := "" }, .Request { id := 2, method := "shutdown", jsonrpc := "2.0", params := .null }, .Respond { id := 2, jsonrpc := "2.0", result := some .null, error := none }),
  (.Shutdown, .Notification { method := "exit", jsonrpc := "2.0", params := .null }, .None)
]

/-- 不正な初期化（initialize の前に他のリクエスト） -/
def invalidInitTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request { id := 1, method := "listResources", jsonrpc := "2.0", params := .null }, .Respond { id := 1, jsonrpc := "2.0", result := none, error := some (Lean.Json.str "Server not initialized") })
]

/-- 
正常なトレースが Nomos の整合性チェックをパスすることを確認 
-/
def checkNormalTrace : Bool :=
  IsConsistentTrace serverAgent normalTrace

/-- 
不正な初期化拒否トレースの検証
-/
def checkInvalidInitTrace : Bool :=
  IsConsistentTrace serverAgent invalidInitTrace

end Lyceum.Test
