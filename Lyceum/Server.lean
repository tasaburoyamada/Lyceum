import Lyceum.JsonRpc
import Lyceum.Inference
import Lyceum.Types
import Lyceum.Types.ServerTypes
import Nomos.Laws

namespace Lyceum

open Lean
open Nomos

/-- Lyceum サーバーのエージェント定義 -/
def serverAgent : Agent ServerState Input Action where
  initialState := ServerState.Uninitialized
  step s i := 
    match s, i with
    | ServerState.Uninitialized, Input.Request reqJson =>
        match (fromJson? reqJson : Except String JsonRpc.Request) with
        | .ok req =>
          if req.method == "initialize" then
            (Action.Respond (toJson { id := req.id, result := some (toJson { protocolVersion := "2024-11-05", capabilities := Json.mkObj [], serverInfo := { name := "Lyceum", version := "0.1.0" } : InitializeResult }), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Initialized { apiKey := "", modelName := "" })
          else
            (Action.Respond (toJson { id := req.id, error := some (Json.str "Server not initialized"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Uninitialized)
        | .error _ => (Action.Respond (toJson { id := Json.null, error := some (Json.str "Invalid Request"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Uninitialized)
    
    | ServerState.Initialized config, Input.Request reqJson =>
        match (fromJson? reqJson : Except String JsonRpc.Request) with
        | .ok req =>
          if req.method == "shutdown" then
            (Action.Respond (toJson { id := req.id, result := some Json.null, jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Shutdown)
          else if req.method == "tools/call" then
            match req.params with
            | some paramsJson =>
              match (fromJson? paramsJson : Except String Message) with
              | .ok msg => (Action.CallLlm req.id [msg], ServerState.Initialized config)
              | .error _ => (Action.Respond (toJson { id := req.id, error := some (Json.str "Invalid parameters for tool call") : JsonRpc.Response }), ServerState.Initialized config)
            | none => (Action.Respond (toJson { id := req.id, error := some (Json.str "Missing parameters for tool call") : JsonRpc.Response }), ServerState.Initialized config)
          else
            (Action.Respond (toJson { id := req.id, error := some (Json.str "Method not implemented"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Initialized config)
        | .error _ => (Action.Respond (toJson { id := Json.null, error := some (Json.str "Invalid Request"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Initialized config)
    
    | ServerState.Shutdown, Input.Request reqJson =>
        match (fromJson? reqJson : Except String JsonRpc.Request) with
        | .ok req => (Action.Respond (toJson { id := req.id, error := some (Json.str "Server is shutting down"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Shutdown)
        | .error _ => (Action.Respond (toJson { id := Json.null, error := some (Json.str "Invalid Request"), jsonrpc := "2.0" : JsonRpc.Response }), ServerState.Shutdown)
    
    | s, Input.Notification notifJson =>
        match (fromJson? notifJson : Except String JsonRpc.Notification) with
        | .ok notif =>
          if notif.method == "exit" then
            (Action.None, ServerState.Shutdown)
          else
            (Action.None, s)
        | .error _ => (Action.None, s)

end Lyceum
