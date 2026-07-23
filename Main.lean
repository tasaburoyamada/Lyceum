import Lbir
import Lyceum.Server
import Lyceum.Inference.Gemini
import Lean.Data.Json.Parser


open Lyceum
open Lean

def main (args : List String) : IO Unit := do
  if args.contains "--help" || args.contains "-h" then
    IO.println "Lyceum v0.43.0
Usage: lyceum [--help]"
    return
  
  let apiKey ← IO.getEnv "GEMINI_API_KEY"
  let modelName := "gemini-2.0-flash-exp"
  
  IO.eprintln "Lyceum MCP Server starting..."
  if apiKey.isNone then
    IO.eprintln "Warning: GEMINI_API_KEY not set. LLM calls will fail."

  let modelPath := "models/gemma.gguf"
  let tokenizer : Tokenizer.Tokenizer := { modelName := "gemma", vocab := Tokenizer.emptyVocab }
  let llmBackend : Inference.LocalLlm := { modelPath := modelPath, tokenizerInstance := tokenizer }
  let agent := serverAgent llmBackend

  let mut state := agent.initialState
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout

  while state != ServerState.Shutdown do
    let line ← stdin.getLine
    if line.isEmpty then break -- EOF

    let res : Except AppError JsonRpc.Response ← 
      match Json.parse line with
      | .error e => pure <| Except.error (AppError.ParseError e)
      | .ok json =>
        match (fromJson? json : Except String JsonRpc.Request) with
        | .ok req => 
            let (action, nextState) := agent.step state (Input.Request (toJson req))
            state := nextState
            match action with
            | Action.Respond res =>
                match (fromJson? res : Except String JsonRpc.Response) with
                | .ok r => pure <| Except.ok r
                | .error e => pure <| Except.error (AppError.ParseError s!"Failed to parse response: {e}")
            | Action.CallLlm callId history =>
                -- NOTE: Using a placeholder client for LLM call until GeminiClient is properly configured
                pure <| Except.ok ({ id := callId, result := some (toJson ("LLM call placeholder" : String)), jsonrpc := "2.0" } : JsonRpc.Response)
            | _ => pure <| Except.ok ({ id := req.id, result := some Json.null, jsonrpc := "2.0" } : JsonRpc.Response)
        | .error _ => 
            match (fromJson? json : Except String JsonRpc.Notification) with
            | .ok notif => 
                let (_, nextState) := agent.step state (Input.Notification (toJson notif))
                state := nextState
                pure <| Except.ok ({ id := Json.null, result := some Json.null, jsonrpc := "2.0" } : JsonRpc.Response)
            | .error _ => pure <| Except.error (AppError.ParseError "Invalid JSON-RPC")

    match res with
    | .ok r => 
        stdout.putStrLn (Json.compress (toJson r))
        stdout.flush
    | .error e =>
        let errRes : JsonRpc.Response := { id := Json.null, error := some (AppError.toMcpJson e), jsonrpc := "2.0" }
        stdout.putStrLn (Json.compress (toJson errRes))
        stdout.flush

  IO.eprintln "Lyceum MCP Server shutting down."
