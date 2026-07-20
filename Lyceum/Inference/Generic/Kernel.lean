import LeanTensor
import Lyceum.Types
import Lyceum.Inference.Generic.Architecture
import Lyceum.Inference.Generic.KVCache
import Lyceum.Inference.Native
import Std.Data.HashMap

namespace Lyceum.Inference.Generic.Kernel

open LeanTensor
open Lyceum.Inference.Native

/-- テンソルの形状変換 (物理サイズ不変の証明付) --/
def flatten {n : Nat} (t : Tensor [1, n]) : Tensor [n] :=
  { val := t.val, prop := by have p := t.prop; simp [Shape.prod, List.prod] at p |-; exact p }

def expand {n : Nat} (t : Tensor [n]) : Tensor [1, n] :=
  { val := t.val, prop := by have p := t.prop; simp [Shape.prod, List.prod] at p |-; exact p }

/-- 物理的な回転行列の適用 (RoPE) --/
def applyRoPE (val : Array Float) (hSize : Nat) (pos : Nat) : Array Float :=
  let half := hSize / 2
  Array.ofFn (n := hSize) (fun idx =>
    let i := idx.val
    let theta := pos.toFloat / (Float.pow 10000.0 ((i % half).toFloat * 2.0 / hSize.toFloat))
    if i < half then
      val[i]! * Float.cos theta - val[i + half]! * Float.sin theta
    else
      val[i - half]! * Float.sin theta + val[i]! * Float.cos theta
  )

/-- 生テンソルのJITデコード --/
def dequantize (tensor : RawQuantizedTensor) : IO (FloatArray) := do
  let expectedSize := tensor.dims.foldl (· * ·) 1
  match tensor.qType with
    | .F32  => pure (decodeF32Native tensor.data (UInt64.ofNat expectedSize))
    | .Q1_K => pure (decode1bitNative tensor.data (UInt64.ofNat expectedSize))
    | _     => pure FloatArray.empty

