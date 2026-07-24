:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(590,yfx, ::).
:- op(600,xfy, ⇩).
:- op(800,xfx, plus).
:- op(800,xfx, minus).
:- op(800,xfx, times).
:- op(800,xfx, lessThan).
:- op(900,xfx, in).
:- op(900,xfx, with).
:- op(990,xfx, ⱶ).
% (->)/2 はカインド宣言の「Args->Result」構文の区切りとして使われて
% いるため、'->' 自身を構成子として使うと ::= 宣言と衝突する
% (EvalML3.pl と同じ理由)。文字列 "->" 由来のトークン以外は
% すべて '=>' を使うことで、この衝突を避ける。with(900) より弱く
% 結合させる必要があるので 950 とする。
:- op(950,xfx, (=>)).

% --- tok/tokens/digit の型 (EvalML3.pl と同じ) ---
bool_v ::= true | false.

% トークンの種類。記号・キーワードは int(_)/bool(_)/var(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める。
tok_type ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | atom_t.

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

% --- 式(AST)とパーサの型 ---
% let(X = E1 in E2) -> let(in(=(X,E1), E2))
% fun(X => E) -> fun(=>(X,E))
% match は with(900) が =>(950) より強く結合するため、実際には
%   match(=>(with(E1, []), E2), =>(::(X, Y), E3))
% という項になる(EvalML3.pl と同様に write_canonical で確認)。
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.

% cons_pat は (x :: y) パターン用。
% `cons_pat ::= (list(atom_t) :: list(atom_t))` だと cons_pat ::: [(::)]
% という裸の構成子名リストが登録されてしまい、サブタイピングの
% リスト同士比較(is_list(T1),is_list(T2)の節)経由で cons_pat <: e が
% 誤って成功してしまう(要素1個同士の構成子名リストだと特に起きやすい)。
% そのため構成子署名だけ直接登録し、cons_pat ::: [(::)] は作らない。
:- assertz((::) ::: [list(atom_t), list(atom_t)]->cons_pat),
   kind(cons_pat).

% with(E, []) の [] は空リストパターン。
with_nil ::= (e with list(_)).

% fun_abs/arm_nil/arm_cons は '=>' という新しい演算子(-> とは別)を
% 構成子に使うことで、::= の「Args->Result」構文と衝突せず、
% 普通の ::= 宣言(LHSは構成子 '=>')として書ける(EvalML3.pl と同じ工夫)。
% [Args]->Result という引数リスト形式のRHSは is_true_alias_rhs により
% 「真の型エイリアス」とみなされ、cons_pat のときのような裸の
% 構成子名リスト(fun_abs:::[(=>)] 等)は登録されない。
% ただしこの真エイリアス扱いのルートでは is_kind/1 が自動では
% 立たないため、fun_abs/arm_nil/arm_cons を is_kind として
% 明示的に登録しておく(e の check_kind_con から kind_compatible で
% 参照されるため)。
(=>) ::= [list(atom_t), e]->fun_abs.
(=>) ::= [with_nil, e]->arm_nil.
(=>) ::= [cons_pat, e]->arm_cons.
:- kind(fun_abs), kind(arm_nil), kind(arm_cons).

% 式AST。nil は空リスト式、e::e は cons。
% match/2 の第1引数は ->(with(E,[]), E2)、第2引数は ->(X::Y, E3)。
e ::= int(int_t) | bool(bool_v) | var(list(atom_t)) | nil
    | e+e | e-e | e*e | (e<e) | (e :: e)
    | if(e,e,e) | let(let_body) | letrec(let_body)
    | fun(fun_abs) | app(e, e) | match(arm_nil, arm_cons).

expr    ::= [e, list(tok_type), list(tok_type)].
expr1   ::= [e, e, list(tok_type), list(tok_type)].
term    ::= [e, list(tok_type), list(tok_type)].
term1   ::= [e, e, list(tok_type), list(tok_type)].
factor  ::= [e, list(tok_type), list(tok_type)].
factor1 ::= [e, e, list(tok_type), list(tok_type)].
farg    ::= [e, list(tok_type), list(tok_type)].

% --- 評価の型 (EvalML3.pl + パターンマッチのリスト値) ---
% 値: 整数・真偽値、クロージャ(通常/letrec)。
v ::= int_t | bool_v | cls(env, fun_abs) | cls(env, binding).

% match/nil/:: の評価結果は [] や [V1|V2] という素の Prolog リストで
% 表現される(v のリスト)。`v ::= ... | list(v).` のように v 自身の
% 選択肢に list(v) を混ぜると、alts/3 が list(v) を単に「list という
% 名前の構成子(引数 v)」として登録してしまい(list:::[v]->v)、
% 肝心の「list(A) という型表現へのエイリアス」情報が失われる
% (tp/3 の空リスト/consリスト専用節 tp(_,[],T) や
%  tp(Γ,[H|Tail],list(A)) は、ターゲット型が構文的に list(A) の
%  形をしている場合にしか反応しないため)。
% そのため vlist という別カインドを単一選択肢(env と同じ「真の
% 型エイリアス」扱い)で用意し、list(v) というエイリアスを維持する。
vlist ::= list(v).

% 評価環境 C は (変数名 = 値) のペアのリスト。値は match の
% x :: y パターンで y がリスト全体(vlist)に束縛されることがあるので、
% v と vlist の2択にする(eval_pair と同じ理由)。
env_binding ::= (list(atom_t) = v) | (list(atom_t) = vlist).
env ::= list(env_binding).

% 'C ⱶ E ⇩ V' は実際には ⱶ(C, ⇩(E,V)) という項になるので、
% ⇩(e,v) の形を eval_pair としてカインド登録しておく。V は
% スカラー(v)またはリスト(vlist)のどちらもありうるので2択にする。
eval_pair ::= (e ⇩ v) | (e ⇩ vlist).

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
% test は writef/2 に list(atom_t) と v が混在する引数リストを渡すため、
% tprolog の list(A)(同種要素のみ)では型付けできない(EvalML2.pl参照)。
% そのためシグネチャを与えず、型検査の対象外(untyped)のままにする。

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
tok('[') --> "[".
tok(']') --> "]".
tok('|') --> "|".
tok(=) --> "=".
tok(::) --> "::".
tok(if) --> "if".
tok(then) --> "then".
tok(else) --> "else".
tok(let) --> "let".
tok(in) --> "in".
tok(fun) --> "fun".
tok(rec) --> "rec".
tok(match) --> "match".
tok(with) --> "with".
tok(var(Cs)) --> alpha_alnums(Cs).

digits([C|Cs]) --> digit(C), digits(Cs).
digits([C])    --> digit(C).

digit(C)   --> [C], { code_type(C, digit) }.

alpha_alnums([C|Cs]) --> alpha(C), alnums(Cs).
alpha_alnums([C]) --> alpha(C).

% 元々は (alpha(C)|digit(C)) というDCGの選言(;/2に変換される)で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、;/2 を含む節はそのままでは型検査できない。
alnums([C|Cs]) --> alpha(C), alnums(Cs).
alnums([C|Cs]) --> digit(C), alnums(Cs).
alnums([C])    --> alpha(C).
alnums([C])    --> digit(C).

alpha(C) --> [C], { code_type(C, alpha) }.

% parse
% expr ::= term | expr + term | expr - term | expr < term | term :: expr
expr(E)      --> term(T), expr1(T, E).
expr(T :: E) --> term(T), [::], expr(E).
expr1(E1, E) --> "<", term(T), expr1(E1 < T, E).
expr1(E1, E) --> "+", term(T), expr1(E1 + T, E).
expr1(E1, E) --> "-", term(T), expr1(E1 - T, E).
expr1(E, E)  --> [].

% term ::= factor | term * factor
term(T) --> factor(F), term1(F, T).
term1(E1, E) --> "*", term(T), expr1(E1 * T, E).
term1(E, E)  --> [].

% factor ::= farg | factor farg
factor(F) --> farg(A), factor1(A, F).
factor1(F1, F) --> farg(A), factor1(app(F1,A), F).
factor1(E, E) --> [].

farg(int(I)) --> [int(I)].
farg(bool(B)) --> [bool(B)].
farg(var(X)) --> [var(X)].
farg(E) --> "(", expr(E), ")".
farg(nil) --> "[]".
farg(if(E1, E2, E3)) -->
    [if], expr(E1), [then], expr(E2), [else], expr(E3).
farg(let(X = E1 in E2)) -->
    [let, var(X), =], expr(E1), [in], expr(E2).
farg(letrec(X = fun(Y => E1) in E2)) -->
    [let, rec, var(X), =, fun, var(Y), =>], expr(E1), [in], expr(E2).
farg(fun(X => E)) -->
    [fun, var(X), =>], expr(E).
farg(match(E1 with [] => E2, X :: Y => E3)) -->
    [match], expr(E1), [with, '[', ']', =>], expr(E2),
    ['|', var(X), ::, var(Y), =>], expr(E3).

% パーサまでの型検査
:- type_check_all.

% eval

% --------- E-Int
% C ⱶ i ⇩ i
_ ⱶ int(I) ⇩ I.

% --------- E-Bool
% C ⱶ b ⇩ b
_ ⱶ bool(B) ⇩ B.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 plus i2 is i3
% -------------------------------------------- E-Plus
% C ⱶ e1 + e2 ⇩ i3
C ⱶ E1 + E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 plus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 minus i2 is i3
% --------------------------------------------- E-Minus
% C ⱶ e1 - e2 ⇩ i3
C ⱶ (E1 - E2) ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 minus I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 times i2 is i3
% ------------------------------------------------- E-Times
% C ⱶ e1 * e2 ⇩ i3
C ⱶ E1 * E2 ⇩ I3 :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 times I2 is I3.

% C ⱶ e1 ⇩ i1   C ⱶ e2 ⇩ i2   i1 less than i2 is i3
% ----------------------------------------------------- E-LessThan
% C ⱶ e1 < e2 ⇩ i3
C ⱶ (E1 < E2) ⇩ B :-
    C ⱶ E1 ⇩ I1, C ⱶ E2 ⇩ I2, I1 lessThan I2 is B.

% C ⱶ e1 ⇩ true   C ⱶ e2 ⇩ v
% ----------------------------- E-IfT
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, E2, _) ⇩ V :-
    C ⱶ E1 ⇩ true, C ⱶ E2 ⇩ V.

