import Lyceum.Tokenizer.Vocab

namespace Lyceum.Tokenizer

open Lyceum.Tokenizer.Vocab

/--
WordPiece トークナイズ。
BERT などのモデルで使用される、最長前方一致アルゴリズム。
-/
def wordPieceTokenize (v : Vocab) (text : String) : List Nat := Id.run do
  let words := text.splitOn " "
  let mut allTokens := []
  
  let unkId := v.getId "[UNK]" |>.getD 100 -- BERT default

  for word in words do
    if word.isEmpty then continue
    
    -- 1. そのまま語彙にあるかチェック
    if let some id := v.getId word then
      allTokens := id :: allTokens
      continue

    -- 2. サブワード分割
    let mut currentWord := word
    let mut wordTokens := []
    let mut isBad := false
    
    while !currentWord.isEmpty do
      let mut endIdx := currentWord.length
      let mut curTokenId : Option Nat := none
      
      while endIdx > 0 do
        let mut sub := currentWord.toList.take endIdx |> String.ofList
        if wordTokens.length > 0 then
          sub := "##" ++ sub
        
        if let some id := v.getId sub then
          curTokenId := some id
          break
        endIdx := endIdx - 1
      
      match curTokenId with
      | some id =>
          wordTokens := id :: wordTokens
          currentWord := currentWord.toList.drop endIdx |> String.ofList
      | none =>
          isBad := true
          break
    
    if isBad then
      allTokens := unkId :: allTokens
    else
      allTokens := wordTokens ++ allTokens

  return allTokens.reverse

end Lyceum.Tokenizer
