import Lean
import Std

namespace Lyceum.Inference.Native

open Lean 
open Std 

/-- 
IEEE-754 準拠の Float32 ビットパターン物理再構成。
符号(1), 指数(8), 仮数(23) をビット演算で正確に抽出する。
--/
def bitsToFloat32 (bits : UInt32) : Float := Id.run do
  let s := (bits >>> 31) &&& 0x1
  let e := (bits >>> 23) &&& 0xFF
  let m := bits &&& 0x7FFFFF
  let sign := if s == 0 then 1.0 else -1.0
  if e == 255 then
    if m == 0 then return sign * (1.0 / 0.0) -- Inf
    else return 0.0 -- NaN
  else if e == 0 then
    if m == 0 then return sign * 0.0
    -- 非正規化数: sign * 2^-126 * (m / 2^23)
    else return sign * (m.toNat.toFloat / 8388608.0) * 1.1754943508222875e-38
  else
    -- 正規化数: sign * 2^(e-127) * (1 + m/2^23)
    let expVal := (Int.ofNat e.toNat) - 127
    let mantissa := 1.0 + (m.toNat.toFloat / 8388608.0)
    let mut factor := 1.0
    if expVal >= 0 then
      for _ in List.range expVal.toNat do factor := factor * 2.0
    else
      for _ in List.range (-expVal).toNat do factor := factor / 2.0
    return sign * mantissa * factor

/-- FloatArray の内積 -/
def dotProductNative (a b : @& FloatArray) : Float := Id.run do
  let mut sum := 0.0
  let size := min a.size b.size
  for i in List.range size do
    sum := sum + (a.get! i * b.get! i)
  return sum

/-- SiLU 活性化関数 -/
def siluNative (t : FloatArray) : FloatArray :=
  FloatArray.mk (t.data.map (fun x => x / (1.0 + Float.exp (-x))))

/-- Attention Score 計算 (物理ループ) -/
def attentionScoresNative (q : FloatArray) (k_cache : FloatArray) (hSize : Nat) : FloatArray := Id.run do
  if hSize == 0 then return FloatArray.empty
  let seqLen := k_cache.size / hSize
  let mut scores := Array.mkEmpty seqLen
  for i in List.range seqLen do
    let mut sum := 0.0
    let k_offset := i * hSize
    if k_offset + hSize <= k_cache.size && hSize <= q.size then
      for j in List.range hSize do
        sum := sum + (q.get! j * k_cache.get! (k_offset + j))
      scores := scores.push (sum / Float.sqrt hSize.toFloat)
  return FloatArray.mk scores

/-- Attention Weighted Sum (物理ループ) -/
def weightedSumNative (probs : FloatArray) (v_cache : FloatArray) (hSize : Nat) : FloatArray := Id.run do
  let seqLen := probs.size
  let mut res := Array.mkEmpty hSize
  for j in List.range hSize do
    let mut sum := 0.0
    for i in List.range seqLen do
      let v_idx := i * hSize + j
      if v_idx < v_cache.size then
        sum := sum + (probs.get! i * v_cache.get! v_idx)
    res := res.push sum
  return FloatArray.mk res

/-- ArgMax サンプリング -/
def argmaxNative (logits : FloatArray) : Nat := Id.run do
  let mut max_val := -1e38; let mut max_idx := 0
  for i in List.range logits.size do
    let val := logits.get! i
    if val > max_val then { max_val := val; max_idx := i }
  return max_idx

@[extern "lean_decode_f32_native"]
def decodeF32Native (bytes : @& ByteArray) (count : UInt64) : FloatArray := Id.run do
  let mut res := Array.mkEmpty count.toNat
  for i in List.range count.toNat do
    let offset := i * 4
    if offset + 3 < bytes.size then
      let b1 := bytes.get! offset; let b2 := bytes.get! (offset+1); let b3 := bytes.get! (offset+2); let b4 := bytes.get! (offset+3)
      let bits : UInt32 := (b4.toUInt32 <<< 24) ||| (b3.toUInt32 <<< 16) ||| (b2.toUInt32 <<< 8) ||| b1.toUInt32
      res := res.push (bitsToFloat32 bits)
    else res := res.push 0.0
  return FloatArray.mk res

@[extern "lean_matmul_native"]
def matmulNative (a b : @& FloatArray) (m k n : UInt64) : FloatArray := Id.run do
  let m_nat := m.toNat; let k_nat := k.toNat; let n_nat := n.toNat
  let res := Array.ofFn (n := m_nat * n_nat) (fun idx => Id.run do
    let i := idx.val / n_nat; let j := idx.val % n_nat
    let mut sum := 0.0
    for p in List.range k_nat do
      let a_idx := i * k_nat + p; let b_idx := p * n_nat + j
      if a_idx < a.size && b_idx < b.size then
        sum := sum + (a.get! a_idx * b.get! b_idx)
    return sum
  )
  return FloatArray.mk res

def decode1bitNative (bytes : @& ByteArray) (count : UInt64) : FloatArray := Id.run do
  let c := count.toNat
  let mut res := Array.mkEmpty c
  for i in List.range c do
    let byte_idx := i / 8; let bit_idx := i % 8
    if byte_idx < bytes.size then
      let b := bytes.get! byte_idx
      let v := (b.toNat >>> bit_idx) &&& 1
      res := res.push (if v == 1 then 1.0 else -1.0)
    else res := res.push 0.0
  return FloatArray.mk res

end Lyceum.Inference.Native
