import Lean
import Lyceum.Inference.Backend
import Lyceum.Inference.Generic.Architecture
import Lyceum.Inference.Generic.KVCache
import Lyceum.Inference.Generic.Loader
import Lyceum.Inference.Generic.Kernel
import Lyceum.Inference.Native
import Lyceum.Types
import Lyceum.Tokenizer.Vocab
import LeanTensor.Math.Tensor
import LeanTensor.Math.Shape
import Init.Data.Array.Basic
import Std.Data.HashMap

open Lyceum
open Lyceum.Inference
open Lyceum.Inference.Generic
open LeanTensor

namespace Lyceum.Test

def assert (name : String) (cond : Bool) (msg : String := "") : IO Unit := do
  if cond then
    IO.println s!"[PASS] {name}"
  else
    throw (IO.userError s!"[FAIL] {name}: {msg}")

def mockVocab : Lyceum.Tokenizer.Vocab :=
  Lyceum.Tokenizer.emptyVocab
  |>.add 0 "<s>" 0.0 .normal
  |>.add 1 "</s>" 0.0 .normal
  |>.add 2 " Hello" 0.0 .normal
  |>.add 3 " world" 0.0 .normal

def mockRawGenericModel : RawGenericModel :=
  let arch : ModelArchitecture := {
    name := "mock-model",
    vocabSize := 4,
    hiddenSize := 2,
    numLayers := 1,
    numHeads := 1,
    headDim := 1
  }
  let tensors : Std.HashMap String RawQuantizedTensor := {}
  
  let embd : RawQuantizedTensor := {
    name := "token_embd.weight",
    qType := .F32,
    dims := [4, 2],
    data := ByteArray.mk #[0, 0, 0, 0]
  }
  let tensors := tensors.insert embd.name embd
  
  let weights := [
    "layers.0.attention_norm.weight",
    "layers.0.attention.wq.weight", "layers.0.attention.wk.weight", "layers.0.attention.wv.weight", "layers.0.attention.wo.weight",
    "layers.0.ffn_norm.weight",
    "layers.0.feed_forward.w1.weight", "layers.0.feed_forward.w2.weight", "layers.0.feed_forward.w3.weight"
  ]
  
  let tensors := weights.foldl (fun acc name =>
    let dims := if name.contains "norm" then [2] else [2, 2]
    let t : RawQuantizedTensor := {
      name := name,
      qType := .F32,
      dims := dims,
      data := ByteArray.empty
    }
    acc.insert name t
  ) tensors
    
  { arch := arch, tensors := tensors }

def mockLlm : LocalLlm :=
  { modelPath := "/mock/model.gguf",
    tokenizerInstance := { modelName := "mock-tokenizer", vocab := mockVocab },
    template := .gemma,
    rawModel := some mockRawGenericModel }

def testListModels : IO Unit := do
  IO.println "[Test] LocalLlm.listModels"
  let backend : LlmBackend LocalLlm := inferInstance
  let result ← backend.listModels mockLlm
  match result with
  | Except.ok models =>
    assert "listModels returns expected model" (models == ["local-generic-1bit-llm"])
  | Except.error e =>
    throw (IO.userError s!"[FAIL] listModels failed: {e}")

def testStreamChatCompletion : IO Unit := do
  IO.println "[Test] LocalLlm.streamChatCompletion (Full Generative Loop)"
  
  let history : List Message := [Message.mkText .user "Hello"]
  let backend : LlmBackend LocalLlm := inferInstance
  let result ← backend.streamChatCompletion mockLlm history none
  
  match result with
  | Except.ok messages =>
    assert "Generative loop returns output" (List.length messages > 0)
    let content := Message.content (List.head! messages)
    IO.println s!"[Inference Result] {content}"
    assert "Output contains success marker" (content.contains "導通")
  | Except.error e =>
    throw (IO.userError s!"[FAIL] streamChatCompletion failed: {e}")

def testInferenceError : IO Unit := do
  IO.println "[Test] LocalLlm.testInferenceError (Negative Testing)"
  let badModel : LocalLlm := { mockLlm with rawModel := some { mockRawGenericModel with tensors := {} } }
  let history : List Message := [Message.mkText .user "Hello"]
  let backend : LlmBackend LocalLlm := inferInstance
  let result ← backend.streamChatCompletion badModel history none
  match result with
  | Except.error _ => IO.println "[PASS] InferenceError caught"
  | Except.ok _ => throw (IO.userError "[FAIL] InferenceError should have been returned")

def runLocalLlmTests : IO UInt32 := do
  try
    testListModels
    testStreamChatCompletion
    testInferenceError
    return 0
  catch e =>
    IO.println s!"[CRITICAL] Physical Local LLM Test failed: {e}"
    return 1

end Lyceum.Test
