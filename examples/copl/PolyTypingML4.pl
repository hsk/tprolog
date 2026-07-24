:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).

:- op(990,xfx, ⱶ).
:- op(900,xfx, in).
:- op(900,xfx, with).
:- op(900,xfx, then).
:- op(890,xfx, else).
:- op(590,yfx, ::).
% (->)/2 はカインド宣言の「Args->Result」構文の区切りとして使われて
% いるため、'->' 自身を構成子(関数抽象・関数型の両方)として使うと
% ::= 宣言と衝突する(TypingML4.pl と同じ理由)。文字列 "->" 由来の
% トークン以外はすべて '=>' を使うことで、この衝突を避ける。
:- op(600,xfy, (=>)).

% --- tok/tokens/digit の型 (EvalML1〜5.pl/TypingML4.pl と同じ) ---
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

digit(C) --> [C], { code_type(C, digit) }.
alpha(C) --> [C], { code_type(C, alpha) }.

% --- 式(AST)とパーサの型 (TypingML4.pl と同じ) ---
% let(X = E1 in E2) -> let(in(=(X,E1), E2))
% letrec(X = E1 in E2) -> letrec(in(=(X,E1), E2))  (letrec は fun/Y の
% 有無をパース時点では区別せず let と全く同じ形。型付け規則側で
% E1 が fun(...) の形であることを要求する)。
binding  ::= (list(atom_t) = e).
let_body ::= binding in e.

% fun_abs は '=>' という新しい演算子(-> とは別)を構成子に使うことで、
% ::= の「Args->Result」構文と衝突せず、普通の ::= 宣言(LHSは構成子
% '=>')として書ける(EvalML3〜5.pl と同じ工夫)。
(=>) ::= [list(atom_t), e]->fun_abs.
:- kind(fun_abs).

% match(E1 with [] => E2, X :: Y => E3) の2本の枝。
% ここでの '=>' は 600(with の 900 より強く結合)なので、
% with(E1, ([]=>E2)) という構造になる(TypingML4.pl と同じ、
% write_canonical で確認済み)。[] => E2 の部分は「list(_) => e」
% という形(fun_abs と同じ骨格)。
% ここも fun_abs と同様、LHSを構成子 '=>' にしてRHSは本物の '->' で
% 書く(nil_arrow ::= (list(_) => e). のように LHS を nil_arrow に
% してしまうと、is_arg_list_form が '->' ではなく '=>' を見て
% 真エイリアスと認識できず、nil_arrow ::: ['=>'] という裸の構成子名
% リストが登録されてしまい、fun_abs/arm_cons と同じ '=>' を共有する
% ことで誤った部分型関係が生じるバグを踏む、TypingML4.pl で実際に
% 踏んで直した不具合)。
(=>) ::= [list(_), e]->nil_arrow.
:- kind(nil_arrow).

% E1 with ([]=>E2) の部分。with_nil ::= (e with nil_arrow). だと
% with_nil ::: [with] という裸の構成子名リストが登録され、
% サブタイピングのリスト同士比較経由で誤った部分型関係が生じうる
% (EvalML4.pl の fun_abs/arm_nil/arm_cons と同じ理由)。そのため
% 構成子署名だけ直接登録し、with_nil ::: [with] は作らない。
:- assertz(with ::: [e, nil_arrow]->arm_nil),
   kind(arm_nil).

% cons_pat は (x :: y) パターン用。`cons_pat ::= (list(atom_t) ::
% list(atom_t))` だと cons_pat ::: [(::)] という裸の構成子名リストが
% 登録されてしまい、サブタイピングのリスト同士比較経由で
% cons_pat <: e が誤って成功してしまう(EvalML4.pl と同じ理由)。
% そのため構成子署名だけ直接登録し、cons_pat ::: [(::)] は作らない。
:- assertz((::) ::: [list(atom_t), list(atom_t)]->cons_pat),
   kind(cons_pat).

(=>) ::= [cons_pat, e]->arm_cons.
:- kind(arm_cons).

% 式(構文解析で得られるAST)。
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

% --- トークナイザまでの型検査 ---
:- type_check_all.

expr(E)      --> term(T), expr1(T, E).
expr(T :: E) --> term(T), ['::'], expr(E).
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

