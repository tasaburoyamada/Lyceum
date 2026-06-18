import Lyceum.Server
import Nomos.Laws
import Lyceum.Test.MockBackend

namespace Lyceum.Test

open Lyceum
open Nomos
open Lean

def reqInit : Json := toJson ({ id := 1, method := "initialize", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resInit : Json := toJson ({ id := 1, jsonrpc := "2.0", result := some (toJson { protocolVersion := "2024-11-05", capabilities := Json.mkObj [], serverInfo := { name := "Lyceum", version := "0.1.0" } : InitializeResult }), error := none } : JsonRpc.Response)
def reqShutdown : Json := toJson ({ id := 2, method := "shutdown", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resShutdown : Json := toJson ({ id := 2, jsonrpc := "2.0", result := some Json.null, error := none } : JsonRpc.Response)
def notifExit : Json := toJson ({ method := "exit", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Notification)
def reqInvalid : Json := toJson ({ id := 1, method := "listResources", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resInvalid : Json := toJson ({ id := 1, jsonrpc := "2.0", result := none, error := some (Json.str "Server not initialized") } : JsonRpc.Response)

def reqCall : Json := toJson ({ id := 2, method := "tools/call", jsonrpc := "2.0", params := some (toJson (Message.mkText .user "test")) } : JsonRpc.Request)

/-- LLM がエラーを返した際の MCP レスポンス検証トレース -/
def llmErrorTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request reqInit, .Respond resInit),
  (.Initialized { apiKey := "", modelName := "" }, .Request reqCall, .CallLlm (toJson (2 : Nat)) [Message.mkText .user "test"])
]

/-- 正常な初期化と終了のシーケンス -/
def normalTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request reqInit, .Respond resInit),
  (.Initialized { apiKey := "", modelName := "" }, .Request reqShutdown, .Respond resShutdown),
  (.Shutdown, .Notification notifExit, .None)
]

/-- 不正な初期化（initialize の前に他のリクエスト） -/
def invalidInitTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request reqInvalid, .Respond resInvalid)
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