import LeanTensor.Math.Gguf.Parser
import LeanTensor.Math.Gguf.Reader
import LeanTensor.Math.Gguf.Types
import LeanTensor.Math.Ops
import LeanTensor.Math.Tensor
import Lyceum.Inference
import Lyceum.Types
import Lyceum.Inference.Gemma.Raw
import Lyceum.Tokenizer.Unigram
import Lyceum.Tokenizer.Vocab
import Lyceum.Inference.Gemma.Loader
import Lyceum.Inference.Gemma.Embedding

open Lyceum
open Lyceum.Inference.Gemma.Raw
open Lyceum.Inference.Gemma.Loader
open Lyceum.Inference.Gemma.Embedding
open Lyceum.Tokenizer.Unigram
open Lyceum.Tokenizer
open Lyceum.Core -- New open statement

namespace Lyceum.Inference.Gemma.Backend

/-- テンプレートの種類 -/
inductive ChatTemplate where
  | alpaca
  | chatml
  | gemma
deriving Inhabited, Repr

structure LocalLeanTensorLlm where
  modelPath : String
  mmprojPath : Option String := none
  tokenizerInstance : Tokenizer
  template : ChatTemplate := .alpaca
  gemmaModel : Option RawGemmaModel := none
deriving Inhabited

instance : Repr LocalLeanTensorLlm where
  reprPrec self _ := s!"LocalLeanTensorLlm(modelPath: {self.modelPath})"

/-- 履歴からプロンプトを生成 -/
def historyToPrompt (_template : ChatTemplate) (history : List Message) : String :=
  history.map (fun msg => 
    let partsText := msg.parts.map (fun p => match p with | .text t => t | _ => "") |>.foldl (· ++ ·) ""
    s!"{partsText}\n"
  ) |>.foldl (· ++ ·) ""

instance [TerminalEnv IO] : LlmBackend LocalLeanTensorLlm where
  listModels _ := pure (Except.ok ["local-leantensor-gemma-4b"])

  streamChatCompletion self history options := do -- Added implicit instance
    let prompt := historyToPrompt self.template history

    -- 1. 物理モデルのロード
    let modelRaw ← match self.gemmaModel with
      | some m => pure m
      | none => 
          match ← loadRawGemmaModel self.modelPath with
          | .ok m => pure m
          | .error e => return .error e

    -- 2. トークン化
    let tokenIds := unigramTokenize self.tokenizerInstance.vocab prompt

    -- 3. 検証と昇格 (本物モデルのパラメータを使用: Hidden=2560, Vocab=3815)
    let token_embd ← match promoteToVerified modelRaw.token_embd [2560, 3815] with 
        | .ok t => pure t 
        | .error e => return .error e 
    let input_vec := embeddingLookup token_embd tokenIds

    -- 4. 推論ループ (検証済みの構造体を使用: Hidden=2560)
    let layerRaw := modelRaw.layers[0]!
    let attn_q ← match promoteToVerified layerRaw.attn_q [2560, 2560] with 
        | .ok t => pure t 
        | .error e => return .error e 
    
    let output := LeanTensor.matmul input_vec attn_q

    return Except.ok [Message.mkText .assistant s!"[Physical Inference] Output norm: {output.val[0]!}"]

  streamContext _self _ctx _start _len := do
    return Except.error (AppError.LlmError "Not implemented")

end Lyceum.Inference.Gemma.Backend