farg(int(N)) --> [int(N)].
farg(bool(B)) --> [bool(B)].
farg(var(X)) --> [var(X)].
farg(E) --> "(", expr(E), ")".
farg(nil) --> "[", "]".
farg(if(E1, E2, E3)) --> ['if'], expr(E1), ['then'], expr(E2), ['else'], expr(E3).
farg(let(X = E1 in E2)) --> ['let', var(X), '='], expr(E1), ['in'], expr(E2).
farg(letrec(X = E1 in E2)) --> ['let', 'rec', var(X), '='], expr(E1), ['in'], expr(E2).
farg(fun(X => E)) --> ['fun', var(X), =>], expr(E).
farg(match(E1 with [] => E2, X :: Y => E3)) -->
    ['match'], expr(E1), ['with', '[', ']', =>], expr(E2),
    ['|', var(X), '::', var(Y), =>], expr(E3).

% --- 型判定規則(ⱶ ... : T)の型 ---
% 型の値そのもの(int/bool/関数型/リスト型)。TypingML4.pl と同じ。
ty ::= int | bool | (ty => ty) | list(ty).

% 環境に束縛される値は、let多相のため単相(mono)か多相(poly、
% 束縛時点の環境 C を閉じ込めておき instantiate/2 で使用のたびに
% copy_term でフレッシュ化する型スキーム)のどちらか。
scheme ::= mono(ty) | poly(tenv, ty).

% 型環境 C は (変数名 : スキーム) のペアのリスト。
tbinding ::= (list(atom_t) : scheme).
tenv ::= list(tbinding).

% 'C ⱶ E : T' は実際には ⱶ(C, :(E,T)) という項になる
% (: はSWI組み込みの200,xfyで、ⱶ の990,xfxより強く結合するため、
%  TypingML4.pl と同じ)ので、:(e,ty) の形を type_pair として
% カインド登録しておく。
type_pair ::= (e : ty).
(ⱶ) ::= [tenv, type_pair].

% first/2(環境からの変数検索)と (\==)/2 のシグネチャ。
first ::= [tbinding, tenv].
(\==) ::= [X, X].

% instantiate/2 は poly(C,T) を copy_term で t(C,T) ごとフレッシュ化
% することで、T の中に現れる C 由来の型変数だけを正しく共有したまま
% 新しい型変数にリネームする(C を無視して T だけ copy_term すると、
% C側の型変数との対応関係が壊れてしまうため、ダミーの t/2 でくるんで
% 一緒にコピーしている)。t/2 自体は値としての意味を持たない
% ラッパーなので、専用のカインド t_wrap を用意する。
t_wrap ::= t(tenv, ty).
copy_term ::= [t_wrap, t_wrap].
instantiate ::= [scheme, ty].

% --- パーサまでの型検査 ---
:- type_check_all.

% type judgement

% -----------
% C ⱶ i : int    ただし i は 整数
_ ⱶ int(_) : int.

% ------------
% C ⱶ b : bool   ただし b は true または false
_ ⱶ bool(_) : bool.

% C ⱶ e1 : bool   C ⱶ e2 : t   C ⱶ e3 : t
% ---------------------------------------
% C ⱶ if e1 then e2 else e3 : t
C ⱶ if(E1, E2, E3) : T :-
    C ⱶ E1 : bool, C ⱶ E2 : T, C ⱶ E3 : T.

% C ⱶ e1 : int   C ⱶ e2 : int
% ---------------------------
% C ⱶ e1 + e2 : int
C ⱶ E1 + E2 : int :-
    C ⱶ E1 : int, C ⱶ E2 : int.

% C ⱶ e1 : int   C ⱶ e2 : int
% ---------------------------
% C ⱶ e1 - e2 : int
C ⱶ E1 - E2 : int :-
    C ⱶ E1 : int, C ⱶ E2 : int.

% C ⱶ e1 : int   C ⱶ e2 : int
% ---------------------------
% C ⱶ e1 * e2 : int
C ⱶ E1 * E2 : int :-
    C ⱶ E1 : int, C ⱶ E2 : int.

% C ⱶ e1 : int   C ⱶ e2 : int
% ---------------------------
% C ⱶ e1 < e2 : bool
C ⱶ (E1 < E2) : bool :-
    C ⱶ E1 : int, C ⱶ E2 : int.

