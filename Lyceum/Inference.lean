import Lyceum.Types

namespace Lyceum

class LlmBackend (α : Type) where
  streamChatCompletion (self : α) (history : List Message) (options : Option LlmRequestOptions) : IO (Except AppError (List Message))
  listModels (self : α) : IO (Except AppError (List String))

class ExecutionEngine (α : Type) where
  prepare (self : α) (cmd : String) (lang : String) : Except AppError ExecutionAction

end Lyceum
