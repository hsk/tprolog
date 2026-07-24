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
% (->)/2 はカインド宣言の「Args->Result」構文の区切りとして使われて
% いるため、'->' 自身を構成子として使うと ::= 宣言と衝突する
% (EvalML3.pl/EvalML4.pl/EvalML5.pl と同じ理由)。文字列 "->" 由来の
% トークン以外はすべて '=>' を使うことで、この衝突を避ける。
:- op(950,xfx, (=>)).

% --- tok/tokens/digit の型 (EvalML3.pl と同じ) ---
bool_v ::= true | false.

% トークンの種類。記号・キーワードは int(_)/bool(_)/var(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める
% (EvalML1.pl と同じ理由: 個別登録すると tp/3 のカットで汎用の
%  atom_t として分類できなくなるため)。
tok_type ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | atom_t.

% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 と '[|]' のシグネチャ。
'[|]'     ::= [A,list(A)]->list(A).
(=)       ::= [X, X].
(!)       ::= [].

tok    ::= [tok_type, list(atom_t), list(atom_t)].
digits ::= [list(atom_t), list(atom_t), list(atom_t)].
digit  ::= [atom_t, list(atom_t), list(atom_t)].
tokens ::= [list(tok_type), list(atom_t), list(atom_t)].

alpha_alnums ::= [list(atom_t), list(atom_t), list(atom_t)].
alnums       ::= [list(atom_t), list(atom_t), list(atom_t)].
alpha        ::= [atom_t, list(atom_t), list(atom_t)].

code_type    ::= [atom_t, atom_t].
number_chars ::= [int_t, list(atom_t)].

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
% 全く同じ挙動になる、節を分ける形に書き換えている(EvalML1〜5と同じ)。
alnums([C|Cs]) --> alpha(C), alnums(Cs).
alnums([C|Cs]) --> digit(C), alnums(Cs).
alnums([C])    --> alpha(C).
alnums([C])    --> digit(C).

alpha(C) --> [C], { code_type(C, alpha) }.

% --- 式(AST)とパーサの型 (EvalML3.pl と同じ) ---
% let(X = E1 in E2) -> let(in(=(X,E1), E2))
% fun(X => E) -> fun(=>(X,E))
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.
fun_abs  ::= (=>).
(=>)     ::= [list(atom_t), e]->fun_abs.

% 式(構文解析で得られるAST)。letrec(X = E1 in E2) は let と全く同じ
% 形(この言語のletrecはパース時点では fun/Y の有無を区別しない)。
e ::= int(int_t) | bool(bool_v) | var(list(atom_t))
    | e+e | e-e | e*e | (e<e) | if(e,e,e) | let(let_body)
    | letrec(let_body) | fun(fun_abs) | app(e, e).

expr    ::= [e, list(tok_type), list(tok_type)].
expr1   ::= [e, e, list(tok_type), list(tok_type)].
term    ::= [e, list(tok_type), list(tok_type)].
term1   ::= [e, e, list(tok_type), list(tok_type)].
factor  ::= [e, list(tok_type), list(tok_type)].
factor1 ::= [e, e, list(tok_type), list(tok_type)].
farg    ::= [e, list(tok_type), list(tok_type)].

% --- トークナイザまでの型検査 ---
:- type_check_all.

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
farg(let(X = E1 in E2)) -->
    [let, var(X), =], expr(E1), [in], expr(E2).  
farg(letrec(X = E1 in E2)) -->
    [let, rec, var(X), =], expr(E1), [in], expr(E2).
farg(fun(X => E)) --> [fun, var(X), =>], expr(E).

% --- パーサまでの型検査 ---
:- type_check_all.

% --- 評価(遅延評価)の型 ---
% 値: 整数・真偽値、またはクロージャ(EvalML3.pl と同じ)。
v ::= int_t | bool_v | cls(env, e) | cls(env, binding).

% 評価環境に格納される値は、既に評価済みの v だけでなく、
% app が引数を遅延させるために作る thunk(C,E)(環境Cのもとで式Eを
% まだ評価していない、という保留計算)にもなりうる。v をそのまま
% storable ::= v | thunk(env,e). のように参照すると、v が既に固有の
% 展開を持つ「普通のカインド」であるため、tp/3 のアトム/複合項判定の
% 非対称性により v<:storable 方向にしか正しく機能しない
% (docs/type-system.md の既知の限界を参照)。そのため v の選択肢を
% そのまま複製し、thunk を追加した形で storable を独自に定義する
% (EvalML4.pl の fun_or_rec と同じ工夫)。
storable ::= int_t | bool_v | cls(env, e) | cls(env, binding) | thunk(env, e).

% 評価環境 C は (変数名 = 格納値) のペアのリスト。格納値は上記の
% 理由で storable(vまたはthunk)にする。
env_binding ::= (list(atom_t) = storable).
env ::= list(env_binding).

% 'C ⱶ E ⇩ V' の V も、var(X) がサンクをそのまま(forceせずに)
% 返しうるので storable にする(force/2 で明示的に v へ変換する)。
eval_pair ::= (e ⇩ storable).
(ⱶ)       ::= [env, eval_pair].

% force(Storable, V) は Storable(値またはサンク)を再帰的に評価して
% 素の値 v にする。
force ::= [storable, v].

% plus/minus/times/lessThan は 'I1 plus I2 is I3' という中置記法で
% 書かれているが、plus 等(800,xfx) は is(700,xfx) より優先順位の
% 数値が小さい(=強く結合する)ため、実際には
%   plus(I1, is(I2,I3))
% という項に展開される。結果型を汎用の _V で受け付ける。
% I1/I2 は force される前は storable(サンクの可能性がある)なので、
% int_t ではなく storable を受け取れるようにする必要があるが、
% int_t は storable の構成子の一つなので int_t<:storable の
% 方向で整合する(下の (+)/(-)/(*) も同様)。
result_is ::= is(int_t, _V).

(+)      ::= [int_t,int_t] -> int_t.
(-)      ::= [int_t,int_t] -> int_t.
(*)      ::= [int_t,int_t] -> int_t.
is       ::= [int_t,int_t].
(<)      ::= [int_t,int_t].
% force/2 の base case 'force(I,I):-integer(I).' で integer/1 を
% ゴールとして呼んでいるため、シグネチャが必要。
integer  ::= [_].
plus     ::= [int_t, result_is].
minus    ::= [int_t, result_is].
times    ::= [int_t, result_is].
lessThan ::= [int_t, result_is].
(\==)    ::= [X, X].

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

% C, x = (C)[rec x = e1] ⱶ e2 ⇩ v
% ----------------------------------------
% C ⱶ let rec x = e1 in e2 ⇩ v
C ⱶ letrec(X = E1 in E2) ⇩ V :-
    [X = cls(C, X = E1) | C] ⱶ E2 ⇩ V.

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
    C ⱶ E1 ⇩ V1, force(V1, cls(C2, fun(X => E0))),
    [X = thunk(C, E2) | C2] ⱶ E0 ⇩ V.

% C ⱶ e1 ⇩ (C2) [rec x = fun y -> e0]
% C ⱶ e2 ⇩ v2
% C2, x = (C2) [rec x = fun y -> e0], y = v2 ⱶ e0 ⇩ v
% ---------------------------------------------------
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ V1, force(V1, cls(C2, X = fun(Y => E0))),
    [Y = thunk(C, E2), X = cls(C2, X = fun(Y => E0)) | C2] ⱶ E0 ⇩ V.

%C ⱶ app(E1, E2) ⇩ V :-
%    C ⱶ E1 ⇩ cls(C2, X = fun(Y => E0)),
%    C ⱶ E2 ⇩ V2,
%    [Y = V2, X = cls(C2, X = fun(Y => E0)) | C2] ⱶ E0 ⇩ V.

I1 plus I2 is I3 :- 
    force(I1, F1), force(I2, F2), I3 is F1 + F2.
I1 minus I2 is I3 :-
    force(I1, F1), force(I2, F2), I3 is F1 - F2.
I1 times I2 is I3 :-
    force(I1, F1), force(I2, F2), I3 is F1 * F2.
% 元々は 'F1 < F2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :-
    force(I1, F1), force(I2, F2), F1 < F2, !.
_I1 lessThan _I2 is false.

force(I, I) :- integer(I).
force(thunk(C, E), FV) :-
    C ⱶ E ⇩ V, force(V, FV), !.
force(V, V).

% --- eval までの型検査 ---
:- type_check_all.

% --- UI (code_result/2 等) の型 ---
% string_chars/2 の第1引数はSWIのstringオブジェクトで、tp/3 に対応する
% 節が無い(atomでもリストでもcompoundでもない)ため、汎用にする。
string_chars ::= [_, list(atom_t)].
code_result  ::= [list(atom_t), v].
code_expr    ::= [list(atom_t), e].
code_tokens  ::= [list(atom_t), list(tok_type)].
% test は writef/2 に list(atom_t) と v が混在する引数リストを渡すため、
% tprolog の list(A)(同種要素のみ)では型付けできない(EvalML2.pl参照)。
% そのためシグネチャを与えず、型検査の対象外(untyped)のままにする。

% UI
% phrase/2 は使わず、DCG変換後の3引数の述語として直接呼ぶ
% (tokens(Tokens,Code,[]) は phrase(tokens(Tokens),Code) と同じ意味。
%  phrase/2 は非終端記号を reified call として渡す高階述語で、
%  tprolog はcallableという概念を持たないため型付けできない)。
code_result(Code, Value) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []),
    [] ⱶ Expr ⇩ Result,
    force(Result, Value), !.

code_expr(Code, Expr) :-
    tokens(Tokens, Code, []),
    expr(Expr, Tokens, []).

code_tokens(Code, Tokens) :-
    tokens(Tokens, Code, []).

% code_result/code_expr/code_tokens は type_check_all の後で
% 定義したので、ここでもう一度呼んでまとめて検証する。
:- type_check_all.

% test
% test内(:-begin_tests/:-end_testsの中)ではdouble_quotes=charsが
% 効かず、文字列リテラルがSWIのstringオブジェクトのままになるため、
% string_chars/2で明示的にcharsのリストへ変換してからcode_result/2に
% 渡す(EvalML1.pl以降のtest/2と同じパターン)。
test(String, Expected) :-
    string_chars(String, Code),
    code_result(Code, Actual),
    (Expected = Actual -> writef('%s => %w\n', [Code, Actual]);
    writef('%s => %w expected, but got %w\n', [Code, Expected, Actual]), fail).

:- begin_tests(eval_lazy_ml3).
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
test(20):- test("let rec f = fun x -> f x + f x in let zero = fun y -> 0 in zero (f 3)", 0).
test(21):- test("1", 1).
:- end_tests(eval_lazy_ml3).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.