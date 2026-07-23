:- use_module('../tprolog').

% =====================================================================
% tprolog.pl の DCG(--> )対応をテストするファイル。
% 非終端記号名にシグネチャが宣言されているDCG規則だけ、
% term_expansion が自前で dcg_translate_rule/2 により変換し、
% 変換後の通常節(差分リスト引数が2つ増える)を型検査する仕組みを
% 直接検証する。
% docs/tprolog_union14.pl に埋め込んでいたデモ・テストを、実際に
% use_module(tprolog) して検証する形に移植したもの。
% =====================================================================

:- set_prolog_flag(double_quotes, chars).

% --- digit_tok//1: 1文字の数字を整数に変換するDCG規則 ---
digit_tok   ::= [int_t, list(atom_t), list(atom_t)].
code_type   ::= [atom_t, atom_t].
atom_number ::= [atom_t, int_t].
% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 のシグネチャ
% (これが無いと dcg_translate_rule で生成される S0=[C|S] のような
%  ゴールが型検査できず、digit_tok 全体が型エラーになってしまう)。
(=)         ::= [_, _].

digit_tok(I) --> [C], { code_type(C, digit), atom_number(C, I) }.

% --- ロード完了後のカインド・節の一括検証 ---
:- dynamic program_clause_check_results/1.
:- type_check_all(kinds(_)-clauses(ClauseResults)),
   assertz(program_clause_check_results(ClauseResults)).

:-begin_tests(dcg_clause_check).

% digit_tok//1(DCG規則)が実際に動作すること。
test(digit_tok_runs):-
    phrase(digit_tok(I), ['5'], []), I == 5.

% digit_tok//1 が typed_clause として型検査され、
% program_clause_check_results に(エラー無く)含まれていることの確認
% (dcg_translate_rule で変換された3引数の節として登録されているはず)。
test(digit_tok_is_type_checked):-
    program_clause_check_results(Results),
    member(ok((digit_tok(_,_,_):-_)), Results),
    \+ member(error(_,_,_,_), Results).

% 型の合わないDCG節を試しに検証してみる。digit_tok の結果は int_t
% でなければならないので、digit_tok(foo) は本来型エラーになるはずの節。
% (pending_clause_check への assertz は PLUnit のテスト本体が別モジュール
%  で実行されるため、そこで assertz するとグローバルな動的述語ではなく
%  別モジュール内のローカルな述語を作ってしまい check_all_clauses からは
%  見えなくなる。そのため dcg_translate_rule + try_check_clause/4 を
%  直接呼ぶ形にしている)。
test(deferred_bad_dcg_clause_is_detected):-
    dcg_translate_rule((digit_tok(foo) --> [_]), Translated),
    try_check_clause(Translated, demo_file, 1, Result),
    Result = error(Translated, demo_file, 1, failed).

% シグネチャの無いDCG規則(non-typed)は、term_expansion の DCG節に
% ある pred_sig(Name,_) のガードに引っかからず、従来通りSWI標準の
% DCG変換に素通しされて普通に動作することの確認
% (tprolog の型検査対象にはならない)。
untyped_dcg_demo(X) --> [X].
test(untyped_dcg_rule_still_works_via_standard_dcg):-
    phrase(untyped_dcg_demo(a), [a], []).

:-end_tests(dcg_clause_check).

:-run_tests.
:-halt.
