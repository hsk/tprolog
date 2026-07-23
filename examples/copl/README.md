# 書籍「プログラミング言語の基礎概念」の Prolog による実装(型付き)

『プログラミング言語の基礎概念』（五十嵐淳著、サイエンス社）を勉強するにあたり、各章で定義される言語（OCamlのサブセット）を 三土辰郎さんが Prolog で実装したものに、tprolog で型をつけた物です。

## 使い方

1. SWI-Prolog をインストールする
2. 各章に対応したプログラムを起動する
  例）EvalML4

  ```bash
  $ swipl EvalML4.pl
  ```

3. プロンプトで以下のようにコードを実行する

  ```ocaml
  ?- test("let x = 1 in x + 2", W).
  let x = 1 in x + 2 => 3
  W = 3.
  ```

4. またはテスト一式を実行する

  ```ocaml
  ?- tests.
  ..
  let x = 1 in x + 2 => 3
  let rec fib = fun n -> if n < 2 then n else fib (n - 1) + fib (n - 2) in fib 10 => 55
  ..
  true
  ```

## 1. Nat.pl

第1章の Nat の実装です。ペアノ自然数の足し算と掛け算を行います。

例）

```ocaml
s(z) plus s(z) is s(s(z))
```

## 2.3.4. CompareNat[1-3].pl

第1章の CompareNat1 から 3 までの実装です。ペアノ自然数どうしの大小を比較します。

例）

```ocaml
s(z) isLessThan s(s(z))
```

## 5. EvalNatExp.pl

第1章の EvalNatExp の実装です。足し算と掛け算からなる式を評価します。

例）

```ocaml
s(s(z)) + z ⇓ s(s(z))
```

## 6. ReduceNatExp.pl

第1章の ReduceNatExp の実装です。足し算と掛け算からなる式を簡約します。

例）

```ocaml
s(z) * s(z) + s(z) * s(z) --> s(z) * s(z) + s(z)
```

## 7. EvalML1.pl

第3章の EvalML1 の実装です。整数とif式を評価します。

例）

```ocaml
if 1 < 2 then 3 else 4
```

## 8. EvalML2.pl

第4章の EvalML2 の実装です。let式を評価します。

例）

```ocaml
let x = 1 in x + 2
```

## 9. EvalML3.pl

第5章の EvalML3 の実装です。（再帰的）関数の定義と適用を評価します。

例）

```ocaml
let rec fib = fun n -> if n < 2 then n else fib (n - 1) + fib (n - 2) in fib 10
```

## 10. EvalML4.pl

第7章の EvalML4 の実装です。リストとパターンマッチを評価します。

例）

```ocaml
match 1 :: 2 :: 3 :: [] with [] -> 4 | a :: b -> a
```

## 11. EvalML5.pl

第7章の EvalML5 の実装です。より一般的なパターンマッチを評価します。

例）

```ocaml
let rec max = fun l -> match l with 
  [] -> 0
  | x :: [] -> x
  | x :: y :: z -> if x < y
    then max (y :: z)
    else max (x :: z)
in max (1 :: 2 :: 3 :: [])
```

## 12. TypingML4.pl

第8章の TypingML4 の実装です。単相の型システムの型付けを判断します。

例）

```ocaml
fun f -> f 0 + f 1 : (int -> int) -> int
```

## 13. PolyTypingML4.pl

第9章の PolyTypingML4 の実装です。多相の型システムの型付けを判断します。

例）

```ocaml
let id = fun x -> x in id id : bool -> bool
```

おまけで型推論もできます。

例）

```prolog
?- infer("let k = fun x -> fun y -> x in k", W).
W = "ab.a->b->a" .
```
