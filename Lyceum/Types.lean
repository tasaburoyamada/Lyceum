import Lean
import Lean.Data.Json
import Init.Data.ToString.Basic
import Lyceum.Base64

open Lean

namespace Lyceum

deriving instance Repr for ByteArray
deriving instance Repr for Lean.Json

instance : ToJson ByteArray where
  toJson a := Json.str (toBase64 a)

instance : FromJson ByteArray where
  fromJson? 
    | Json.str s => Except.ok (fromBase64 s)
    | _ => Except.error "Expected string for ByteArray"

/-- MCP 役割の定義 -/
inductive Role where
  | system | user | assistant | tool
deriving Repr, BEq, ToJson, FromJson, Inhabited

/-- 実行エンジンのアクション定義 -/
inductive ExecutionAction where
  | Bash (cmd : String)
  | Docker (cmd : String)
  | Wasm (mod : String) (func : String)
  | Grep (pat : String) (dir : Option String)
  | Read (path : String)
  | Write (path : String) (content : String)
  | Glob (pat : String) (dir : Option String)
deriving Repr, Inhabited, BEq

instance : ToString Role where
  toString : Role → String
  | .system => "system"
  | .user => "user"
  | .assistant => "assistant"
  | .tool => "tool"

structure FunctionCall where
  name : String
  arguments : String
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure ToolCall where
  id : String
  type : String := "function"
  function : FunctionCall
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- マルチモーダル対応のメッセージパーツ -/
inductive MessagePart where
  | text (content : String)
  | image (mimeType : String) (data : ByteArray)
  | audio (mimeType : String) (data : ByteArray)
  | video (mimeType : String) (data : ByteArray)
  | file (mimeType : String) (data : ByteArray)
  | resource (uri : String) (content : String)
  | toolCall (call : ToolCall)
  | toolResponse (id : String) (content : String)
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- メッセージ構造体 -/
structure Message where
  role : Role
  parts : List MessagePart
deriving Repr, ToJson, FromJson, BEq, Inhabited

def Message.mkText (role : Role) (text : String) : Message :=
  { role := role, parts := [.text text] }

def Message.content (msg : Message) : String :=
  msg.parts.map (fun p => match p with | .text t => t | _ => "") |>.foldl (· ++ ·) ""

/-- 推論オプション -/
structure LlmRequestOptions where
  temperature : Option Float := none
  maxTokens : Option Nat := none
  topP : Option Float := none
deriving Repr, BEq, ToJson, FromJson, Inhabited

inductive AppError where
  | LlmError : String -> AppError
  | ExecutionError : String -> AppError
  | ConfigError : String -> AppError
  | AuthError : String -> AppError
  | IoError : String -> AppError
  | SerializationError : String -> AppError
  | NetworkError : String -> AppError
  | Timeout : AppError
  | ToolError : String -> AppError
  | PolicyViolation : String -> AppError
  | ModelError : String -> AppError
  | ParseError : String -> AppError
  | ExternalError : String -> AppError
  | Unknown : String -> AppError
deriving Repr, BEq, Inhabited

instance : ToString AppError where
  toString e := s!"{repr e}"

def AppError.toMcpJson (e : AppError) : Lean.Json :=
  Lean.Json.mkObj [
    ("code", Lean.Json.num (Lean.JsonNumber.fromNat 32000)),
    ("message", Lean.Json.str (toString e))
  ]

structure Tool where
  name : String
  description : String
  inputSchema : Lean.Json
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure Resource where
  uri : String
  name : String
  description : String
  mimeType : String
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure Prompt where
  name : String
  description : String
  arguments : Lean.Json
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure ServerInfo where
  name : String
  version : String
deriving Repr, ToJson, FromJson, BEq, Inhabited

structure InitializeResult where
  protocolVersion : String
  capabilities : Lean.Json
  serverInfo : ServerInfo
deriving Repr, ToJson, FromJson, BEq, Inhabited

end Lyceum

