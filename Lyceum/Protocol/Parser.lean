import Lean
import Lean.Data.Json
import Lyceum.Types
import Lyceum.Protocol.Types

namespace Lyceum.Protocol

open Lean hiding Message
open Lyceum

/-- LLMの生成テキストから MachineAction AST をパースする純粋関数 -/
def parseActionFromText (input : String) : Option MachineAction := Id.run do
  let trimmed := input.trimAscii.toString
  if trimmed == "/quit" || trimmed == "quit" then
    return some MachineAction.Quit
  else if trimmed.startsWith "/bash " then
    let cmd := trimmed.drop 6
    return some (MachineAction.ExecuteBash cmd.toString)
  else if trimmed.startsWith "/write " then
    let rest := (trimmed.drop 7).toString
    let parts := rest.splitOn " "
    match parts with
    | path :: contentParts =>
        let content := String.intercalate " " contentParts
        return some (MachineAction.WriteFile path content)
    | _ => return none
  else if trimmed.startsWith "/read " then
    let path := (trimmed.drop 6).toString
    return some (MachineAction.ReadFile path)
  else
    return none

end Lyceum.Protocol
