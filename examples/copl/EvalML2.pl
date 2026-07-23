:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(700,xfx,is).
:- op(800,xfx,⇩).
:- op(800,xfx,plus).
:- op(800,xfx,minus).
:- op(800,xfx,times).
:- op(800,xfx,lessThan).
:- op(900,xfx,in).
:- op(990,xfx,ⱶ).

% --- 型 ---
% 値: 整数(int_t)そのもの、または真偽値アトム(bool_v)そのもの。
bool_v ::= true | false.
v ::= int_t | bool_v.

% let(X = E1 in E2) は 'C ⱶ let(X = E1 in E2) ⇩ V' のように書かれるが、
% 演算子の優先順位(in=900,==700)により実際には
%   let(in(=(X,E1), E2))
% という項になる(実際に write_canonical/1 で確認した)。
% X = E1 の部分を binding、in(binding,E2) の部分を let_body として
% それぞれカインド登録しておく。
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.

% 式(構文解析で得られるAST)。変数名は tok(var(Cs)) --> alpha_alnums(Cs)
% と同じく、文字のリスト(list(atom_t))のまま扱う(atomには変換しない)。
e ::= int(int_t) | bool(bool_v) | var(list(atom_t))
    | e+e | e-e | e*e | (e<e) | if(e,e,e) | let(let_body).

% トークンの種類。記号・キーワードは int(_)/bool(_)/var(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める
% (EvalML1.pl と同じ理由: 個別登録すると tp/3 のカットで汎用の
%  atom_t として分類できなくなるため)。
tok_type ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | atom_t.

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
% という項に展開される(minus/times/lessThan も同様)。
% plus/minus/times は結果が int_t、lessThan は結果が bool_v になるので、
% is(int_t,V) の V を汎用のプレースホルダにしておき、どちらの結果型でも
% 受け付けられるようにする(member/[|]/(:) と同じ「V を使い回す」パターン)。
result_is ::= is(int_t, _V).

% --- 述語シグネチャ ---
% env が list(env_binding) のエイリアスなので、リスト値をエイリアス
% 越しにチェックする際に '[|]' の署名が必要になる(env_binding や
% tenv 等、他のファイルでも繰り返し必要になった署名)。
'[|]'    ::= [A,list(A)]->list(A).
(!)      ::= [].
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

% --- tok の型 ---
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
alpha_alnums ::= [list(atom_t), list(atom_t), list(atom_t)].
alnums       ::= [list(atom_t), list(atom_t), list(atom_t)].
alpha        ::= [atom_t, list(atom_t), list(atom_t)].

% tok//1 の本体が呼ぶ組み込み述語のシグネチャ。
code_type    ::= [atom_t, atom_t].
number_chars ::= [int_t, list(atom_t)].
% (=)/2 は両辺が同じ型でなければならないので、独立した2つの無名変数
% [_,_] ではなく、同じ変数 [X,X] を共有させる(EvalML1.pl参照)。
(=)          ::= [X, X].

% expr/expr1/term/term1/factor は tokens//1 の出力(トークン列)を
% 読んで式 e を組み立てるDCG規則。tok//1 系とは異なり、差分リストは
% 文字(atom_t)ではなくトークン(tok_type)の列であることに注意。
expr   ::= [e, list(tok_type), list(tok_type)].
expr1  ::= [e, e, list(tok_type), list(tok_type)].
term   ::= [e, list(tok_type), list(tok_type)].
term1  ::= [e, e, list(tok_type), list(tok_type)].
factor ::= [e, list(tok_type), list(tok_type)].

% tokenize
tokens(Ts) --> " ", tokens(Ts).
tokens([T|Ts]) --> tok(T), !, tokens(Ts).
tokens([]) --> "".

tok(int(I)) --> digits(Cs), { number_chars(I, Cs) }.
tok(bool(true)) --> "true".
tok(bool(false)) --> "false".
tok(+) --> "+".
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

factor(int(I)) --> [int(I)].
factor(bool(B)) --> [bool(B)].
factor(var(X)) --> [var(X)].
factor(E) --> "(", expr(E), ")".
factor(if(E1, E2, E3)) -->
    [if], expr(E1), [then], expr(E2), [else], expr(E3).
factor(let(X = E1 in E2)) --> [let, var(X), =], expr(E1), [in], expr(E2).

% eval

% 以下では環境を C とする (Context)
% C ⱶ i ⇩ i
_ ⱶ int(I) ⇩ I.

% C ⱶ b ⇩ b
_ ⱶ bool(B) ⇩ B.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   C ⱶ i1 plus i2 is i3
% ------------------------------------------------
% C ⱶ e1 + e2 ⇩ i3
C ⱶ E1 + E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 plus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   C ⱶ i1 minus i2 is i3
% -------------------------------------------------
% C ⱶ e1 - e2 ⇩ i3
C ⱶ E1 - E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 minus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   C ⱶ i1 times i2 is i3
% -------------------------------------------------
% C ⱶ e1 * e2 ⇩ i3
C ⱶ E1 * E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 times I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   C ⱶ i1 less than i2 is i3
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

% C ⱶ e1 ⇩ v1   x = v1, C ⱶ e3 ⇩ v
% --------------------------------
% C ⱶ let x = e1 in e2 ⇩ v
C ⱶ let(X = E1 in E2) ⇩ V :-
    C ⱶ E1 ⇩ V1, [X = V1 | C] ⱶ E2 ⇩ V.

% C, x = v ⱶ x ⇩ v
[X = V | _] ⱶ var(X) ⇩ V.

% (y != x)   C ⱶ x ⇩ v2
% ---------------------
% C, y = v1 ⱶ x ⇩ v2
[Y = _ | C] ⱶ var(X) ⇩ V :-
    Y \== X, C ⱶ var(X) ⇩ V.

I1 plus I2 is I3 :- I3 is I1 + I2.
I1 minus I2 is I3 :- I3 is I1 - I2.
I1 times I2 is I3 :- I3 is I1 * I2.
% 元々は 'I1 < I2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :- I1 < I2, !.
_I1 lessThan _I2 is false.

% --- ロード完了後のカインド一括検証 ---
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
% 渡す(EvalML1.plのtest/2と同じパターン)。
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

% code_result/code_expr/code_tokens/test は type_check_all の後で
% 定義したので、ここでもう一度呼んでまとめて検証する。
:- type_check_all.

:- begin_tests(eval_ml2).
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
test(16):- test("1", 1).
:- end_tests(eval_ml2).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
