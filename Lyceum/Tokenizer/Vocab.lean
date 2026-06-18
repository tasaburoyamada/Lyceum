import Lyceum.Types

open Lyceum

namespace Lyceum.Tokenizer

/-- トークンの属性情報 -/
inductive TokenType where
  | undefined | normal | unknown | control | userDefined | byte | unused
deriving BEq, Repr, Inhabited

/-- Float のための Ord インスタンス (Lean 4 標準にない場合用) -/
instance : Ord Float where
  compare x y :=
    if x < y then Ordering.lt
    else if x > y then Ordering.gt
    else Ordering.eq

/-- 語彙データ構造 (Lean 標準の RBMap を使用) -/
structure Vocab where
  tokenToId : Lean.RBMap String Nat Ord.compare
  idToToken : Lean.RBMap Nat String Ord.compare
  scores    : Lean.RBMap Nat Float Ord.compare
  types     : Lean.RBMap Nat TokenType Ord.compare
deriving Inhabited, Repr

/-- 空の語彙を作成 -/
def emptyVocab : Vocab := {
  tokenToId := Lean.RBMap.empty,
  idToToken := Lean.RBMap.empty,
  scores    := Lean.RBMap.empty,
  types     := Lean.RBMap.empty
}

/-- 語彙にトークンを追加 -/
def Vocab.add (v : Vocab) (id : Nat) (token : String) (score : Float) (type : TokenType) : Vocab := {
  tokenToId := v.tokenToId.insert token id,
  idToToken := v.idToToken.insert id token,
  scores    := v.scores.insert id score,
  types     := v.types.insert id type
}

/-- トークン文字列から ID を取得 -/
def Vocab.getId (v : Vocab) (token : String) : Option Nat :=
  v.tokenToId.find? token

/-- ID からトークン文字列を取得 -/
def Vocab.getToken (v : Vocab) (id : Nat) : Option String :=
  v.idToToken.find? id

/-- 
バイト値 (0-255) に対応するトークン ID を検索する。
Gemma 等のモデルでは <0xNN> という形式で語彙に含まれている。
-/
def Vocab.getByteId (v : Vocab) (b : UInt8) : Option Nat :=
  let hex := (Nat.toDigits 16 b.toNat)
  let hexStr := if hex.length == 1 then "0" ++ String.ofList hex else String.ofList hex
  let token := "<0x" ++ hexStr.toUpper ++ ">"
  v.getId token

/-- 
トークン文字列がバイト表現（<0xNN>）である場合、そのバイト値を返す。
-/
def Vocab.parseByteToken (token : String) : Option UInt8 :=
  if token.startsWith "<0x" && token.endsWith ">" && token.length == 6 then
    let hexPart := token.toList.drop 3 |>.take 2
    -- 16進数文字列を数値に変換（簡易実装）
    let hexToNat (c : Char) : Nat :=
      if c >= '0' && c <= '9' then c.toNat - '0'.toNat
      else if c >= 'A' && c <= 'F' then c.toNat - 'A'.toNat + 10
      else if c >= 'a' && c <= 'f' then c.toNat - 'a'.toNat + 10
      else 0
    match hexPart with
    | [h, l] => some (UInt8.ofNat (hexToNat h * 16 + hexToNat l))
    | _ => none
  else
    none

/-- 物理的なトークナイザー実装 -/
structure Tokenizer where
  modelName : String
  vocab : Vocab
deriving Inhabited, Repr

end Lyceum.Tokenizer
