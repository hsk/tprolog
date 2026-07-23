:- use_module('../tprolog').

% =====================================================================
% 加算だけの最小限の言語を tprolog 上に実装する。
% =====================================================================

% --- 0. Prolog 組み込み述語のシグネチャ(節本体の型検査に必要) ---
(+)    ::= [int_t, int_t] -> int_t.
integer::= [_].
is     ::= [int_t, int_t].

% --- 1. 型 (ty) ---
% 型は tint の1種類しかないが、値の種類である int_t とは別に、
% 「型」を表す専用のトークン tint を持つ ty を定義しておく
% (int_t をそのまま型として使い回すと、int_t が整数値の種類を表す
%  組み込みのカインドとして特別扱いされているため、tp/3 が
%  「アトム int_t 自体を int_t 型の値として型付けする」ことに
%  失敗してしまう)。
ty ::= tint.

% --- 2. 式 (term) ---
term ::= int_t | term+term.

% --- 3. 単純型システム (typeof/2) ---
typeof ::= [term, ty].
typeof(I,tint):-integer(I).
typeof(E1+E2,tint):-typeof(E1,tint),typeof(E2,tint).

% --- 3. 大ステップ評価器 (eval/2) ---
eval ::= [term, int_t].
eval(I,I):-integer(I).
eval(E1+E2,I):-eval(E1,I1),eval(E2,I2),I is I1+I2.

% --- 4. ロード完了後のカインド一括検証 ---
:- type_check_all.

% --- 5. サンプルプログラム: (1+2)+(3+4) ---
sample_program((1+2)+(3+4)).

% --- 6. テスト ---
:- begin_tests(add).

test(typeof_whole):-
    sample_program(Whole),
    typeof(Whole,tint).

test(eval_whole):-
    sample_program(Whole),
    eval(Whole,V),
    V == 10.

% *-/2 は term に対して一切宣言していないので、
% typeof にこの節を足すと check/2 が「弾く」ことを確認する。
test(reject_undeclared_minus_clause):-
    \+ check(_, (typeof(E1-E2,tint):-typeof(E1,tint),typeof(E2,tint))).

test(reject_non_int_term):-
    \+ typeof(foo, tint).

:- end_tests(add).

:- run_tests.
:- halt.
