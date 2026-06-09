import Lyceum.Server
import Lyceum.Inference.Gemini
import Lean.Data.Json.Parser

open Lyceum
open Lean

def main : IO Unit := do
  let apiKey ← IO.getEnv "GEMINI_API_KEY"
  let modelName := "gemini-2.0-flash-exp"
  
  IO.println "Lyceum MCP Server starting..."
  if apiKey.isNone then
    IO.eprintln "Warning: GEMINI_API_KEY not set. LLM calls will fail."

  let mut state := serverAgent.initialState
  let stdin ← IO.getStdin
  let stdout ← IO.getStdout

  while state != .Shutdown do
    let line ← stdin.getLine
    if line.isEmpty then break -- EOF

    match Json.parse line with
    | .error _ => continue
    | .ok json =>
        let input : Option Input := 
          match (fromJson? json : Except String JsonRpc.Request) with
          | .ok req => some (.Request req)
          | .error _ => 
              match (fromJson? json : Except String JsonRpc.Notification) with
              | .ok notif => some (.Notification notif)
              | .error _ => none
        
        match input with
        | none => continue
        | some i =>
            let (action, nextState) := serverAgent.step state i
            state := nextState
            
            match action with
            | .Respond res => 
                stdout.putStrLn (Json.compress (toJson res))
                stdout.flush
            | .Notify notif =>
                stdout.putStrLn (Json.compress (toJson notif))
                stdout.flush
            | .CallLlm id history =>
                let client : GeminiClient := { apiUrl := "https://generativelanguage.googleapis.com", apiKey := apiKey.getD "", modelName := some modelName }
                match ← LlmBackend.streamChatCompletion client history none with
                | .ok respMsgs =>
                    let res : JsonRpc.Response := { id := id, result := some (toJson respMsgs) }
                    stdout.putStrLn (Json.compress (toJson res))
                    stdout.flush
                | .error err =>
                    let res : JsonRpc.Response := { id := id, error := some (Json.str s!"LLM Error: {err}") }
                    stdout.putStrLn (Json.compress (toJson res))
                    stdout.flush
            | .None => pure ()

  IO.println "Lyceum MCP Server shutting down."
