import Lyceum.Tokenizer.Vocab

namespace Lyceum.Tokenizer

open Lyceum.Tokenizer.Vocab

/-- 
トークナイザーの正規化処理。
- 空白のメタ文字変換 (` ` -> ` `)
-/
def normalize (text : String) (addSentencePiecePrefix : Bool := true) : String :=
  let text := if addSentencePiecePrefix then " " ++ text else text
  -- U+0020 (Space) を U+2581 (Lower One Eighth Block ' ') に置換
  text.replace " " " "

/-- 
デコード時の正規化解除。
トークンリストから復元された文字列を受け取り、
バイトトークン (<0xNN>) の復号とメタ文字の空白戻しを行う。
-/
def denormalize (v : Vocab) (tokens : List String) : String := Id.run do
  let mut bytes : ByteArray := ByteArray.empty
  
  for token in tokens do
    match Vocab.parseByteToken token with
    | some b => 
        bytes := bytes.push b
    | none =>
        -- メタ文字を置換してからバイト列に変換
        let processed := token.replace " " " "
        bytes := bytes ++ processed.toByteArray
  
  -- バイト列から文字列へ復元（ダミープリフィックスをトリム）
  let result := String.fromUTF8! bytes
  if result.startsWith " " then
    String.ofList (result.toList.drop 1)
  else
    result

end Lyceum.Tokenizer
