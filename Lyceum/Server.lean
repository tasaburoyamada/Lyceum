import Lyceum.JsonRpc
import Lyceum.Inference
import Nomos.Laws

namespace Lyceum

open Lean

/-- サーバーのコンテキスト（不変な設定） -/
structure ServerConfig where
  apiKey : String
  modelName : String
deriving Repr, BEq

/-- サーバーの状態 -/
inductive ServerState where
  | Uninitialized
  | Initialized (config : ServerConfig)
  | Shutdown
deriving Repr, BEq

/-- 入力イベント -/
inductive Input where
  | Request (req : JsonRpc.Request)
  | Notification (notif : JsonRpc.Notification)
deriving Repr, BEq

/-- 出力アクション -/
inductive Action where
  | Respond (res : JsonRpc.Response)
  | Notify (notif : JsonRpc.Notification)
  | CallLlm (id : Json) (history : List Message)
  | None
deriving Repr, BEq

/-- Lyceum サーバーのエージェント定義 (Nomos 準拠) -/
def serverAgent : Nomos.Agent ServerState Input Action where
  initialState := .Uninitialized
  step s i := 
    match s, i with
    | .Uninitialized, .Request req =>
        if req.method == "initialize" then
          (.Respond { id := req.id, result := some (toJson { protocolVersion := "2024-11-05", capabilities := Json.mkObj [], serverInfo := { name := "Lyceum", version := "0.1.0" } : InitializeResult }) }, .Initialized { apiKey := "", modelName := "" })
        else
          (.Respond { id := req.id, error := some (Json.str "Server not initialized") }, .Uninitialized)
    
    | .Initialized _, .Request req =>
        if req.method == "shutdown" then
          (.Respond { id := req.id, result := some Json.null }, .Shutdown)
        else if req.method == "tools/call" then
          -- llm_generate ツールが呼ばれたと仮定
          match (fromJson? req.params : Except String Message) with
          | .ok msg => (.CallLlm req.id [msg], s)
          | .error _ => (.Respond { id := req.id, error := some (Json.str "Invalid parameters for tool call") }, s)
        else
          (.Respond { id := req.id, result := some (Json.str "Method not implemented") }, s)
    
    | .Shutdown, .Request req =>
        (.Respond { id := req.id, error := some (Json.str "Server is shutting down") }, .Shutdown)
    
    | _, .Notification notif =>
        if notif.method == "exit" then
          (.None, .Shutdown)
        else
          (.None, s)

end Lyceum
