import Lyceum.Types
import Lyceum.Inference
import Lyceum.Base64
import Lean.Data.Json

namespace Lyceum

open Lean

/-- Gemini API 用のコンテンツパーツ -/
inductive GeminiPart where
  | text (text : String)
  | inlineData (mimeType : String) (data : String)
  | functionCall (name : String) (args : Json)
  | functionResponse (name : String) (response : Json)
deriving ToJson, FromJson, Repr, Inhabited

instance : ToJson GeminiPart where
  toJson p := match p with
    | .text t => Json.mkObj [("text", Json.str t)]
    | .inlineData m d => Json.mkObj [("inline_data", Json.mkObj [("mime_type", Json.str m), ("data", Json.str d)])]
    | .functionCall n a => Json.mkObj [("function_call", Json.mkObj [("name", Json.str n), ("args", a)])]
    | .functionResponse n r => Json.mkObj [("function_response", Json.mkObj [("name", Json.str n), ("response", r)])]

structure GeminiContent where
  role : String
  parts : List GeminiPart
deriving ToJson, FromJson, Repr, Inhabited

structure GeminiRequest where
  contents : List GeminiContent
  system_instruction : Option GeminiContent := none
  generationConfig : Option Json := none
  tools : Option (List Json) := none
deriving ToJson, FromJson, Inhabited

structure GeminiClient where
  apiUrl : String
  apiKey : String
  modelName : Option String := none
deriving Repr, Inhabited

/-- 互換性のためのエイリアス -/
abbrev LlmClient := GeminiClient

/-- MessagePart から GeminiPart への変換 -/
def messagePartToGemini (p : MessagePart) : IO GeminiPart := do
  match p with
  | .text t => return .text t
  | .image m d => return .inlineData m (toBase64 d)
  | .audio m d => return .inlineData m (toBase64 d)
  | .video m d => return .inlineData m (toBase64 d)
  | .file m d => return .inlineData m (toBase64 d)
  | .resource _ c => return .text c
  | .toolCall c => 
      let args := match Json.parse c.function.arguments with
        | .ok j => j
        | _ => Json.mkObj []
      return .functionCall c.function.name args
  | .toolResponse id content =>
      let res := match Json.parse content with
        | .ok j => j
        | _ => Json.str content
      return .functionResponse id res

def messagesToGemini (history : List Message) : IO (Option GeminiContent × List GeminiContent) := do
  let mut system := none
  let mut contents := []
  for msg in history do
    let role := match msg.role with
      | .system => "system"
      | .user => "user"
      | .assistant => "model"
      | .tool => "user"
    let parts ← msg.parts.mapM messagePartToGemini
    let content := { role := role, parts := parts }
    if msg.role == .system then
      system := some { role := "system", parts := parts }
    else
      contents := content :: contents
  return (system, contents.reverse)

/-- GeminiPart から MessagePart への直接変換（JSONパース不要） -/
def geminiPartToMessageDirect (p : GeminiPart) : MessagePart :=
  match p with
  | .text t => .text t
  | .inlineData mime b64 =>
      let bytes := fromBase64 b64
      match mime.splitOn "/" |>.head! with
      | "image" => MessagePart.image mime bytes
      | "audio" => MessagePart.audio mime bytes
      | "video" => MessagePart.video mime bytes
      | _ => MessagePart.file mime bytes
  | .functionCall name args =>
      .toolCall { id := name, function := { name := name, arguments := args.compress } }
  | .functionResponse name response =>
      .toolResponse name response.compress

def geminiPartToMessage (p : Json) : IO (Option MessagePart) := do
  if let .ok (.str t) := p.getObjVal? "text" then
    return some (.text t)
  if let .ok dataObj := p.getObjVal? "inline_data" then
    if let (.ok (.str mime), .ok (.str b64)) := (dataObj.getObjVal? "mime_type", dataObj.getObjVal? "data") then
      let bytes := fromBase64 b64
      let part := match mime.splitOn "/" |>.head! with
        | "image" => MessagePart.image mime bytes
        | "audio" => MessagePart.audio mime bytes
        | "video" => MessagePart.video mime bytes
        | _ => MessagePart.file mime bytes
      return some part
  if let .ok callObj := p.getObjVal? "function_call" then
    if let (.ok (.str name), .ok args) := (callObj.getObjVal? "name", callObj.getObjVal? "args") then
      return some (.toolCall { id := name, function := { name := name, arguments := args.compress } })
  if let .ok respObj := p.getObjVal? "function_response" then
    if let (.ok (.str name), .ok resp) := (respObj.getObjVal? "name", respObj.getObjVal? "response") then
      return some (.toolResponse name resp.compress)
  return none

def floatToJsonNumber (f : Float) : JsonNumber :=
  match Json.parse (toString f) with
  | .ok (Json.num n) => n
  | _ => JsonNumber.fromNat 0

def optionsToGemini (options : Option LlmRequestOptions) : Option Json := Id.run do
  match options with
  | none => return none
  | some opt =>
      let mut fields : List (String × Json) := []
      if let some temp := opt.temperature then
        fields := ("temperature", Json.num (floatToJsonNumber temp)) :: fields
      if let some max := opt.maxTokens then
        fields := ("maxOutputTokens", Json.num (JsonNumber.fromNat max)) :: fields
      if let some topP := opt.topP then
        fields := ("topP", Json.num (floatToJsonNumber topP)) :: fields
      if fields.isEmpty then return none
      else return some (Json.mkObj fields)

