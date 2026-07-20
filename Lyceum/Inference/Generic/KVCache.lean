import LeanTensor
import Lyceum.Inference.Generic.Architecture
import Lyceum.Types

namespace Lyceum.Inference.Generic

/--
KVキャッシュの構造。内部データは FloatArray として保持。
--/
structure GenericKVCache where
  keys   : Array FloatArray
  values : Array FloatArray
deriving Inhabited

/--
KVキャッシュを管理するための状態オブジェクト。
--/
structure InferenceState where
  cache : Option GenericKVCache
  tokenCount : Nat
deriving Inhabited

/-- 
キャッシュから特定の層のテンソルを取得し、形状を検証する (物理的整合性)。
--/
def getCacheTensor (as : Array FloatArray) (idx : Nat) (seqLen : Nat) (hSize : Nat) 
  : Except AppError (LeanTensor.Tensor [seqLen, hSize]) := do
  if h_idx : idx < as.size then
    let data := as[idx]
    let expectedSize := seqLen * hSize
    if h_size : data.data.size = expectedSize then
      return { val := data.data, prop := by simp [LeanTensor.Shape.prod, List.prod]; exact h_size }
    else
      Except.error (AppError.ModelError s!"Cache size mismatch at index {idx}")
  else
    Except.error (AppError.ModelError s!"Cache layer index {idx} out of bounds")

/-- 
キャッシュの全層が物理的に整合しているかを検証する (Nomos 法の一種)。
--/
def verifyCache (self : GenericKVCache) : Except AppError Unit :=
  if self.keys.size ≠ self.values.size then
    Except.error (AppError.ModelError "Cache structural mismatch: keys and values size differ")
  else
    let rec verifyLayers (i : Nat) : Except AppError Unit :=
      if i < self.keys.size then
        if self.keys[i]!.data.size ≠ self.values[i]!.data.size then
          Except.error (AppError.ModelError s!"Cache structural mismatch at layer {i}")
        else
          verifyLayers (i + 1)
      else
        Except.ok ()
    verifyLayers 0

/-- 
キャッシュを物理的に更新する。
--/
def updateCacheLayer (self : GenericKVCache) (idx : Nat) (k v : Array Float) 
  : Except AppError GenericKVCache := do
  if h : idx < self.keys.size ∧ idx < self.values.size then
    let newK := self.keys[idx].data ++ k
    let newV := self.values[idx].data ++ v
    let updated := { 
      keys := self.keys.set idx (FloatArray.mk newK) h.left,
      values := self.values.set idx (FloatArray.mk newV) h.right 
    }
    -- Nomos Contract Check: Verify invariant post-update
    match verifyCache updated with
    | Except.error e => Except.error e
    | Except.ok () => Except.ok updated
  else
    Except.error (AppError.ModelError s!"Cache update index {idx} out of bounds")

end Lyceum.Inference.Generic
