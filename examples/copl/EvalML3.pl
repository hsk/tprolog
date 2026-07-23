:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(700,xfx, is).
:- op(800,xfx, ⇩).
:- op(800,xfx, plus).
:- op(800,xfx, minus).
:- op(800,xfx, times).
:- op(800,xfx, lessThan).
:- op(900,xfx, in).
:- op(990,xfx, ⱶ).
:- op(650, xfx, (=>)).   % => を中置演算子として宣言

% --- tok/tokens/digit の型 (EvalML2.pl と同じ) ---
% 値: 真偽値アトム(bool_v)。
bool_v ::= true | false.

% トークンの種類。記号・キーワードは int(_)/bool(_)/var(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める
% (EvalML1.pl と同じ理由: 個別登録すると tp/3 のカットで汎用の
%  atom_t として分類できなくなるため)。
tok_type ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | atom_t.

% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 と '[|]' のシグネチャ
% (これが無いと dcg_translate_rule で生成される S0=[C|S] のような
%  ゴールが型検査できず、digit/tok 全体が型エラーになってしまう)。
'[|]'     ::= [A,list(A)]->list(A).
(=)       ::= [X, X].
(!)       ::= [].

% tok//1 は DCG規則だが、tprolog は非終端記号名にシグネチャが
% あるものだけ自前で dcg_translate_rule/2 により変換して型検査する。
% DCGは差分リストを引数として引き回すため、実際のアリティは
% 元の非終端記号の引数 + 2 (S0, S) になる。
tok    ::= [tok_type, list(atom_t), list(atom_t)].
digits ::= [list(atom_t), list(atom_t), list(atom_t)].
digit  ::= [atom_t, list(atom_t), list(atom_t)].
% tokens//1 は tok//1 を呼び出してトークン列を作る、tok と同じ形の
% 差分リストを引き回す再帰的なDCG規則。
tokens ::= [list(tok_type), list(atom_t), list(atom_t)].

% 変数名(alpha_alnums)を綴るためのDCG規則。
% tok(var(Cs)) が呼ぶため、tok の型検査に合わせてシグネチャが必要。
alpha_alnums ::= [list(atom_t), list(atom_t), list(atom_t)].
alnums       ::= [list(atom_t), list(atom_t), list(atom_t)].
alpha        ::= [atom_t, list(atom_t), list(atom_t)].

% tok//1 の本体が呼ぶ組み込み述語のシグネチャ。
code_type    ::= [atom_t, atom_t].
number_chars ::= [int_t, list(atom_t)].

% --- 式(AST)とパーサの型 ---
% let(X = E1 in E2) は演算子の優先順位(in=900,==700)により実際には
%   let(in(=(X,E1), E2))
% という項になる(EvalML2.pl参照)。
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.
fun_abs  ::= (=>).
(=>)     ::= [list(atom_t), e]->fun_abs.

% 式(構文解析で得られるAST)。変数名は文字のリスト(list(atom_t))のまま。
e ::= int(int_t) | bool(bool_v) | var(list(atom_t))
    | e+e | e-e | e*e | (e<e) | if(e,e,e) | let(let_body)
    | letrec(let_body) | fun(fun_abs) | app(e, e).

% expr/expr1/term/term1/factor/factor1/farg は tokens//1 の出力(トークン列)を
% 読んで式 e を組み立てるDCG規則。差分リストは文字ではなくトークン列。
expr    ::= [e, list(tok_type), list(tok_type)].
expr1   ::= [e, e, list(tok_type), list(tok_type)].
term    ::= [e, list(tok_type), list(tok_type)].
term1   ::= [e, e, list(tok_type), list(tok_type)].
factor  ::= [e, list(tok_type), list(tok_type)].
factor1 ::= [e, e, list(tok_type), list(tok_type)].
farg    ::= [e, list(tok_type), list(tok_type)].

% --- 評価の型 (EvalML2.pl + クロージャ) ---
% 値: 整数・真偽値、またはクロージャ。
% cls(C, fun(X=>E)) と cls(C, X=fun(Y=>E)) (letrec用) の2形がある。
v ::= int_t | bool_v | cls(env, e) | cls(env, binding).

% 評価環境 C は (変数名 = 値) のペアのリスト。
env_binding ::= (list(atom_t) = v).
env ::= list(env_binding).

% 'C ⱶ E ⇩ V' は実際には ⱶ(C, ⇩(E,V)) という項になるので、
% ⇩(e,v) の形を eval_pair としてカインド登録しておく。
eval_pair ::= (e ⇩ v).

% plus/minus/times/lessThan は 'I1 plus I2 is I3' という中置記法で
% 書かれているが、plus 等(800,xfx) は is(700,xfx) より優先順位の
% 数値が小さい(=強く結合する)ため、実際には
%   plus(I1, is(I2,I3))
% という項に展開される。結果型を汎用の _V で受け付ける。
result_is ::= is(int_t, _V).

(+)      ::= [int_t,int_t] -> int_t.
(-)      ::= [int_t,int_t] -> int_t.
(*)      ::= [int_t,int_t] -> int_t.
is       ::= [int_t,int_t].
(<)      ::= [int_t,int_t].
plus     ::= [int_t, result_is].
minus    ::= [int_t, result_is].
times    ::= [int_t, result_is].
lessThan ::= [int_t, result_is].
(ⱶ)      ::= [env, eval_pair].
(\==)    ::= [X, X].

% --- UI (code_result/2 等) の型 ---
% string_chars/2 の第1引数はSWIのstringオブジェクトで、tp/3 に対応する
% 節が無い(atomでもリストでもcompoundでもない)ため、汎用にする。
string_chars ::= [_, list(atom_t)].
code_result  ::= [list(atom_t), v].
code_expr    ::= [list(atom_t), e].
code_tokens  ::= [list(atom_t), list(tok_type)].
% test/check_and_report は writef/2 に list(atom_t) と v が混在する
% 引数リスト([Code,Expected]等)を渡す。tprolog の list(A) は同種の
% 要素しか表現できず、この「printf風の可変長・異種混在の引数リスト」
% は型付けできない(phrase/2のcallableと同様、この型システムの
% 表現力の限界)。そのため test/check_and_report はシグネチャを
% 与えず、型検査の対象外(untyped)のままにする。

% tokenize
tokens(Ts) --> " ", tokens(Ts).
tokens([T|Ts]) --> tok(T), !, tokens(Ts).
tokens([]) --> "".

tok(int(I)) --> digits(Cs), { number_chars(I, Cs) }.
tok(bool(true)) --> "true".
tok(bool(false)) --> "false".
tok(+) --> "+".
tok(=>) --> "->".
tok(-) --> "-".
tok(*) --> "*".
tok(<) --> "<".
tok('(') --> "(".
tok(')') --> ")".
tok(=) --> "=".
tok(if) --> "if".
tok(then) --> "then".
tok(else) --> "else".
tok(let) --> "let".
tok(in) --> "in".
tok(fun) --> "fun".
tok(rec) --> "rec".
tok(var(Cs)) --> alpha_alnums(Cs).

digits([C|Cs]) --> digit(C), digits(Cs).
digits([C])    --> digit(C).

digit(C)   --> [C], { code_type(C, digit) }.

alpha_alnums([C|Cs]) --> alpha(C), alnums(Cs).
alpha_alnums([C]) --> alpha(C).

% 元々は (alpha(C)|digit(C)) というDCGの選言(;/2に変換される)で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、;/2 を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、節を分ける形に書き換えている。
alnums([C|Cs]) --> alpha(C), alnums(Cs).
alnums([C|Cs]) --> digit(C), alnums(Cs).
alnums([C])    --> alpha(C).
alnums([C])    --> digit(C).

alpha(C) --> [C], { code_type(C, alpha) }.

% parse
expr(E)      --> term(T), expr1(T, E).
expr1(E1, E) --> "<", term(T), expr1(E1 < T, E).
expr1(E1, E) --> "+", term(T), expr1(E1 + T, E).
expr1(E1, E) --> "-", term(T), expr1(E1 - T, E).
expr1(E, E)  --> [].

term(T) --> factor(F), term1(F, T).
term1(E1, E) --> "*", term(T), expr1(E1 * T, E).
term1(E, E)  --> [].

factor(F) --> farg(A), factor1(A, F).
factor1(F1, F) --> farg(A), factor1(app(F1,A), F).
factor1(E, E) --> [].

farg(int(I)) --> [int(I)].
farg(bool(B)) --> [bool(B)].
farg(var(X)) --> [var(X)].
farg(E) --> "(", expr(E), ")".
farg(if(E1, E2, E3)) -->
    [if], expr(E1), [then], expr(E2), [else], expr(E3).
farg(let(X = E1 in E2)) --> [let, var(X), =], expr(E1), [in], expr(E2).
farg(letrec(X = fun(Y => E1) in E2)) -->
    [let, rec, var(X), =, fun, var(Y), =>], expr(E1), [in], expr(E2).
farg(fun(X => E)) --> [fun, var(X), =>], expr(E).

% eval
% 以下では環境を C とする (Context)
% C ⱶ i ⇩ i
_ ⱶ int(I) ⇩ I.

% C ⱶ b ⇩ b
_ ⱶ bool(B) ⇩ B.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 plus i2 is i3
% ------------------------------------------------
% C ⱶ e1 + e2 ⇩ i3
C ⱶ E1 + E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 plus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 minus i2 is i3
% -------------------------------------------------
% C ⱶ e1 - e2 ⇩ i3
C ⱶ E1 - E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 minus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 times i2 is i3
% -------------------------------------------------
% C ⱶ e1 * e2 ⇩ i3
C ⱶ E1 * E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 times I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 less than i2 is i3
% -----------------------------------------------------
% C ⱶ e1 < e2 ⇩ i3
C ⱶ E1 < E2 ⇩ B :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 lessThan I2 is B.

% C ⱶ e1 ⇩ true   C ⱶ e2 ⇩ v
% --------------------------
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, E2, _) ⇩ V :-
    C ⱶ E1 ⇩ true, C ⱶ E2 ⇩ V.

