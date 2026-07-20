import Lyceum.Server
import Nomos.Laws
import Lyceum.Test.MockBackend
import Lyceum.Test.LocalLlmTest -- Need mockLlm

namespace Lyceum.Test

open Lyceum
open Nomos
open Lean

def reqInit : Json := toJson ({ id := 1, method := "initialize", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resInit : Json := toJson ({ id := 1, jsonrpc := "2.0", result := some (toJson { protocolVersion := "2.0", capabilities := Json.null, serverInfo := { name := "Lyceum", version := "0.1" } : InitializeResult }), error := none } : JsonRpc.Response)
def reqShutdown : Json := toJson ({ id := 2, method := "shutdown", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Request)
def resShutdown : Json := toJson ({ id := 2, jsonrpc := "2.0", result := some Json.null, error := none } : JsonRpc.Response)
def notifExit : Json := toJson ({ method := "exit", jsonrpc := "2.0", params := some Json.null } : JsonRpc.Notification)

def reqCall : Json := toJson ({ id := 2, method := "tools/call", jsonrpc := "2.0", params := some (toJson (Message.mkText .user "test")) } : JsonRpc.Request)

/-- 正常なトレース -/
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

end Lyceum.Test