% C ⱶ e1 ⇩ false    C ⱶ e3 ⇩ v
% ----------------------------- E-IfF
% C ⱶ if e1 then e2 else e3 ⇩ v
C ⱶ if(E1, _, E3) ⇩ V :-
    C ⱶ E1 ⇩ false, C ⱶ E3 ⇩ V.

% C ⱶ e1 ⇩ v1   C, x = v1 ⱶ e2 ⇩ v
% -------------------------------- E-Let
% C ⱶ let x = e1 in e2 ⇩ v
C ⱶ let(X = E1 in E2) ⇩ V :-
    C ⱶ E1 ⇩ V1, [X = V1 | C] ⱶ E2 ⇩ V. 

% C, x = (ε)[rec x = fun y -> e1] ⱶ e2 ⇩ v 
% ---------------------------------------- E-LetRec
% C ⱶ let rec x = fun y -> e1 in e2 ⇩ v
C ⱶ letrec(X = fun(Y => E1) in E2) ⇩ V :-
    [X = cls(C, X = fun(Y => E1)) | C] ⱶ E2 ⇩ V.

% ---------------- E-Var1
% C, x = v ⱶ x ⇩ v
[X = V | _] ⱶ var(X) ⇩ V.

% (y != x)   C ⱶ x ⇩ v2
% --------------------- E-Var2
% C, y = v1 ⱶ x ⇩ v2
[Y = _ | C] ⱶ var(X) ⇩ V :-
    Y \== X, C ⱶ var(X) ⇩ V.

