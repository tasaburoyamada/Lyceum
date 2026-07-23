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


/-- LLMからの生応答を解析し、StructuredLlmResponse を抽出する -/
def parseStructuredLlmResponse (rawResponse : String) : StructuredLlmResponse :=
  { thought := "", action := none, response := rawResponse }

end Lyceum.Protocol
