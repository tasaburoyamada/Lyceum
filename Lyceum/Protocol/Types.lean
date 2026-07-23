import Lean
import Lean.Data.Json
import Lyceum.Types

namespace Lyceum.Protocol

open Lean hiding Message
open Lyceum

inductive GovernanceAction where
  | AuditIntegrity
  | SelfHeal
  | CheckEngine
  | VerifyIntegrity
  | ShowSettings
deriving Repr, BEq, Inhabited, ToJson, FromJson

inductive MachineAction where
  | Quit
  | CallLlm (msgs : List Message)
  | ExecuteBash (cmd : String)
  | Governance (action : GovernanceAction)
  | WriteFile (path : String) (content : String)
  | ReadFile (path : String) (startLine : Option Nat := none) (endLine : Option Nat := none)
  | SearchMemory (query : String) (limit : Nat)
  | StoreMemory (key : String) (value : String)
  | ActivateSkill (name : String)
  | EditImage (file : String) (prompt : String)
  | RestoreImage (file : String) (prompt : String)
  | GenerateIcon (prompt : String) (sizes : List Nat)
  | GenerateDiagram (prompt : String) (diagType : String)
  | InvokeAgent (prompt : String)
  | RunTest (testCommand : String)
deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- 構造化されたLLM応答 -/
structure StructuredLlmResponse where
  thought : String
  action : Option String -- 例えばbashコマンド
  response : String
  hasLlmError : Bool := false
deriving Repr, BEq, Inhabited, ToJson, FromJson

/-- Gemini 2.0 Native Structured Output (OpenAPI 3.0 Schema) -/

def structuredLlmResponseSchema : Json :=
  Json.mkObj [
    ("type", Json.str "OBJECT"),
    ("properties", Json.mkObj [
      ("thought", Json.mkObj [("type", Json.str "STRING"), ("description", Json.str "Thinking and reasoning process")]),
      ("action", Json.mkObj [("type", Json.str "STRING"), ("description", Json.str "Action command e.g. /bash <cmd>, /write <file> <content>, /read <file>")]),
      ("response", Json.mkObj [("type", Json.str "STRING"), ("description", Json.str "Natural language output to user")])
    ]),
    ("required", Json.arr #[Json.str "thought", Json.str "response"])
  ]

/-- LLMからの生応答を解析し、StructuredLlmResponse を抽出する -/
def parseStructuredLlmResponse (rawResponse : String) : StructuredLlmResponse :=
  match Json.parse rawResponse with
  | Except.ok j =>
      let thought := (j.getObjValAs? String "thought").toOption.getD ""
      let action := (j.getObjValAs? String "action").toOption
      let response := (j.getObjValAs? String "response").toOption.getD rawResponse
      { thought := thought, action := action, response := response }
  | Except.error _ =>
      { thought := "", action := none, response := rawResponse }


end Lyceum.Protocol
