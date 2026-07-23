# この型システムについて

`tprolog.pl` が実装している型システムを、既存の型理論・型システム研究の文脈に位置づけて整理したメモです。

## 経緯

最初は、多相ヴァリアント(polymorphic variant)をPrologの型システムに適用したらどうなるかという発想から実装を始めました。
作っていくうちに、どうも列多相(row polymorphism)が無くても成立する部分型付けの型システムになっていき、その路線で機能を追加していきました。
その後、型を述語論理として(パーサとは別に)独立に書けるようにした方が良いだろうと考えて書き換えていったところ、出来上がった仕組みがλPrologの型システムに似ていることに気づきました。
そこからカインド(kind)の概念も取り入れることにしました。
これが現状の型システムの成り立ちです。

## タグなし構造的共用型 + 簡易カインドシステム

`T ::= A | B | ...` で宣言したカインドは、値がどの構成子由来かを示すタグを持ちません。
「値が集合(カインド)に属していればよい」という**意味論的な部分型付け(semantic subtyping)** によって判定されます。
これは OCaml のタグ付きバリアントとは系譜が異なり、TypeScript の union 型に近い設計です。

- Frisch, A., Castagna, G., & Benzaken, V. (2008). *"Semantic Subtyping: Dealing Set-Theoretically with Function, Union, Intersection, and Negation Types."* ACM TOPLAS 30(3).
  union/intersection 型を集合論的に定義する枠組みです。タグなしで union 型に部分型付けする発想が直接対応します。
- Pierce, B. C. (2002). *Types and Programming Languages.* MIT Press. (Ch.11 variants, Ch.15 部分型付け)
  variant 型・部分型付けの標準的教科書リファレンスです。

加えて `check_kind_decl`/`check_kind_con` が行っている「構成子の引数が全てカインドであること」の検証は、System Fω のような**カインドシステム**の簡易版です。

- Girard, J.-Y. (1972). *Interprétation fonctionnelle et élimination des coupures dans l'arithmétique d'ordre supérieur.*
  System F の起源であり、後に Fω へ拡張されました。
- Pierce, B. C. (2002). *TaPL*, Ch.29–31 "Type Operators and Kinding."

なお、この仕組みは行変数(row variable)による拡張可能レコード/バリアントではないので、**厳密には行多相(row polymorphism)ではありません**。
行多相を指すなら以下が定番です。

- Wand, M. (1987). *"Complete Type Inference for Simple Objects."* LICS.
- Rémy, D. (1989). *"Type inference for records in a natural extension of ML."*
- Leijen, D. (2005). *"Extensible records with scoped labels."*

## λPrologの型システムとの関係

`kind/1` と `check_kind_decl`/`check_kind_con` を導入するきっかけになったのが λProlog の型システムです。
λProlog では、`kind list type -> type.` のように型構成子自体の種(kind)を宣言し、`type cons A -> list A -> list A.` のように各構成子の型を宣言します。
`tprolog.pl` の `::=` 宣言は、この「型構成子の kind 宣言」と「各構成子の型宣言」をまとめて1つの記法で行っていると言えます。
`check_kind_con` が「構成子の引数が全てカインドであること」を検証しているのも、λProlog の kind チェック(型構成子への型の適用が正しい kind を持つかどうかの検査)に対応します。
ただし λProlog は単純型付きラムダ計算(高階の項を含む)の型検査であり、部分型付けは持ちません。
一方 `tprolog.pl` は部分型付けによるタグなし共用型を中心に据えている点が異なります。

- Nadathur, G., & Miller, D. (1988). *"An Overview of λProlog."* Proceedings of the 5th International Conference and Symposium on Logic Programming (ICLP/SLP).
- Miller, D., & Nadathur, G. (2012). *Programming with Higher-Order Logic.* Cambridge University Press.
  λProlog の kind/type 宣言の仕組みが体系的にまとめられています。

## Mercuryとの対比

Mercury は Prolog系の言語に Hindley–Milner 風の多相型システムを載せた処理系で、型はタグ付きの代数的データ型(discriminated union)として宣言します。
`tprolog.pl` がタグなしの構造的共用型を採用しているのとは対照的です。
Mercury のようなタグ付き多相型システムの起源として、しばしば以下の論文が引用されます。

- Mycroft, A., & O'Keefe, R. A. (1984). *"A polymorphic type system for Prolog."* Artificial Intelligence 23(3).
  Prolog にタグ付きの多相型システムを載せる先駆的な提案であり、Mercury の型システムの直接の祖先にあたります。
- Somogyi, Z., Henderson, F., & Conway, T. (1996). *"The execution algorithm of Mercury: an efficient purely declarative logic programming language."* Journal of Logic Programming 29(1-3).
  Mercury 自体の型・モード・決定性システムを含む処理系全体の解説です。

## 既知の限界: 高階述語(phrase/2 など)は型付けできない

`tprolog.pl` は DCG規則(`-->`)自体は自前で `dcg_translate_rule/2` により変換して型付けできる(`examples/copl/EvalML1.pl` の `tok`/`tokens`/`expr` などで実施済み)。
しかし `phrase(tokens(Tokens), Code)` のように、非終端記号を **reified call**(データとして再構成した呼び出し)として `phrase/2` に渡す形は型付けできない。

`tp/3` がその値(`tokens(Tokens)`)を構成子(kind)として型付けしようとして必ず失敗するためである。
`tokens` は述語シグネチャ(`tokens ::: [Args...]` という引数型リストの形)として登録されているだけで、構成子としての事実(`tokens ::: Args->結果型` という矢印の形)が存在しない。
同じ名前が「呼び出せる述語」と「`phrase` に渡すデータ」の二重の役割を持ってしまうのが根本原因で、`tprolog` の型システムには「呼び出し可能な値(callable)」を表現する概念が無いことに起因する。

現状の回避策は、`phrase/2` を使わず、DCG変換後の3引数の述語として `tokens(Tokens, Code, [])` のように直接呼ぶ形に書き換えることである(`code_result/2` で実施済み)。
callable型のサポート(あるいは `phrase/2` の特別扱い)は今後の課題として残っている。

## まとめ

「**タグなし構造的共用型による部分型付けに、λProlog由来の簡易カインドシステムを組み合わせたもの**」と言えます。
Mercury のようなタグ付き多相型システムとは異なる系譜にあります。
