import Lean

namespace Lyceum.Training.BitLinear

open Lean

/-- BitNet b1.58 Ternary 値 {-1, 0, 1} -/
inductive BitTernary where
  | negOne
  | zero
  | posOne
deriving Repr, BEq, Inhabited

/-- BitTernary から Float への変換 -/
def BitTernary.toFloat : BitTernary → Float
  | .negOne => -1.0
  | .zero   => 0.0
  | .posOne => 1.0

/-- BitLinear 層の重みと構造 -/
structure BitLinearWeights where
  inFeatures : Nat
  outFeatures : Nat
  -- 実数マスター重み W_fp
  masterWeights : Array Float
  -- 量子化済み Ternary 重み W_tilde
  quantizedWeights : Array BitTernary
  -- スケールファクター gamma
  gamma : Float := 1.0
deriving Repr, Inhabited

/-- 実数値 x を BitTernary {-1, 0, 1} へ量子化 -/
def quantizeValue (val : Float) (gamma : Float) (eps : Float := 1e-5) : BitTernary :=
  let scaled := val / (gamma + eps)
  if scaled > 0.5 then .posOne
  else if scaled < -0.5 then .negOne
  else .zero

/-- 実数マスター重み W_fp 全体を BitTernary {-1, 0, 1} へ量子化しスケール gamma を計算 -/
def quantizeMasterWeights (master : Array Float) : (Array BitTernary × Float) :=
  if master.size == 0 then (#[], 1.0)
  else
    let sumAbs := master.foldl (fun acc w => acc + Float.abs w) 0.0
    let gamma := sumAbs / master.size.toFloat
    let qArray := master.map (fun w => quantizeValue w gamma)
    (qArray, gamma)

/-- BitLinear 重みの初期化 -/
def createBitLinear (inFeatures outFeatures : Nat) (initVal : Float := 0.01) : Id BitLinearWeights := do
  let size := inFeatures * outFeatures
  let mut master : Array Float := #[]
  for i in [:size] do
    let val := initVal * ((i % 5).toFloat - 2.0)
    master := master.push val
  let (qArr, g) := quantizeMasterWeights master
  return { inFeatures := inFeatures, outFeatures := outFeatures, masterWeights := master, quantizedWeights := qArr, gamma := g }

/-- 順伝播 (Forward Pass): Y = gamma * (W_tilde * X) -/
def forwardBitLinear (layer : BitLinearWeights) (x : Array Float) : Id (Array Float) := do
  let mut y : Array Float := #[]
  for outIdx in [:layer.outFeatures] do
    let mut sum : Float := 0.0
    for inIdx in [:layer.inFeatures] do
      let weightIdx := outIdx * layer.inFeatures + inIdx
      let qW := layer.quantizedWeights.getD weightIdx .zero |>.toFloat
      let inputVal := x.getD inIdx 0.0
      sum := sum + qW * inputVal
    y := y.push (layer.gamma * sum)
  return y

/-- 逆伝播 (Straight-Through Estimator: STE 勾配更新) -/
def backwardBitLinear (layer : BitLinearWeights) (x : Array Float) (gradOutput : Array Float) (lr : Float) : Id BitLinearWeights := do
  let mut newMaster := layer.masterWeights
  for outIdx in [:layer.outFeatures] do
    let dL_dy := gradOutput.getD outIdx 0.0
    for inIdx in [:layer.inFeatures] do
      let idx := outIdx * layer.inFeatures + inIdx
      let xVal := x.getD inIdx 0.0
      -- STE: dL/dW_fp ≈ dL/dY * gamma * X
      let gradW := dL_dy * layer.gamma * xVal
      let oldW := newMaster.getD idx 0.0
      let updatedW := oldW - lr * gradW
      newMaster := newMaster.set! idx updatedW

  let (newQ, newGamma) := quantizeMasterWeights newMaster
  return { layer with masterWeights := newMaster, quantizedWeights := newQ, gamma := newGamma }

end Lyceum.Training.BitLinear
