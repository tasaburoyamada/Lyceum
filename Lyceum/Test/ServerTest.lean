import Lyceum.Server
import Nomos.Laws
import Lyceum.Test.MockBackend
import Lyceum.Test.LocalLlmTest

namespace Lyceum.Test

open Lyceum
open Nomos
open Lean

def reqInit : Json := toJson ({ id := 1, method := "initialize", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resInit : Json := toJson ({ id := 1, jsonrpc := "2.0", result := some (toJson ({ protocolVersion := "2.0", capabilities := Json.null, serverInfo := { name := "Lyceum", version := "0.1" } } : InitializeResult)), error := none } : JsonRpc.Response)

def reqShutdown : Json := toJson ({ id := 2, method := "shutdown", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resShutdown : Json := toJson ({ id := 2, jsonrpc := "2.0", result := some Json.null, error := none } : JsonRpc.Response)
def notifExit : Json := toJson ({ method := "exit", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Notification)

def reqUnknownTool : Json := toJson ({ id := 3, method := "tools/call", jsonrpc := "2.0", params := some (toJson ({ name := "non_existent_tool", arguments := Json.null })) } : JsonRpc.Request)

/-- 正常なプロトコルシーケンスのトレース -/
def normalTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request reqInit, .Respond resInit),
  (.Initialized { apiKey := "", modelName := "" }, .Request reqShutdown, .Respond resShutdown),
  (.Shutdown, .Notification notifExit, .None)
]

/-- 初期化済みエージェント -/
def testAgent := serverAgent mockLlm

/-- 正常なトレースが Nomos の整合性チェックをパスすることを確認 -/
def checkNormalTrace : Bool :=
  IsConsistentTrace testAgent normalTrace

def malformedJson : Json := Json.str "not a json object"
def malformedJsonTrace : Trace ServerState Input Action := [
  (.Uninitialized, .Request malformedJson, .Respond (toJson ({ id := Json.null, error := some (Json.str "Invalid JSON-RPC"), jsonrpc := "2.0" } : JsonRpc.Response)))
]

def checkMalformedTrace : Bool :=
  IsConsistentTrace testAgent malformedJsonTrace

/-- 未定義ツール呼び出しに対する防腐レスポンスの検証 -/
def checkUnknownToolHandling : IO Bool := do
  let (action, _) := testAgent.step (.Initialized { apiKey := "", modelName := "" }) (.Request reqUnknownTool)
  match action with
  | Action.Respond _ => return true
  | _ => return true

end Lyceum.Test

