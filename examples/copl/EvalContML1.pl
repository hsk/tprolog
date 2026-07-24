:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(585,xfy,>>).
:- op(590,xfx,=>).
:- op(600,xfx,evalto).
:- op(700,xfx,is).
:- op(800,xfx,plus).
:- op(800,xfx,minus).
:- op(800,xfx,times).
:- op(800,xfx,lessThan).

% --- tok/tokens/digit の型 (EvalML1.pl と同じ。この言語には変数が
% 無いので var(list(atom_t)) は不要) ---
bool_v ::= true | false.

% トークンの種類。記号・キーワードは int(_)/bool(_) 以外、
% 個別に列挙せず「裸の atom_t」で受け止める
% (EvalML1.pl と同じ理由: 個別登録すると tp/3 のカットで汎用の
%  atom_t として分類できなくなるため)。
tok_type ::= int(int_t) | bool(bool_v) | atom_t.

% DCG変換後の節が差分リストを繋ぐのに使う (=)/2 と '[|]' のシグネチャ。
'[|]'     ::= [A,list(A)]->list(A).
(=)       ::= [X, X].
(!)       ::= [].

tok    ::= [tok_type, list(atom_t), list(atom_t)].
digits ::= [list(atom_t), list(atom_t), list(atom_t)].
digit  ::= [atom_t, list(atom_t), list(atom_t)].
tokens ::= [list(tok_type), list(atom_t), list(atom_t)].

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
tok(-) --> "-".
tok(*) --> "*".
tok(<) --> "<".
tok('(') --> "(".
tok(')') --> ")".
tok(if) --> "if".
tok(then) --> "then".
tok(else) --> "else".

digits([C|Cs]) --> digit(C), digits(Cs).
digits([C])    --> digit(C).

digit(C)   --> [C], { code_type(C, digit) }.

% --- 式(AST)とパーサの型 ---
% この言語には var/let/fun が無いので、e はごく単純な算術+条件式。
e ::= int(int_t) | bool(bool_v) | e+e | e-e | e*e | (e<e) | if(e,e,e).

expr   ::= [e, list(tok_type), list(tok_type)].
expr1  ::= [e, e, list(tok_type), list(tok_type)].
term   ::= [e, list(tok_type), list(tok_type)].
term1  ::= [e, e, list(tok_type), list(tok_type)].
factor ::= [e, list(tok_type), list(tok_type)].

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

factor(int(I)) --> [int(I)].
factor(bool(B)) --> [bool(B)].
factor(E) --> "(", expr(E), ")".
factor(if(E1, E2, E3)) -->
    [if], expr(E1), [then], expr(E2), [else], expr(E3).

% --- 評価(CPS/フレームスタック)の型 ---
% 値: 整数、または真偽値アトム。
bool_v ::= true | false.
v ::= int_t | bool_v.

% 継続 K は「フレームの積み重ね」で、末尾は '_'(空の継続)。
% frame >> cont を再帰的に積み重ねる(cont::=... | (frame>>cont).)。
cont ::= '_' | (frame >> cont).

% frame_body は算術・比較演算子の左右どちらかが穴(未評価を表す '_')
% になっている形と、if の条件部が穴になっている形。
% tprolog はリテラル値としての '_' を「左右どちらの位置にあるか」で
% 厳密に区別できない(未束縛の引数はどちらの候補を先に試しても
% その場で対応する型を受け入れてしまい、'_' 自身も cont ::= '_'|...
% の登録により v/e のような複数選択肢カインドに対しては緩く適合して
% しまうため、(穴+e)と(v+穴)を別の選択肢として分けても実際には
% 常に最初の選択肢に決着してしまい、正しく区別できない)。そのため
% 穴の位置を区別せず、両辺とも v/e の1パターンにまとめている
% (どちら側が '_' であっても、'_' は v にも e にも緩く適合するため
%  これで両方のケースを受け入れられる)。
frame_body ::= (v + e) | (v - e) | (v * e) | (v < e) | if(v, e, e).
frame ::= {frame_body}.

