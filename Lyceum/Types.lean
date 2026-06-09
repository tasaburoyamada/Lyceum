import Lean

namespace Lyceum

open Lean

-- インスタンス定義
deriving instance Repr for IO.Error
deriving instance Repr for ByteArray
deriving instance Repr for Json

instance : ToJson ByteArray where
  toJson b := Json.arr (b.toList.toArray.map (fun u => Json.num (JsonNumber.fromNat u.toNat)))

instance : FromJson ByteArray where
  fromJson? j := do
    let arr ← j.getArr?
    let list ← arr.toList.mapM (fun n => n.getNat?)
    return (list.map UInt8.ofNat).toByteArray

/-- MCP 役割の定義 -/
inductive Role where
  | system | user | assistant | tool
deriving Repr, BEq, ToJson, FromJson, Inhabited

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

/-- メッセージから最初のテキスト内容を取得する -/
def Message.content (self : Message) : String :=
  let texts := self.parts.filterMap (fun p => 
    match p with
    | .text t => some t
    | _ => none
  )
  String.intercalate "\n" texts

/-- テキストのみのメッセージを作成するヘルパー -/
def Message.mkText (role : Role) (text : String) : Message :=
  { role := role, parts := [.text text] }

/-- 文字列をFloatに変換する -/
def stringToFloat (s : String) : Float :=
  match Json.parse s with
  | .ok (Json.num n) => n.toFloat
  | _ => 0.0 

/-- LLMへのリクエストオプション -/
structure LlmRequestOptions where
  maxTokens : Option Nat := none
  temperature : Option Float := none
  topP : Option Float := none
deriving Repr, BEq, ToJson, FromJson

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
  | Unknown : String -> AppError
deriving Repr, BEq, Inhabited

instance : ToString AppError where
  toString e := s!"{repr e}"

/-- MCP ツール定義 -/
structure Tool where
  name : String
  description : String
  inputSchema : Json
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- MCP リソース定義 -/
structure Resource where
  uri : String
  name : String
  description : String
  mimeType : String
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- MCP プロンプト定義 -/
structure Prompt where
  name : String
  description : String
  arguments : Json
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- サーバーの基本情報 -/
structure ServerInfo where
  name : String
  version : String
deriving Repr, ToJson, FromJson, BEq, Inhabited

/-- 初期化レスポンス -/
structure InitializeResult where
  protocolVersion : String
  capabilities : Json
  serverInfo : ServerInfo
deriving Repr, ToJson, FromJson, BEq, Inhabited

end Lyceum