% --------------------------------- E-Fun
% C ⱶ fun x -> e ⇩ (C) [fun x -> e]
C ⱶ fun(X => E) ⇩ cls(C, fun(X => E)).

% C ⱶ e1 ⇩ (C2) [fun x -> e0]
% C ⱶ e2 ⇩ v2   C2, x = v2 ⱶ e0 ⇩ v
% --------------------------------- E-App
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, fun(X => E0)),
    C ⱶ E2 ⇩ V2,
    [X = V2 | C2] ⱶ E0 ⇩ V.

% C ⱶ e1 ⇩ (C2) [rec x = fun y -> e0]   C ⱶ e2 ⇩ v2
% C2, x = (C2) [rec x = fun y -> e0], y = v2 ⱶ e0 ⇩ v
% --------------------------------------------------- E-AppRec
% C ⱶ e1 e2 ⇩ v
C ⱶ app(E1, E2) ⇩ V :-
    C ⱶ E1 ⇩ cls(C2, X = fun(Y => E0)),
    C ⱶ E2 ⇩ V2,
    [Y = V2, X = cls(C2, X = fun(Y => E0)) | C2] ⱶ E0 ⇩ V.

% ----------- E-Nil
% C ⱶ [] ⇩ []
_ ⱶ nil ⇩ [].

