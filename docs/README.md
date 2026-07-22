# docs/ について

このディレクトリは、git管理を始める前に行っていた試行錯誤をそのまま残した
「実験の記録」です。以後はこのディレクトリのファイルを編集せず、変更は
リポジトリルートの `tprolog.pl` とその利用例
(`sample.pl` / `stlc.pl` / `add.pl`) に対して行い、git のコミット/タグで
バージョンを追っていきます。

## おおまかな流れ

1. **`tprolog0.pl` → `tprolog1.pl` → `tprolog2.pl`**
   行多相(row polymorphism)を持つ簡易的な型システムの最初期の実験。
2. **`expand_bnf.pl` / `expand_bnf2.pl` / `expand_bnf copy.pl`**
   `::=` によるBNF風の型・述語シグネチャ宣言をterm_expansionで展開する
   仕組みの試作。
3. **`lambda.pl` → `lambda2.pl` → `lambda3.pl`**
   ラムダ計算・クロージャを持つ評価器の試作。
4. **`tprolog_union.pl` → `tprolog_union2.pl` 〜 `tprolog_union12.pl`**
   上記の要素を統合し、以下を段階的に導入していったメインの実験ライン。
   - `::=`宣言からの述語シグネチャ・型(カインド)の自動登録
   - カインドの宣言時整合性検証 (`check_kind_decl`)
   - 相互再帰する型のための遅延検証 (`check_all_kinds` によるまとめ検証)
   - 演算子オーバーロード時の誤判定の修正 (`+`/`*` など)
   - エイリアス判定の精緻化 (`is_true_alias_rhs`: 述語シグネチャ・
     既定義の型参照・`list/1`・単一構成子のnewtypeの区別)

## 現在の到達点

`tprolog_union12.pl` までの成果を汎用モジュール `tprolog.pl`
(`:- module(tprolog, [...])`) として切り出し、`sample.pl` /
`stlc.pl`(単純型付きラムダ計算) / `add.pl`(加算のみの最小言語) を
`:- use_module(tprolog).` で利用する形に整理しました。
今後の変更は `tprolog.pl` 側に対して行い、このディレクトリの
ファイルは参照専用の記録として扱います。