% C ⱶ e1 ⇩ false   C ⱶ e3 ⇩ v
% -----------------------------
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, _, E3) ⇩ V :-
    C ⱶ E1 ⇩ false, C ⱶ E3 ⇩ V.

% C ⱶ e1 ⇩ v1   C, x = v1 ⱶ e3 ⇩ v
% --------------------------------
% C ⱶ let x = e1 in e2 ⇩ v
C ⱶ let(X = E1 in E2) ⇩ V :-
    C ⱶ E1 ⇩ V1, [X = V1 | C] ⱶ E2 ⇩ V.

% C, x = (C)[rec x = fun y -> e1] ⱶ e2 ⇩ v
% ----------------------------------------
% C ⱶ let rec x = fun y -> e1 in e2 ⇩ v
C ⱶ letrec(X = fun(Y => E1) in E2) ⇩ V :-
    [X = cls(C, X = fun(Y => E1)) | C] ⱶ E2 ⇩ V.

% C, x = v ⱶ x ⇩ v
[X = V | _] ⱶ var(X) ⇩ V.

% (y != x)   C ⱶ x ⇩ v2
% ---------------------
% C, y = v1 ⱶ x ⇩ v2
[Y = _ | C] ⱶ var(X) ⇩ V :-
    Y \== X, C ⱶ var(X) ⇩ V.

