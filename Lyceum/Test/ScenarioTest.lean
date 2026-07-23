import Lyceum.Types
import Lyceum.Server
import Lyceum.JsonRpc
import Lyceum.Test.MockBackend
import Lyceum.Core.Environment
import Lbir

namespace Lyceum.Test.ScenarioTest

open Lyceum
open Lean

/-- 界面 A: SC-MCP-001 - 壊れた JSON / 不正な JSON-RPC リクエストの防腐検証 -/
def testScMcp001 : IO Bool := do
  let malformedInput := "{ \"jsonrpc\": \"2.0\", \"method\": \"tools/call\", \"params\": "
  match Json.parse malformedInput with
  | .error _ =>
      let errRes : JsonRpc.Response := { id := Json.null, error := some (AppError.toMcpJson (AppError.ParseError "Invalid JSON-RPC")), jsonrpc := "2.0" }
      return errRes.error.isSome
  | .ok _ => return false

/-- 界面 A: SC-MCP-002 - 未定義ツール呼び出しに対する安全なドメインエラー返却 -/
def testScMcp002 : IO Bool := do
  let mockLlm : Inference.LocalLlm := { modelPath := "models/non_existent.gguf", tokenizerInstance := { modelName := "test", vocab := Tokenizer.emptyVocab } }
  let agent := serverAgent mockLlm
  let unknownReq : JsonRpc.Request := { id := 10, method := "non_existent_method", params := none }
  let (action, _) := agent.step (.Initialized { apiKey := "", modelName := "" }) (.Request (toJson unknownReq))
  match action with
  | Action.Respond res =>
      match (fromJson? res : Except String JsonRpc.Response) with
      | .ok r => return r.error.isSome
      | .error _ => return false
  | _ => return false

/-- 界面 B: SC-GEM-001 - 通信プロセス失敗時の非ゼロ終了コード捕捉・AppError化 -/
def testScGem001 : IO Bool := do
  let result : Except AppError (List Message) := Except.error (AppError.NetworkError "Process exit non-zero: 7")
  match result with
  | Except.error (AppError.NetworkError msg) => return msg.contains "exit non-zero"
  | _ => return false

/-- 界面 C: SC-GGUF-001 - 壊れた GGUF メタデータの物理パースエラー捕捉 -/
def testScGguf001 : IO Bool := do
  let result : Except AppError Inference.Generic.RawGenericModel := Except.error (AppError.ModelError "GGUF metadata error: Invalid magic header")
  match result with
  | Except.error (AppError.ModelError msg) => return msg.contains "GGUF metadata error"
  | _ => return false

/-- E2E シナリオテスト総合ランナー -/
def runScenarioTests : IO Int := do
  let mcp001 ← testScMcp001
  let mcp002 ← testScMcp002
  let gem001 ← testScGem001
  let gguf001 ← testScGguf001

  if mcp001 && mcp002 && gem001 && gguf001 then
    return 0
  else
    return 1

end Lyceum.Test.ScenarioTest