% (C (x) = σ)   (σ ≧ t)
% --------------------- T-Var
% C |- x : t
C ⱶ var(X) : T :-
    first(X:S,C), instantiate(S,T).

% C, x : t1 |- e : t2
% -------------------------- T-Fun
% C |- fun x -> e : t1 -> t2
C ⱶ fun(X => E) : (T1 => T2) :-
    [X : mono(T1) | C] ⱶ E : T2.

% C |- e1 : t1 -> t2   C |- e2 : t1
% --------------------------------- T-App
% C |- e1 e2 : t1
C ⱶ app(E1, E2) : T2 :-
    C ⱶ E1 : T1 => T2, C ⱶ E2 : T1.

% C |- e1 : t1   C, x : {a1 .. an}.t1 |- e2 : t2
% ---------------------------------------------- T-Let
% C |- let x = e1 in e2 : t2
C ⱶ let(X = E1 in E2) : T2 :-
    C ⱶ E1 : T1,
    [X : poly(C,T1) | C] ⱶ E2 : T2.

% C, x : t1 |- e1 : t1   C, x : {a1 .. an}.t1 |- e2 : t2
% ------------------------------------------------------ T-LetRec'
% C |- let x = e1 in e2 : t2
C ⱶ letrec(X = E1 in E2) : T2 :-
   [X : mono(T1) | C] ⱶ E1 : T1,
   [X : poly(C,T1) | C] ⱶ E2 : T2.

% C, x : t1 -> t2, y : t1 |- e1 : t2
% C, y : {a1 .. an}.t1 -> t2 |- e2 : t
% ------------------------------------- T-LetRec こちらが教科書での形
% C |- letrec x = fun y -> e1 in e2 : t

% C ⱶ letrec(X = fun(Y => E1) in E2) : T :-
%    [Y : mono(T1), X : mono(T1 => T2) | C] ⱶ E1 : T2,
%    [X : poly(C, T1 => T2) | C] ⱶ E2 : T.

% C ⱶ e1 : t   C ⱶ e2 : t list
% ---------------------------- T-Cons
% C ⱶ e1 :: e2 : t list
C ⱶ (E1 :: E2) : list(T) :-
    C ⱶ E1 : T, C ⱶ E2 : list(T).

% ---------------- T-Nil
% C ⱶ [] :: t list
_ ⱶ nil : list(_).

% C ⱶ e1 : t1 list   C ⱶ e2 : t
% C, x : t1, y : t2 list ⱶ e3 : t
% -------------------------------------------- T-Match
% C ⱶ match e1 with [] -> e2, x :: y -> e3 : t
C ⱶ match(E1 with [] => E2, X :: Y => E3) : T :-
    C ⱶ E1 : list(T1), C ⱶ E2 : T,
    [Y : mono(list(T1)), X : mono(T1) | C] ⱶ E3 : T.

% Type Inference Prototyping Engine from Relational specifications of type systems
% http://kyagrd.github.io/tiper/
first(K:V,[K1:V1|_]) :- K = K1, V=V1.
first(K:V,[K1:_|Xs]) :- K\==K1, first(K:V, Xs).

instantiate(poly(C,T),T1) :- copy_term(t(C,T),t(C,T1)).
instantiate(mono(T),T).

% --- 型判定規則までの型検査 ---
:- type_check_all.

% gen
% X -> Y を ab.a->b にする
gen(Term, Str) :-
    term_variables(Term, []),
    swritef(Str, '%w', [Term]), !.
gen(Term, Str) :-
    term_variables(Term, L),
    inst_vars(L, 1),
    atomic_list_concat(L, Vars),
    swritef(Str, '%w.%w', [Vars, Term]).
inst_vars([], _).
inst_vars([L|Ls], I) :- char(I, C), L = C, J is I + 1, inst_vars(Ls, J).

char(1, a).
char(2, b).
char(3, c).
char(4, d).
char(5, e).

