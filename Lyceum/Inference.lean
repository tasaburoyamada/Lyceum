import Lyceum.Types
import Lyceum.MemoryMapped

namespace Lyceum

class LlmBackend (α : Type) where
  streamChatCompletion (self : α) (history : List Message) (options : Option LlmRequestOptions) : IO (Except AppError (List Message))
  streamContext (self : α) (ctx : MemoryMappedContext) (start : Nat) (len : Nat) : IO (Except AppError (List Message))
  listModels (self : α) : IO (Except AppError (List String))

-- 具象実装のためのヘルパー型クラス
class LlmInstanceBackend (α : Type) where
  streamChatCompletion (self : α) (history : List Message) (options : Option LlmRequestOptions) : IO (Except AppError (List Message))
  streamContext (self : α) (ctx : MemoryMappedContext) (start : Nat) (len : Nat) : IO (Except AppError (List Message))
  listModels (self : α) : IO (Except AppError (List String))

end Lyceum
