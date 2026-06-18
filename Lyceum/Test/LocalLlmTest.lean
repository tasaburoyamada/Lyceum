import Lyceum.Inference
import Lyceum.Inference.Gemma.Backend
import Lyceum.Inference.Gemma.Loader
import Lyceum.Inference.Gemma.Raw
import Lyceum.Types
import Lyceum.Tokenizer.Vocab
import Lyceum.Tokenizer.Unigram
import LeanTensor.Math.Tensor
import LeanTensor.Math.Shape
import LeanTensor.Math.Ops
import Init.Data.Array.Basic -- Explicit import for Array.mkArray

open Lyceum
open LeanTensor

namespace Lyceum.Test

/-- Dummy RawTensor for testing -/
def dummyRawTensor (dims : List Nat) : Lyceum.Inference.Gemma.Raw.RawTensor :=
  { dims := dims, data := Array.ofFn (n := LeanTensor.Shape.prod dims) (f := fun _ => (0.0 : Float)) }

/-- Mock RawGemmaModel for testing -/
def mockRawGemmaModel : Lyceum.Inference.Gemma.Raw.RawGemmaModel :=
  { token_embd := dummyRawTensor [2560, 3815],
    layers := #[
      { attn_q := dummyRawTensor [2560, 2560],
        attn_k := dummyRawTensor [2560, 2560],
        attn_v := dummyRawTensor [2560, 2560],
        attn_o := dummyRawTensor [2560, 2560],
        ffn_gate := dummyRawTensor [2560, 2560],
        ffn_up := dummyRawTensor [2560, 2560],
        ffn_down := dummyRawTensor [2560, 2560],
        attn_norm := dummyRawTensor [2560],
        post_attn_norm := dummyRawTensor [2560],
        ffn_norm := dummyRawTensor [2560],
        post_ffw_norm := dummyRawTensor [2560]
      }
    ],
    norm_final := dummyRawTensor [2560]
  }

/-- Mock Vocab for testing -/
def mockVocab : Lyceum.Tokenizer.Vocab :=
  Lyceum.Tokenizer.emptyVocab
  |>.add 0 "<s>" 0.0 .normal
  |>.add 1 "</s>" 0.0 .normal
  |>.add 2 " Hello" 0.0 .normal
  |>.add 3 " world" 0.0 .normal

/-- Mock LocalLeanTensorLlm for testing -/
def mockLlm : Lyceum.Inference.Gemma.Backend.LocalLeanTensorLlm :=
  { modelPath := "/mock/model.gguf",
    tokenizerInstance := { modelName := "mock-tokenizer", vocab := mockVocab },
    template := .gemma,
    gemmaModel := some mockRawGemmaModel }

def assert (name : String) (cond : Bool) (msg : String := "") : IO Unit := do
  if cond then
    IO.println s!"[PASS] {name}"
  else
    throw (IO.userError s!"[FAIL] {name}: {msg}")

def testListModels [Lyceum.Core.TerminalEnv IO] : IO Unit := do
  IO.println "[Test] LocalLeanTensorLlm.listModels"
  let result ← LlmBackend.listModels mockLlm
  match result with
  | Except.ok models =>
    assert "listModels returns expected model" (models == ["local-leantensor-gemma-4b"])
      s!"Expected ['local-leantensor-gemma-4b'], got {models}"
  | Except.error e =>
    throw (IO.userError s!"[FAIL] listModels failed: {e}")

def testStreamChatCompletion [Lyceum.Core.TerminalEnv IO] : IO Unit := do
  IO.println "[Test] LocalLeanTensorLlm.streamChatCompletion"
  
  -- Instead of mocking loadRawGemmaModel, we will create a test-specific instance
  -- of LocalLeanTensorLlm that has the gemmaModel pre-filled.
  let prefilledLlm : Lyceum.Inference.Gemma.Backend.LocalLeanTensorLlm :=
    { mockLlm with gemmaModel := some mockRawGemmaModel }

  let history : List Message := [Message.mkText .user "Hello world"]
  let result ← LlmBackend.streamChatCompletion prefilledLlm history none
  
  match result with
  | Except.ok messages =>
    assert "streamChatCompletion returns a message" (messages.length == 1)
      s!"Expected 1 message, got {messages.length}"
    assert "streamChatCompletion message is assistant role" (messages[0]!.role == Lyceum.Role.assistant)
      s!"Expected assistant role, got {messages[0]!.role}"
    let content := messages[0]!.parts.map (fun p => match p with | .text t => t | _ => "") |>.foldl (· ++ ·) ""
    assert "streamChatCompletion message contains inference output" (content.contains "[Physical Inference]")
      s!"Expected '[Physical Inference]' in content, got {content}"
  | Except.error e =>
    throw (IO.userError s!"[FAIL] streamChatCompletion failed: {e}")

def runLocalLlmTests [Lyceum.Core.TerminalEnv IO] : IO UInt32 := do
  try
    testListModels
    testStreamChatCompletion
    return 0
  catch e =>
    IO.println s!"[CRITICAL] Local LLM Test failed: {e}"
    return 1

end Lyceum.Test
