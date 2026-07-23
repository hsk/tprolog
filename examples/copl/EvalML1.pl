:- use_module('../../tprolog').

:- set_prolog_flag(double_quotes, chars).
:- op(600,xfy,⇓).
:- op(700,xfx,is).
:- op(800,xfx,plus).
:- op(800,xfx,minus).
:- op(800,xfx,times).
:- op(800,xfx,lessThan).

% --- 型 ---
% 値: 整数(int_t)そのもの、または真偽値アトム(bool_v)そのもの。
bool_v ::= true | false.
v ::= int_t | bool_v.

% 式(構文解析で得られるAST)。
e ::= int(int_t) | bool(bool_v)
    | e+e | e-e | e*e | (e<e)
    | if(e,e,e).

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
(⇓)      ::= [e, v].

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

% eval

% i ⇓ i
int(I) ⇓ I.

% b ⇓ b
bool(B) ⇓ B.

% e1 ⇓ i1   e2 ⇓ i2   i1 plus i2 is i3
% --------------------------------------
% e1 + e2 ⇓ i3
E1 + E2 ⇓ I3 :-
    E1 ⇓ I1, E2 ⇓ I2, I1 plus I2 is I3.

% e1 ⇓ i1   e2 ⇓ i2   i1 minus i2 is i3
% ---------------------------------------
% e1 - e2 ⇓ i3
E1 - E2 ⇓ I3 :-
    E1 ⇓ I1, E2 ⇓ I2, I1 minus I2 is I3.

% e1 ⇓ i1   e2 ⇓ i2   i1 times i2 is i3
% ---------------------------------------
% e1 * e2 ⇓ i3
E1 * E2 ⇓ I3 :-
    E1 ⇓ I1, E2 ⇓ I2, I1 times I2 is I3.

% e1 ⇓ i1   e2 ⇓ i2   i1 less than i2 is b
% ------------------------------------------
% e1 < e2 ⇓ b
(E1 < E2) ⇓ B :-
    E1 ⇓ I1, E2 ⇓ I2, I1 lessThan I2 is B.

% e1 ⇓ true   e2 ⇓ v
% -------------------------
% if e1 then e2 else e3 ⇓ v
if(E1, E2, _) ⇓ V :-
    E1 ⇓ true, E2 ⇓ V.

% e1 ⇓ false   e3 ⇓ v
% -------------------------
% if e1 then e2 else e3 ⇓ v
if(E1, _, E3) ⇓ V :-
    E1 ⇓ false, E3 ⇓ V.

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
code_result(Code, Result) :-
    phrase(tokens(Tokens), Code),
    phrase(expr(E), Tokens),
    E ⇓ Result, !.
test(String, Result):-
    string_chars(String, Chars),
    code_result(Chars, Result).
:- begin_tests(eval_ml1).
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
:- end_tests(eval_ml1).
:- set_prolog_flag(plunit_output, always).
:- run_tests.
:- halt.
