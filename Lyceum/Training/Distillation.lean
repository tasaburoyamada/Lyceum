import Lean
import Lyceum.Training.BitLinear

namespace Lyceum.Training.Distillation

open Lean
open Lyceum.Training.BitLinear

/-- Softmax 関数の計算 -/
def softmax (logits : Array Float) (temperature : Float := 1.0) : Array Float :=
  if logits.size == 0 then #[]
  else
    let maxVal := logits.foldl (fun acc v => if v > acc then v else acc) (-1e9)
    let exps := logits.map (fun v => Float.exp ((v - maxVal) / temperature))
    let sumExp := exps.foldl (· + ·) 0.0
    exps.map (fun e => e / (sumExp + 1e-8))

/-- KL-Divergence Loss (Teacher vs Student Logits) -/
def computeKLDivergenceLoss (teacherLogits studentLogits : Array Float) (temperature : Float := 1.0) : Id Float := do
  let pTeacher := softmax teacherLogits temperature
  let qStudent := softmax studentLogits temperature
  let mut loss : Float := 0.0
  for i in [:pTeacher.size] do
    let p := pTeacher.getD i 1e-8
    let q := qStudent.getD i 1e-8
    let klTerm := p * Float.log (p / (q + 1e-8))
    loss := loss + klTerm
  return loss * (temperature * temperature)

/-- 蒸留学習の 1 ステップ (Forward, KL Loss, STE Backward) -/
def trainDistillationStep
    (layer : BitLinearWeights)
    (inputData : Array Float)
    (teacherLogits : Array Float)
    (lr : Float)
    (temperature : Float := 1.0) : Id (BitLinearWeights × Float) := do
  -- 1. Student Forward (BitLinear 1.58-bit)
  let studentLogits := forwardBitLinear layer inputData

  -- 2. Loss 計算 (KL Divergence)
  let loss := computeKLDivergenceLoss teacherLogits studentLogits temperature

  -- 3. 蒸留勾配 (Softmax p - q 差分)
  let pTeacher := softmax teacherLogits temperature
  let qStudent := softmax studentLogits temperature
  let mut gradStudent : Array Float := #[]
  for i in [:studentLogits.size] do
    let diff := (qStudent.getD i 0.0) - (pTeacher.getD i 0.0)
    gradStudent := gradStudent.push diff

  -- 4. STE Backward & マスター重み更新
  let updatedLayer := backwardBitLinear layer inputData gradStudent lr
  return (updatedLayer, loss)

/-- BitNet QAT 蒸留学習セッション結果 -/
structure DistillationSessionResult where
  initialLoss : Float
  finalLoss : Float
  trainedEpochs : Nat
  gamma : Float
deriving Repr, Inhabited

/-- マルチエポック蒸留学習実行ループ -/
def runDistillationTraining
    (layer : BitLinearWeights)
    (dataset : List (Array Float × Array Float))
    (epochs : Nat)
    (lr : Float) : Id (BitLinearWeights × DistillationSessionResult) := do
  let mut currentLayer := layer
  let mut firstLoss : Float := 0.0
  let mut lastLoss : Float := 0.0

  for epoch in [:epochs] do
    let mut epochLossSum : Float := 0.0
    for (x, teacherOut) in dataset do
      let (nextLayer, stepLoss) := trainDistillationStep currentLayer x teacherOut lr 1.0
      currentLayer := nextLayer
      epochLossSum := epochLossSum + stepLoss

    let avgLoss := epochLossSum / (dataset.length.toFloat + 1e-5)
    if epoch == 0 then firstLoss := avgLoss
    lastLoss := avgLoss

  let res : DistillationSessionResult := {
    initialLoss := firstLoss,
    finalLoss := lastLoss,
    trainedEpochs := epochs,
    gamma := currentLayer.gamma
  }
  return (currentLayer, res)

end Lyceum.Training.Distillation
