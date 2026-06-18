import LeanTensor.Math.Tensor
import LeanTensor.Math.Shape
import LeanTensor.Math.Ops
import Lyceum.Types

namespace Lyceum.Inference.Gemma.Raw

open LeanTensor

/-- 実行時に読み込まれる未検証テンソル -/
structure RawTensor where
  dims : List Nat
  data : Array Float
deriving Inhabited, Repr

/-- Gemma用 Transformer 層 (未検証) -/
structure RawGemmaLayer where
  attn_q : RawTensor
  attn_k : RawTensor
  attn_v : RawTensor
  attn_o : RawTensor
  ffn_gate : RawTensor
  ffn_up : RawTensor
  ffn_down : RawTensor
  attn_norm : RawTensor
  post_attn_norm : RawTensor
  ffn_norm : RawTensor
  post_ffw_norm : RawTensor
deriving Inhabited, Repr

/-- Gemma モデル (未検証) -/
structure RawGemmaModel where
  token_embd : RawTensor
  layers : Array RawGemmaLayer
  norm_final : RawTensor
deriving Inhabited, Repr

/-- 
動的テンソルを検証し、コンパイル時に確定している Tensor 型へ昇格させる。
実モデルの語彙サイズが期待値より大きい場合は、安全にスライス（切り出し）検証を行うことで
メモリ(RAM)の消費を極小化しOOMを防止する。
-/
def promoteToVerified (t : RawTensor) (dims : List Nat) : Except Lyceum.AppError (Tensor dims) :=
  let t_dims := t.dims
  let t_data := t.data
  if t_dims.length == dims.length then
    let t_hidden := t_dims.getD 0 0
    let t_vocab := t_dims.getD 1 0
    let exp_hidden := dims.getD 0 0
    let exp_vocab := dims.getD 1 0
    
    if t_hidden == exp_hidden && t_vocab >= exp_vocab then
      let expected_size := Shape.prod dims
      let sliced_data := t_data.extract 0 expected_size
      if h_size : sliced_data.size = expected_size then
        Except.ok { val := sliced_data, prop := by simp [Shape.prod, h_size, expected_size] }
      else
        Except.error (Lyceum.AppError.ExecutionError s!"Data size error: sliced {sliced_data.size}, expected {expected_size}")
    else
      Except.error (Lyceum.AppError.ExecutionError s!"Dimension specification error: got {t_dims}, expected {dims}")
  else
    Except.error (Lyceum.AppError.ExecutionError s!"Dimension length mismatch: got {t_dims.length}, expected {dims.length}")

end Lyceum.Inference.Gemma.Raw