% C ⱶ fun x -> e ⇩ (C) [fun x -> e]
C ⱶ fun(X => E) ⇩ cls(C, fun(X => E)).

% C ⱶ e1 ⇩ (C2) [fun x -> e0]
% C ⱶ e2 ⇩ v2   C2, x = v2 ⱶ e0 ⇩ v
% ---------------------------------
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, fun(X => E0)),
    C ⱶ E2 ⇩ V2,
    [X = V2 | C2] ⱶ E0 ⇩ V.

% C ⱶ e1 ⇩ (C2) [rec x = fun y -> e0]
% C ⱶ e2 ⇩ v2
% C2, x = (C2) [rec x = fun y -> e0], y = v2 ⱶ e0 ⇩ v
% ---------------------------------------------------
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, X = fun(Y => E0)),
    C ⱶ E2 ⇩ V2,
    [Y = V2, X = cls(C2, X = fun(Y => E0)) | C2] ⱶ E0 ⇩ V.

I1 plus I2 is I3 :- I3 is I1 + I2.
I1 minus I2 is I3 :- I3 is I1 - I2.
I1 times I2 is I3 :- I3 is I1 * I2.
% 元々は 'I1 < I2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :- I1 < I2, !.
_I1 lessThan _I2 is false.

% code_result 前までの型検査
:- type_check_all.

