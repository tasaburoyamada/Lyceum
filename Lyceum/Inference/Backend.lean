import Lyceum.Inference
import Lyceum.Types
import Lyceum.Tokenizer.Unigram
import Lyceum.Inference.Generic.Architecture
import Lyceum.Inference.Generic.Loader
import Lyceum.Inference.Generic.Kernel
import Lyceum.Inference.Generic.KVCache
import LeanTensor.Math.Shape
import LeanTensor.Math.Tensor

open Lyceum
open Lyceum.Inference.Generic
open LeanTensor

namespace Lyceum.Inference

/-- テンプレートの種類 -/
inductive ChatTemplate where
  | alpaca | chatml | gemma
deriving Inhabited, Repr

/-- 汎用ローカルLLMバックエンド --/
structure LocalLlm where
  modelPath : String
  tokenizerInstance : Tokenizer.Tokenizer
  template : ChatTemplate := .gemma
  rawModel : Option RawGenericModel := none
  state : InferenceState := { cache := none, tokenCount := 0 }
deriving Inhabited

/-- 履歴から物理的なプロンプトを構築する (スタブなし) --/
def historyToPrompt (template : ChatTemplate) (history : List Message) : String :=
  let buildMsg (m : Message) : String :=
    let roleStr := match m.role with | .user => "user" | .assistant => "model" | .system => "system" | .tool => "tool"
    let content := Message.content m
    match template with
    | .gemma => s!"<start_of_turn>{roleStr}\n{content}<end_of_turn>\n"
    | .chatml => s!"<|im_start|>{roleStr}\n{content}<|im_end|>\n"
    | .alpaca => s!"### {roleStr}:\n{content}\n\n"
  history.foldl (fun acc m => acc ++ buildMsg m) ""

def embeddingLookup (model : RawGenericModel) (token_id : Nat)
  : IO (Except AppError (LeanTensor.Tensor [1, model.arch.hiddenSize])) := do
  let embd_name := "token_embd.weight"
  match model.tensors.get? embd_name with
  | none => return Except.error (AppError.ModelError s!"Embedding tensor '{embd_name}' not found")
  | some tensor =>
      let embd_raw ← Kernel.dequantize tensor
      let h_size := model.arch.hiddenSize
      let start_idx := token_id * h_size
      if h_bound : start_idx + h_size <= embd_raw.data.size then
        let data := embd_raw.data.extract start_idx (start_idx + h_size)
        if h : data.size = h_size then
          return Except.ok { val := data, prop := by simp [Shape.prod, List.prod]; exact h }
        else return Except.error (AppError.ModelError "Embedding extraction error")
      else return Except.error (AppError.ModelError s!"Token {token_id} out of bounds")

instance [Lyceum.Core.TerminalEnv IO] : LlmBackend LocalLlm where
  listModels _ := pure (Except.ok ["local-generic-1bit-llm"])

  streamChatCompletion self history _options := do
    let prompt := historyToPrompt self.template history
    let modelResult ← match self.rawModel with
      | some m => pure (Except.ok m)
      | none => Loader.loadRawGenericModel self.modelPath
    
    match modelResult with
    | Except.error e => return Except.error e
    | Except.ok model =>

      let tokenIds := Tokenizer.Unigram.unigramTokenize self.tokenizerInstance.vocab prompt
      if tokenIds.isEmpty then return Except.error (AppError.Unknown "Empty tokens")
      
      let initial_cache : GenericKVCache := match self.state.cache with
        | some c => c
        | none => { 
            keys := Array.mk (List.replicate model.arch.numLayers FloatArray.empty),
            values := Array.mk (List.replicate model.arch.numLayers FloatArray.empty)
          }

      -- Nomos Contract Check: Verify model state before inference
      if model.tensors.isEmpty then
        return Except.error (AppError.ModelError "Nomos Violation: Model tensors are empty, inference aborted.")

      -- 推論ステップ: 物理的な状態遷移を完遂
      let run_step (token_id : Nat) (cache : GenericKVCache) (pos : Nat) : IO (Except AppError (Nat × GenericKVCache)) := do
        let embeddingRes ← embeddingLookup model token_id
        match embeddingRes with
        | Except.error e => return Except.error e
        | Except.ok hidden_state =>
            let mut state := hidden_state
            let mut updated_cache := cache
            for i in [0:model.arch.numLayers] do
              match ← Kernel.runLlamaLayer model i state updated_cache pos with
              | Except.error e => return Except.error e
              | Except.ok (next_state, next_cache) =>
                  state := next_state
                  updated_cache := next_cache
            
            let next_token := Native.argmaxNative (FloatArray.mk state.val)
            return Except.ok (next_token, updated_cache)

      -- Prefill & Decode パイプライン
      let rec run_pipeline (inputs : List Nat) (cache : GenericKVCache) (generated : List Nat) (pos : Nat) (remaining : Nat) : IO (Except AppError (List Nat)) := do
        match remaining with
        | 0 => return Except.ok generated
        | rem + 1 =>
          let token_id := match inputs with | t :: _ => t | [] => (generated.reverse.headD 0)
          let next_inputs := match inputs with | _ :: ts => ts | [] => []
          
          match ← run_step token_id cache pos with
          | Except.error e => return Except.error e
          | Except.ok (next_token, updated_cache) =>
              if inputs.isEmpty then
                if next_token == 1 then return Except.ok (generated ++ [next_token])
                else run_pipeline [] updated_cache (generated ++ [next_token]) (pos + 1) rem
              else
                -- Prefillhandover: 最後のプロンプトの予測値を Decode に繋ぐ
                if next_inputs.isEmpty then
                   run_pipeline [] updated_cache [next_token] (pos + 1) rem
                else
                   run_pipeline next_inputs updated_cache [] (pos + 1) rem

      match ← run_pipeline tokenIds initial_cache [] self.state.tokenCount 50 with
      | Except.error e => return Except.error e
      | Except.ok result_tokens =>
          let output_text := self.tokenizerInstance.vocab.decode result_tokens
          return Except.ok [Message.mkText .assistant s!"[Physical Result] {output_text}"]

  streamContext self _ctx _start _len := do
    -- Architectural intent: Stream context from Memory.VectorDB based on start/len.
    -- Returning empty list as no context lookup is currently configured in this environment.
    return Except.ok []

end Lyceum.Inference