/-- 
1 Transformerレイヤーの物理推論。
QKV射影、RoPE適用、KVキャッシュ更新、Attention、FFN の全工程を導通させる。
--/
def runLlamaLayer (model : RawGenericModel) (layerIdx : Nat) (input : Tensor [1, model.arch.hiddenSize]) (cache : GenericKVCache) (pos : Nat)
  : IO (Except AppError (Tensor [1, model.arch.hiddenSize] × GenericKVCache)) := do

  let hSize := model.arch.hiddenSize

  -- 1. RMSNorm
  let norm_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.attention_norm.weight"
  let some norm_w_raw_tensor := norm_w_raw_opt | return Except.error (AppError.ModelError s!"Missing norm weight: layers.{layerIdx}.attention_norm.weight")
  let norm_w_raw ← dequantize norm_w_raw_tensor
  if h_norm : norm_w_raw.data.size = hSize then
    let x_normed := LeanTensor.rmsnorm (flatten input) { val := norm_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_norm }
    let x_2d := expand x_normed
    
    -- 2. QKV Projection
    let q_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.attention.wq.weight"
    let k_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.attention.wk.weight"
    let v_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.attention.wv.weight"
    
    let some q_w_raw_tensor := q_w_raw_opt | return Except.error (AppError.ModelError "Missing Q weight")
    let some k_w_raw_tensor := k_w_raw_opt | return Except.error (AppError.ModelError "Missing K weight")
    let some v_w_raw_tensor := v_w_raw_opt | return Except.error (AppError.ModelError "Missing V weight")

    let q_w_raw ← dequantize q_w_raw_tensor
    let k_w_raw ← dequantize k_w_raw_tensor
    let v_w_raw ← dequantize v_w_raw_tensor
    
    if h_qkv : q_w_raw.data.size = hSize * hSize ∧ k_w_raw.data.size = hSize * hSize ∧ v_w_raw.data.size = hSize * hSize then
      -- Q = x * Wq, K = x * Wk, V = x * Wv
      let q := (LeanTensor.matmul x_2d { val := q_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_qkv.left }).val
      let k := (LeanTensor.matmul x_2d { val := k_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_qkv.right.left }).val
      let v := (LeanTensor.matmul x_2d { val := v_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_qkv.right.right }).val
      
      -- RoPE
      let q_rope := applyRoPE q hSize pos
      let k_rope := applyRoPE k hSize pos
      
      -- 3. Cache Update & Attention
      match updateCacheLayer cache layerIdx k_rope v with
      | Except.error e => return Except.error e
      | Except.ok updated_cache =>
          if h_cache : layerIdx < updated_cache.keys.size ∧ layerIdx < updated_cache.values.size then
            let k_full := updated_cache.keys[layerIdx]'h_cache.left
            let scores := attentionScoresNative (FloatArray.mk q_rope) k_full hSize
            
            if h_score : scores.data.size = scores.size then
              let probs := @LeanTensor.NN.softmax 1 scores.size { val := scores.data, prop := by simp [Shape.prod]; exact h_score }
              let v_full := updated_cache.values[layerIdx]'h_cache.right
              let context := weightedSumNative (FloatArray.mk probs.val) v_full hSize
              
              if h_ctx : context.data.size = hSize then
                -- 4. O Projection
                let o_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.attention.wo.weight"
                let some o_w_raw_tensor := o_w_raw_opt | return Except.error (AppError.ModelError "Missing O weight")
                let o_w_raw ← dequantize o_w_raw_tensor
                if h_o : o_w_raw.data.size = hSize * hSize then
                  let attn_out := @LeanTensor.matmul 1 hSize hSize (expand { val := context.data, prop := by simp [hSize, Shape.prod]; exact h_ctx }) { val := o_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_o }
                  let x_res1 := LeanTensor.add input attn_out
                  
                  -- 5. FFN
                  let ffn_norm_w_raw_opt := model.tensors.get? s!"layers.{layerIdx}.ffn_norm.weight"
                  let some ffn_norm_w_raw_tensor := ffn_norm_w_raw_opt | return Except.error (AppError.ModelError "Missing FFN norm")
                  let ffn_norm_w_raw ← dequantize ffn_norm_w_raw_tensor
                  
                  if h_ffn_norm : ffn_norm_w_raw.data.size = hSize then
                    let x_ffn_normed := LeanTensor.rmsnorm (flatten x_res1) { val := ffn_norm_w_raw.data, prop := by simp [hSize, Shape.prod]; exact h_ffn_norm }
                    
                    let w1_raw_opt := model.tensors.get? s!"layers.{layerIdx}.feed_forward.w1.weight"
                    let w3_raw_opt := model.tensors.get? s!"layers.{layerIdx}.feed_forward.w3.weight"
                    let w2_raw_opt := model.tensors.get? s!"layers.{layerIdx}.feed_forward.w2.weight"
                    
                    let some w1_w_raw_tensor := w1_raw_opt | return Except.error (AppError.ModelError "Missing W1")
                    let some w3_w_raw_tensor := w3_raw_opt | return Except.error (AppError.ModelError "Missing W3")
                    let some w2_w_raw_tensor := w2_raw_opt | return Except.error (AppError.ModelError "Missing W2")
                    
                    let w1_raw ← dequantize w1_w_raw_tensor
                    let w3_raw ← dequantize w3_w_raw_tensor
                    let w2_raw ← dequantize w2_w_raw_tensor
                    
                    if h_ffn_w : w1_raw.data.size = hSize * hSize ∧ w3_raw.data.size = hSize * hSize ∧ w2_raw.data.size = hSize * hSize then
                       let x_ffn_2d := expand x_ffn_normed
                       let gated := @LeanTensor.matmul 1 hSize hSize x_ffn_2d { val := w1_raw.data, prop := by simp [hSize, Shape.prod]; exact h_ffn_w.left }
                       let up    := @LeanTensor.matmul 1 hSize hSize x_ffn_2d { val := w3_raw.data, prop := by simp [hSize, Shape.prod]; exact h_ffn_w.right.left }
                       let activated_data := siluNative (FloatArray.mk gated.val) |>.data
                       if h_act : activated_data.size = hSize then
                         let activated := LeanTensor.mul { val := activated_data, prop := by simp [hSize, Shape.prod]; exact h_act } up
                         let ffn_out := @LeanTensor.matmul 1 hSize hSize activated { val := w2_raw.data, prop := by simp [hSize, Shape.prod]; exact h_ffn_w.right.right }
                         return Except.ok (LeanTensor.add x_res1 ffn_out, updated_cache)
                       else return Except.error (AppError.ModelError "FFN activation mismatch")
                    else return Except.error (AppError.ModelError "FFN weight size mismatch")
                  else return Except.error (AppError.ModelError "FFN norm size mismatch")
                else return Except.error (AppError.ModelError "O weight size mismatch")
              else return Except.error (AppError.ModelError "Context size mismatch")
            else return Except.error (AppError.ModelError "Softmax size mismatch")
          else return Except.error (AppError.ModelError "Cache error")
    else return Except.error (AppError.ModelError "QKV weight size mismatch")
  else return Except.error (AppError.ModelError "Norm weight size mismatch")

end Lyceum.Inference.Generic.Kernel