% C ⱶ e1 ⇩ v1   C ⱶ e2 ⇩ v2
% ------------------------ E-Cons
% C ⱶ e1 :: e2 ⇩ v1 :: v2
C ⱶ E1 :: E2 ⇩ [V1 | V2] :-
    C ⱶ E1 ⇩ V1, C ⱶ E2 ⇩ V2.

% C ⱶ e1 ⇩ []    C ⱶ e2 ⇩ v
% --------------------------------------------- E-MatchNil
% C ⱶ match e1 with [] -> e2 | x :: y -> e3 ⇩ v
C ⱶ match(E1 with [] => E2, _ :: _ => _) ⇩ V :-
    C ⱶ E1 ⇩ [], C ⱶ E2 ⇩ V.

% C ⱶ e1 ⇩ v1 :: v2    C, y = v2, x = v1 ⱶ e3 ⇩ v
% ----------------------------------------------- E-MatchCons
% C ⱶ match e1 with [] -> e2 | x :: y -> e3 ⇩ v
C ⱶ match(E1 with [] => _, X :: Y => E3) ⇩ V :-
    C ⱶ E1 ⇩ [V1 | V2],
    [X = V1, Y = V2 | C] ⱶ E3 ⇩ V.

% (i3 = i1 + i2)
% ---------------- B-Plus
% i1 plus i2 is i3
I1 plus I2 is I3 :-
    I3 is I1 + I2.

% (i3 = i1 - i2)
% ---------------- B-Minus
% i1 minus i2 is i3
I1 minus I2 is I3 :-
     I3 is I1 - I2.

% (i3 = i1 * i2)
% ---------------- B-Times
% i1 times i2 is i3
I1 times I2 is I3 :-
     I3 is I1 * I2.

% (b3 = i1 < i2)
% ---------------- B-LessThan
% i1 less than i2 is b3
% 元々は 'I1 < I2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :- I1 < I2, !.
_I1 lessThan _I2 is false.

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

% code_result/code_expr/code_tokens は type_check_all の後で
% 定義したので、ここでもう一度呼んでまとめて検証する。
:- type_check_all.

% test
% test内(:-begin_tests/:-end_testsの中)ではdouble_quotes=charsが
% 効かず、文字列リテラルがSWIのstringオブジェクトのままになるため、
% string_chars/2で明示的にcharsのリストへ変換してからcode_result/2に
% 渡す(EvalML1.pl/EvalML2.pl/EvalML3.plのtest/2と同じパターン)。
test(String, Expected) :-
    string_chars(String, Code),
    code_result(Code, Actual),
    (Expected = Actual -> writef('%s => %w\n', [Code, Actual]);
    writef('%s => %w expected, but got %w\n', [Code, Expected, Actual]), fail).

:- begin_tests(eval_ml4).
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
test(20):- test("match [] with [] -> 1 | a :: b -> a", 1).
test(21):- test("let x = [] in match x with [] -> 1 | a :: b -> a", 1).
test(22):- test("match 1 :: 2 :: 3 :: [] with [] -> 4 | a :: b -> a", 1).
test(23):- test("match 1 :: 2 :: 3 :: [] with [] -> 4 | a :: b -> b", [2, 3]).
test(24):- test("let rec length = fun x -> match x with [] -> 0 | a :: b -> 1 + length b in length (10 :: 20 :: 30 :: [])", 3).
test(25):- test("1", 1).
:- end_tests(eval_ml4).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.