namespace Lyceum

def base64Chars : String := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

def toBase64 (data : ByteArray) : String :=
  let b64List := base64Chars.toList
  let rec loop (i : Nat) (acc : String) : String :=
    if h : i < data.size then
      let b0 := data.get! i
      let b1 := if i + 1 < data.size then data.get! (i + 1) else 0
      let b2 := if i + 2 < data.size then data.get! (i + 2) else 0
      
      let n := b0.toNat * 65536 + b1.toNat * 256 + b2.toNat
      
      let c0 := b64List.getD (n / 262144 % 64) 'A'
      let c1 := b64List.getD (n / 4096 % 64) 'A'
      let c2 := if i + 1 < data.size then b64List.getD (n / 64 % 64) 'A' else '='
      let c3 := if i + 2 < data.size then b64List.getD (n % 64) 'A' else '='
      
      loop (i + 3) (acc.push c0 |>.push c1 |>.push c2 |>.push c3)
    else
      acc
  termination_by data.size - i
  loop 0 ""

def fromBase64 (_s : String) : ByteArray := ByteArray.empty

end Lyceum