/-- 
SSE チャンク ("data: {...}") をパースして GeminiPart を抽出する。
-/
def parseSseChunk (line : String) : List GeminiPart := Id.run do
  if !line.startsWith "data: " then return []
  let data := line.drop 6 |>.trimAscii.toString
  match Json.parse data with
  | .ok j =>
      let navigate : Except String (List Json) := do
        let candidates ← j.getObjVal? "candidates"
        let first ← candidates.getArrVal? 0
        let content ← first.getObjVal? "content"
        let parts ← content.getObjVal? "parts"
        let arr ← parts.getArr?
        return arr.toList
      match navigate with
      | .ok ps => 
          ps.filterMap (fun p =>
            if let .ok (.str t) := p.getObjVal? "text" then some (.text t)
            else if let .ok callObj := p.getObjVal? "function_call" then
              if let (.ok (.str name), .ok args) := (callObj.getObjVal? "name", callObj.getObjVal? "args") then
                some (.functionCall name args)
              else none
            else none
          )
      | .error _ => []
  | .error _ => []

/-- ストリームを読み込みながらリアルタイムで出力するためのヘルパー -/
partial def readStream (handle : IO.FS.Handle) (acc : List GeminiPart) : IO (List GeminiPart) := do
  let line ← handle.getLine
  if line.isEmpty then return acc
  let newParts := parseSseChunk line
  if !newParts.isEmpty then
    for part in newParts do
      match part with
      | .text t => IO.print t; (← IO.getStdout).flush
      | .functionCall name _ => IO.println s!"\n[Tool Call]: {name}"
      | _ => pure ()
    readStream handle (acc ++ newParts)
  else
    readStream handle acc

def geminiListModels (self : GeminiClient) : IO (Except AppError (List String)) := do
    let baseUrl := if self.apiUrl.endsWith "/" then self.apiUrl else self.apiUrl ++ "/"
    let url := s!"{baseUrl}v1beta/models?key={self.apiKey}"
    let child ← IO.Process.spawn { 
      cmd := "curl", 
      args := #[
        "--max-time", "5",
        "-s", "-L", "-X", "GET", 
        "-H", "Content-Type: application/json", 
        "-H", s!"x-goog-api-key: {self.apiKey}",
        url
      ], 
      stdout := .piped, stderr := .null 
    }
    let out ← child.stdout.readToEnd
    let exitCode ← child.wait
    if exitCode != 0 then
      return Except.error (AppError.NetworkError s!"curl process exited with code {exitCode}")
    match Json.parse out with
    | .ok json =>
        if let .ok errObj := json.getObjVal? "error" then
          let msg := match errObj.getObjVal? "message" with
            | .ok (.str s) => s
            | _ => "Unknown API error"
          return Except.error (AppError.LlmError s!"Gemini API Error (listModels): {msg}")

        let parseModels : Except String (List String) := do
          let modelsArr ← json.getObjVal? "models"
          let arr ← modelsArr.getArr?
          return arr.toList.filterMap (fun j => match j.getObjVal? "name" with | .ok (.str s) => some s | _ => none)
        match parseModels with 
        | .ok names => return Except.ok names 
        | .error e => return Except.error (AppError.LlmError s!"Failed to parse models: {e}. Response: {out}")
    | .error e => return Except.error (AppError.LlmError s!"JSON parse failed: {e}. Response: {out}")

def geminiStreamChatCompletion (self : GeminiClient) (history : List Message) (options : Option LlmRequestOptions) : IO (Except AppError (List Message)) := do
    let (system, contents) ← messagesToGemini history
    let reqObj : GeminiRequest := { 
      contents := contents, 
      system_instruction := system, 
      generationConfig := optionsToGemini options,
      tools := none
    }
    let jsonReq := (toJson reqObj).compress
    let model ← match self.modelName with
      | some m => pure m
      | none => return Except.error (AppError.ConfigError "No model name specified for Gemini client")
    
    let baseUrl := if self.apiUrl.endsWith "/" then self.apiUrl else self.apiUrl ++ "/"
    let url := s!"{baseUrl}v1beta/{model}:streamGenerateContent?alt=sse&key={self.apiKey}"
    
    let child ← IO.Process.spawn { 
      cmd := "curl", 
      args := #[
        "--max-time", "10",
        "-N", "-s", "-L", "-X", "POST", 
        "-H", "Content-Type: application/json", 
        "-H", s!"x-goog-api-key: {self.apiKey}",
        "-d", jsonReq, 
        url
      ], 
      stdout := .piped, stderr := .null 
    }
    
    let parts ← readStream child.stdout []
    IO.println ""
    
    let exitCode ← child.wait
    if exitCode != 0 then
      return Except.error (AppError.NetworkError s!"curl process exited with code {exitCode}")
    
    let mut messageParts : List MessagePart := []
    for p in parts do
      let mp := geminiPartToMessageDirect p
      messageParts := mp :: messageParts
    
    if messageParts.isEmpty then
      return Except.error (AppError.LlmError "LLM returned empty response")
    
    return Except.ok [{ role := Role.assistant, parts := messageParts.reverse }]

instance : LlmBackend GeminiClient where
  listModels := geminiListModels
  streamChatCompletion := geminiStreamChatCompletion
  streamContext self ctx start len := do
    match ctx.fetchSegment start len with
    | .error e => return Except.error (AppError.LlmError e)
    | .ok bytes =>
        let content := String.fromUTF8! bytes
        let history : List Message := [{ role := .user, parts := [.text content] }]
        geminiStreamChatCompletion self history none

end Lyceum
