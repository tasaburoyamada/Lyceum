import Lyceum.Inference
import Lyceum.Types

namespace Lyceum.Test

/-- 異常系をテストするためのモックLLMバックエンド -/
structure MockLlmBackend where
  shouldFail : Bool
  errorMessage : String

instance : LlmBackend MockLlmBackend where
  streamChatCompletion self _ _ := 
    if self.shouldFail then
      return .error (.LlmError self.errorMessage)
    else
      return .ok [Message.mkText .assistant "Mock response"]
  
  streamContext self _ _ _ :=
    if self.shouldFail then
      return .error (.LlmError self.errorMessage)
    else
      return .ok [Message.mkText .assistant "Mock context response"]
  listModels _ := return .ok ["mock-model"]

end Lyceum.Test
