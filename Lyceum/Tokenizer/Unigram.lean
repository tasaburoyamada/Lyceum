import Lyceum.Tokenizer.Vocab
import Lyceum.Types

open Lyceum

namespace Lyceum.Tokenizer.Unigram

open Lyceum.Tokenizer

/-- Viterbi アルゴリズムのためのノード -/
structure ViterbiNode where
  id : Nat
  score : Float
  prev : Option Nat -- 直前のノードのインデックス
deriving Repr, Inhabited

/-- 日本語特有の正規化 (Full-width -> Half-width, etc) -/
def normalizeJapanese (text : String) : String := Id.run do
  let mut res := ""
  for c in text.toList do
    let val := c.toNat
    if val >= 0xFF01 && val <= 0xFF5E then
      -- 全角英数を半角英数へ
      res := res.push (Char.ofNat (val - 0xFEE0))
    else if val == 0x3000 then
      -- 全角スペースを半角スペースへ
      res := res.push ' '
    else
      res := res.push c
  return res

/-- 
Unigram (SentencePiece) トークナイザーの実装。
Viterbi アルゴリズムを用いて、合計スコアが最大になる分割を選択する。
-/
partial def unigramTokenize (v : Vocab) (rawText : String) : List Nat := Id.run do
  let text := normalizeJapanese rawText
  let n := text.length
  if n == 0 then return []

  -- best_scores[i] : テキストの i 文字目までの最大スコア
  -- backpointers[i] : 最大スコアを達成した際の (token_id, prev_index)
  let mut bestScores : Array Float := Array.empty
  let mut backpointers : Array (Option (Nat × Nat)) := Array.empty

  -- 手動で配列を初期化
  for _ in [0:n + 1] do
    bestScores := bestScores.push (-1e15) -- より小さい値で初期化
    backpointers := backpointers.push none

  bestScores := bestScores.set! 0 0.0

  let chars := text.toList.toArray

  -- 前方向パス
  for i in [0:n] do
    let currentBestScore := bestScores[i]!
    if currentBestScore < -1e14 then continue

    -- 1. 語彙に基づくマッチング
    let mut currentSub := ""
    for j in [i:min (i + 100) n] do
      currentSub := currentSub.push chars[j]!
      if let some id := v.getId currentSub then
        let score := v.scores.find? id |>.getD 0.0
        let totalScore := currentBestScore + score
        let targetIdx := j + 1
        if totalScore > bestScores[targetIdx]! then
          bestScores := bestScores.set! targetIdx totalScore
          backpointers := backpointers.set! targetIdx (some (id, i))

    -- 2. Byte Fallback (マッチが見つからなかった、またはスコアが低い場合)
    -- マッチが全くない場合のみ Byte Fallback を行う
    let targetIdx := i + 1
    if bestScores[targetIdx]! < -1e14 then
      let c := chars[i]!
      let bytes := c.toString.toByteArray
      
      -- UTF-8 バイト単位で ID を取得
      let mut currentByteScore := currentBestScore
      
      let mut byteIds := []
      for b in bytes.toList do
        if let some bid := v.getByteId b then
          byteIds := bid :: byteIds
          -- 日本語(マルチバイト)のペナルティを緩和
          let penalty := if bytes.size > 1 then 2.0 else 10.0
          currentByteScore := currentByteScore - penalty 
        else
          byteIds := 3 :: byteIds
          currentByteScore := currentBestScore - 100.0
      
      if let some firstId := byteIds.reverse.head? then
         bestScores := bestScores.set! targetIdx currentByteScore
         backpointers := backpointers.set! targetIdx (some (firstId, i))

  -- 後ろ向きパス (バックトラッキング)
  let rec backtrack (curr : Nat) (acc : List Nat) : List Nat :=
    if curr == 0 then acc else
    match backpointers[curr]! with
    | some (id, prev) => backtrack prev (id :: acc)
    | none => acc

  backtrack n []

end Lyceum.Tokenizer.Unigram
