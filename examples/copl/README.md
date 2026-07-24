# 書籍「プログラミング言語の基礎概念」の Prolog による実装(型付き)

『プログラミング言語の基礎概念』（五十嵐淳著、サイエンス社）を勉強するにあたり、各章で定義される言語（OCamlのサブセット）を 三土辰郎さんが Prolog で実装した
[copl-in-prolog](https://github.com/mitsuchi/copl-in-prolog)
を元にし、tprolog で型をつけた物です。

## 使い方

各ファイルは tprolog による型検査と、plunit によるテスト一式の実行までを行うようになっているので、実行するだけで動作を確認できます。

1. SWI-Prolog をインストールする
2. 各章に対応したプログラムを実行する(型検査とテストが自動で走り、終わると終了する)
  例）EvalML4

  ```bash
  $ swipl EvalML4.pl
  All kinds and clauses validated successfully!
  All kinds and clauses validated successfully!
  % Start unit: eval_ml4
  % [1/25] eval_ml4:1 ..42 => 42
  ..................................................... passed (0.001 sec)
  ...
  % End unit eval_ml4: passed (0.006 sec CPU)
  % All 25 tests passed in 0.017 seconds (0.009 cpu)
  ```

個別にコードを試したい場合は、対話環境で `code_result/2`(または `test/2`)を直接呼び出すこともできます。

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

## 14. EvalContML1.pl

継続渡し形式(CPS)で EvalML1 相当の言語(整数演算・if式)を評価する実装です。継続を「フレームの積み重ね」(`>>`)として表現し、式を継続とともに評価する形(`e >> k`)と、値を継続へ渡す形(`v => k`)を判別しながら評価します。

例）

```ocaml
1 + 2 >> _ evalto 3
```

## 15. EvalLazyML3.pl / EvalML3-Lazy.pl

EvalML3 相当の言語(再帰関数)を遅延評価(call-by-need)で評価する実装です。関数適用の引数を `thunk(環境, 式)` として遅延させ、実際に値が必要になった時点で `force` して評価します。2つのファイルは同一内容です(plunit のテストユニット名のみ異なります)。

例）

```ocaml
let rec f = fun x -> f x + f x in let zero = fun y -> 0 in zero (f 3)
```

このコードは通常の評価(先行評価)では `f` が無限に自己適用されて止まりませんが、遅延評価では `zero` が引数を一度も使わないため、評価されずに `0` を返します。