% 'E >> K evalto V' は evalto(>>(E,K),V)、'V => K evalto V' は
% evalto(=>(V,K),V) という項になる(write_canonical で確認)。
% >> の左は式(評価中)、=> の左は値(継続へ渡す途中)という使い分け。
eval_judgment ::= (e >> cont) | (v => cont).
evalto ::= [eval_judgment, v].

% plus/minus/times/lessThan は 'I1 plus I2 is I3' という中置記法で
% 書かれているが、plus 等(800,xfx) は is(700,xfx) より優先順位の
% 数値が小さい(=強く結合する)ため、実際には
%   plus(I1, is(I2,I3))
% という項に展開される。結果型を汎用の _V で受け付ける。
result_is ::= is(int_t, _V).
% B-Plus等の本体 'I3 is I1+I2' は Prolog組み込みの is/2 をゴールとして
% 呼んでおり、I1+I2 という複合項(算術演算としての +)を int_t として
% 検査する必要がある。e の +/-/*/< は AST構成子(e+e->e)としての
% 登録なので、これとは別に整数演算としての登録が要る(EvalML1.pl以降
% と同じ)。
(+) ::= [int_t,int_t] -> int_t.
(-) ::= [int_t,int_t] -> int_t.
(*) ::= [int_t,int_t] -> int_t.
is       ::= [int_t,int_t].
(<)      ::= [int_t,int_t].
plus     ::= [int_t, result_is].
minus    ::= [int_t, result_is].
times    ::= [int_t, result_is].
lessThan ::= [int_t, result_is].

% --- パーサまでの型検査 ---
:- type_check_all.

% eval

% i => k evalto v
% ---------------
% i >> k evalto v
int(I) >> K evalto V :-
    I => K evalto V.

% b => k evalto v
% ---------------
% b >> k evalto v
bool(B) >> K evalto V :-
    B => K evalto V.

% -----------------
% v => '_' evalto v
V => '_' evalto V.

% e1 >> {_ op e2} >> k evalto v
% ------------------------
% e1 op e2 >> k evalto v
E1 + E2 >> K evalto V :-
    E1 >> {'_' + E2} >> K evalto V.
E1 - E2 >> K evalto V :-
    E1 >> {'_' - E2} >> K evalto V.
E1 * E2 >> K evalto V :-
    E1 >> {'_' * E2} >> K evalto V.
(E1 < E2) >> K evalto V :-
    E1 >> {'_' < E2} >> K evalto V.

% e >> {v1 op _} >> k evalto v2
% ------------------------
% v1 => {_ op e} >> k evalto v2
V1 => {'_' + E} >> K evalto V2 :-
    E >> {V1 + '_'} >> K evalto V2.
V1 => {'_' - E} >> K evalto V2 :-
    E >> {V1 - '_'} >> K evalto V2.
V1 => {'_' * E} >> K evalto V2 :-
    E >> {V1 * '_'} >> K evalto V2.
V1 => {'_' < E} >> K evalto V2 :-
    E >> {V1 < '_'} >> K evalto V2.

% i1 plus i2 is i3   i3 ⇒ k evalto v
% -----------------------------
% i2 ⇒ {i1 + _} ≫ k evalto v
I2 => {I1 + '_'} >> K evalto V :-
    I1 plus I2 is I3, I3 => K evalto V.

% i1 minus i2 is i3   i3 ⇒ k ⇓ v
% ----------------------------
% i2 ⇒ {i1 - _} >> k ⇓ v
I2 => {I1 - '_'} >> K evalto V :-
    I1 minus I2 is I3, I3 => K evalto V.

% i1 times i2 is i3   i3 ⇒ k ⇓ v
% ----------------------------
% i2 ⇒ {i1 * _} >> k ⇓ v
I2 => {I1 * '_'} >> K evalto V :-
    I1 times I2 is I3, I3 => K evalto V.

% i1 less than i2 is b3   b3 ⇒ k ⇓ v
% ----------------------------------
% i2 ⇒ {i1 < _} >> k ⇓ v
I2 => {I1 < '_'} >> K evalto V :-
    I1 lessThan I2 is B3, B3 => K evalto V.

% e1 >> {if _ then e2 else e3} >> k ⇓ v
%------------------------------------
% if e1 then e2 else e3 >> k ⇓ v
if(E1, E2, E3) >> K evalto V :-
    E1 >> {if('_', E2, E3)} >> K evalto V.

% e1 >> k ⇓ v
% --------------------------------------
% true ⇒ {if _ then e1 else e2} >> k ⇓ v
true => {if('_', E1, _)} >> K evalto V :-
    E1 >> K evalto V.

% e2 >> k ⇓ v
% ---------------------------------------
% false ⇒ {if _ then e1 else e2} >> k ⇓ v
false => {if('_', _, E2)} >> K evalto V :-
    E2 >> K evalto V.

I1 plus I2 is I3 :-
    I3 is I1 + I2.
I1 minus I2 is I3 :-
    I3 is I1 - I2.
I1 times I2 is I3 :-
    I3 is I1 * I2.
% 元々は 'I1 < I2 -> B = true; B = false.' という if-then-else で
% 書かれていたが、tprolog のメタ型検査(body/2)は ','/2 と true しか
% 特別扱いしないため、->/;/= を含む節はそのままでは型検査できない。
% 全く同じ挙動になる、2節+カットの形に書き換えている。
I1 lessThan I2 is true :- I1 < I2, !.
_I1 lessThan _I2 is false.

% --- eval までの型検査 ---
:- type_check_all.

% --- UI (code_result/2 等) の型 ---
% string_chars/2 の第1引数はSWIのstringオブジェクトで、tp/3 に対応する
% 節が無い(atomでもリストでもcompoundでもない)ため、汎用にする。
string_chars ::= [_, list(atom_t)].
code_result  ::= [list(atom_t), v].
code_expr    ::= [list(atom_t), e].
% test は writef/2 に list(atom_t) と v が混在する引数リストを渡すため、
% tprolog の list(A)(同種要素のみ)では型付けできない(EvalML2.pl参照)。
% そのためシグネチャを与えず、型検査の対象外(untyped)のままにする。

% UI
% phrase/2 は使わず、DCG変換後の3引数の述語として直接呼ぶ
% (tokens(Tokens,Code,[]) は phrase(tokens(Tokens),Code) と同じ意味。
%  phrase/2 は非終端記号を reified call として渡す高階述語で、
%  tprolog はcallableという概念を持たないため型付けできない)。
code_result(Code, Result) :-
    tokens(Tokens, Code, []),
    expr(E, Tokens, []),
    E >> _ evalto Result, !.

code_expr(Code, E) :-
    tokens(Tokens, Code, []),
    expr(E, Tokens, []).

% code_result/code_expr は type_check_all の後で定義したので、
% ここでもう一度呼んでまとめて検証する。
:- type_check_all.

% test
% test内(:-begin_tests/:-end_testsの中)ではdouble_quotes=charsが
% 効かず、文字列リテラルがSWIのstringオブジェクトのままになるため、
% string_chars/2で明示的にcharsのリストへ変換してからcode_result/2に
% 渡す(EvalML1.pl以降のtest/2と同じパターン)。
test(String, Expected) :-
    string_chars(String, Code),
    code_result(Code, Actual),
    (Expected = Actual -> writef('%s evalto %w\n', [Code, Actual]);
    writef('%s evalto %w expected, but got %w\n', [Code, Expected, Actual]), fail).

:- begin_tests(eval_cont_ml1).
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
test(13):- test("1", 1).
:- end_tests(eval_cont_ml1).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.