% UI
% phrase/2 は使わず、DCG変換後の3引数の述語として直接呼ぶ
% (tokens(Tokens,Code,[]) は phrase(tokens(Tokens),Code) と同じ意味。
%  phrase/2 は非終端記号を reified call として渡す高階述語で、
%  tprolog はcallableという概念を持たないため型付けできない)。
code_result(Code, Result) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []),
    [] ⱶ Expr ⇩ Result, !.

code_expr(Code, Expr) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []).

code_tokens(Code, Tokens) :-
    tokens(Tokens, Code, []).

% test
% test内(:-begin_tests/:-end_testsの中)ではdouble_quotes=charsが
% 効かず、文字列リテラルがSWIのstringオブジェクトのままになるため、
% string_chars/2で明示的にcharsのリストへ変換してからcode_result/2に
% 渡す(EvalML1.pl/EvalML2.plのtest/2と同じパターン)。
test(String, Expected) :-
    string_chars(String, Code),
    code_result(Code, Actual),
    check_and_report(Code, Expected, Actual).

% 元々は '(Expected = Actual -> ... ; ..., fail)' という if-then-else
% で書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、頭部でのユニフィケーション+カットの形
% (lessThan と同じパターン)に書き換えている。
check_and_report(Code, Expected, Expected) :- !, writef('%s => %w\n', [Code, Expected]).
check_and_report(Code, Expected, Actual) :-
    writef('%s => %w expected, but got %w\n', [Code, Expected, Actual]), fail.

% code_result/code_expr/code_tokens は type_check_all の後で
% 定義したので、ここでもう一度呼んでまとめて検証する。
:- type_check_all.

:- begin_tests(eval_ml3).
test(1):- test("42", 42).
test(2):- test("1 + 2", 3).
test(3):- test("3 + 4 - 2", 5).
test(4):- test("10 - 1 - 2", 7).
test(5):- test("1 + 2 * 3", 7).
test(6):- test("(1 + 2) * 3", 9).
test(7):- test("1 < 2", true).
test(8):- test("2 < 1", false).
test(9):- test("if 1 < 2 then 3 else 4", 3).
test(10):- test("if 2 < 1 then 3 else 4", 4).
test(11):- test("if true then 1 else 2", 1).
test(12):- test("if false then 1 else 2", 2).
test(13):- test("let x = 1 in x + 2", 3).
test(14):- test("let x = 1 in let y = 2 in x + y", 3).
test(15):- test("let x = 1 in let x = 2 in x + x", 4).
test(16):- test("let double = fun x -> x + x in double 1", 2).
test(17):- test("(fun x -> fun y -> x + y) 1 2", 3).
test(18):- test("let rec fact = fun n -> if n < 2 then 1 else n * fact (n - 1) in fact 5", 120).
test(19):- test("let rec fib = fun n -> if n < 2 then n else fib (n - 1) + fib (n - 2) in fib 10", 55).
% self-application による再帰(letrecを使わない書き方)。実際に計算される
% 値(3の階乗=6)を確認した上で、期待値として明示している。
test(20):- test("let fact = fun self -> fun n -> if n < 2 then 1 else n * self self (n - 1) in fact fact 3", 6).
test(21):- test("1", 1).
:- end_tests(eval_ml3).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