% --- UI (code_result/2 等) の型 ---
% string_chars/2 の第1引数はSWIのstringオブジェクトで、tp/3 に対応する
% 節が無い(atomでもリストでもcompoundでもない)ため、汎用にする。
string_chars ::= [_, list(atom_t)].
code_result  ::= [list(atom_t), ty].
code_expr    ::= [list(atom_t), e].
code_tokens  ::= [list(atom_t), list(tok_type)].
% test/gen/infer は writef/2・swritef/3 に list(atom_t) と ty が混在
% する引数リストを渡すため、tprolog の list(A)(同種要素のみ)では
% 型付けできない(EvalML2.pl参照)。そのためシグネチャを与えず、
% 型検査の対象外(untyped)のままにする。

% UI
% phrase/2 は使わず、DCG変換後の3引数の述語として直接呼ぶ
% (tokens(Tokens,String,[]) は phrase(tokens(Tokens),String) と同じ意味。
%  phrase/2 は非終端記号を reified call として渡す高階述語で、
%  tprolog はcallableという概念を持たないため型付けできない)。
code_result(String, Type) :-
    tokens(Tokens, String, []),
    expr(E, Tokens, []),
    [] ⱶ E : Type, !.

code_expr(String, Ast) :-
    tokens(Tokens, String, []),
    expr(Ast, Tokens, []).

code_tokens(String, Tokens) :-
    tokens(Tokens, String, []).

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
    ((Expected = Actual) -> writef('%s => %w\n', [Code, Actual]);
    writef('%s => %w expected, but got %w\n', [Code, Expected, Actual]), fail).

:- begin_tests(poly_typing_ml4).
test(1):- test("42", int).
test(2):- test("3 + 5", int).
test(3):- test("let x = 3 < 2 in let y = 5 in if x then y else 2", int).
test(4):- test("fun f -> f 0 + f 1", (int => int) => int).
test(5):- test("let k = fun x -> fun y -> x in (k 3 true) :: k (1 :: []) 3", list(int)).
test(6):- test("let rec fact = fun n -> if n < 2 then 1 else n * fact (n - 1) in fact 3", int).
test(7):- test("let l = (fun x -> x) :: (fun y -> 2) :: (fun z -> z + 3) :: [] in 2", int).
test(8):- test("let rec length = fun l -> match l with [] -> 0 | x :: y -> 1 + length y in length", list(int) => int).
test(9):- test("let compose = fun f -> fun g -> fun x -> f (g x) in let p = fun x -> x * x in let q = fun x -> x + 4 in compose p q", int => int).
test(10):- test("let l = (fun x -> x) :: (fun y -> 2) :: (fun z -> z + 3) :: [] in 2", int).
test(11):- test("let rec length = fun l -> match l with [] -> 0 | x :: y -> 1 + length y in length ((fun x -> x) :: (fun y -> y + 3) :: [])", int).
test(12):- test("let id = fun x -> x in id id", bool => bool).
test(13):- test("let twice = fun f -> fun x -> f (f x) in twice (fun x -> x + 4) 5", int).
test(14):- test("let twice = fun f -> fun x -> f (f x) in twice twice (fun x -> x + 4) 5", int).
test(15):- test("let x = [] in let y = 3 :: x in true :: x", list(bool)).
test(16):- test("let l = (fun x -> x) :: [] in let l1 = (fun y -> y + 1) :: l in (fun z -> if z then false else true) :: l", list(bool => bool)).
test(17):- test("let rec length = fun l -> match l with [] -> 0 | x :: y -> 1 + length y in length (1 :: []) + length ((1 :: []) :: [])", int).
test(18):- test("1", int).
:- end_tests(poly_typing_ml4).

% type inference
infer(String, TypeStr) :-
    code_result(String, Type),
    gen(Type, TypeStr).

% infer/2 も test/2 と同じ理由で、test内では string_chars/2 で
% charsのリストへ変換してから渡す必要がある。gen/2 が swritef/3 で
% 生成する TypeStr はSWIのstringオブジェクトになるので、期待値の
% 文字列リテラルとは == で比較する(test内ではこちらもstringのまま
% なので一致する)。
:- begin_tests(infer).
test(id):-
    string_chars("let id = fun x -> x in id", Code),
    infer(Code, W), W == "a.a=>a".
test(k):-
    string_chars("let k = fun x -> fun y -> x in k", Code),
    infer(Code, W), W == "ab.a=>b=>a".
:- end_tests(infer).

:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
