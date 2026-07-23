:- use_module('../../tprolog').

:- op(600,xfx,⇓).
:- op(700,xfx,is).
:- op(800,xfx,plus).
:- op(800,xfx,times).

% --- 型 (Peano自然数と式) ---
nat ::= z | s(nat).
% exp は nat リテラルと、その加算・乗算からなる式。
exp ::= nat | exp+exp | exp*exp.

% plus/times は 'N1 plus N2 is N3' という中置記法で書かれているが、
% is(700,xfx) は plus/times(800,xfx) より優先順位の数値が小さい
% (=強く結合する)ため、実際には
%   plus(N1, is(N2,N3))
% という項に展開される(times も同様)。この is(nat,nat) という
% 形をカインドとして登録しておく。
nat_is ::= is(nat,nat).

% --- 述語シグネチャ ---
plus  ::= [nat, nat_is].
times ::= [nat, nat_is].
(⇓)   ::= [exp, nat].

% -------------- E-Const
% n ⇓ n
N ⇓ N.

% e1 ⇓ n1   e2 ⇓ n2   n1 plus n2 is n
% ------------------------------------- E-Plus
% e1 + e2 ⇓ n
E1 + E2 ⇓ N :-
    E1 ⇓ N1, E2 ⇓ N2, N1 plus N2 is N.

% e1 ⇓ n1   e2 ⇓ n2   n1 times n2 is n
% ------------------------------------- E-Times
% e1 * e2 ⇓ n
E1 * E2 ⇓ N :-
    E1 ⇓ N1, E2 ⇓ N2, N1 times N2 is N.

% ------------- P-Zero
% Z plus n is n
z plus N is N.

% n1 plus n2 is n
% --------------------- P-Succ
% S(n1) plus n2 is S(n)
s(N1) plus N2 is s(N) :-
    N1 plus N2 is N.

% --------------- T-Zero
% Z times n1 is Z
z times _ is z.

% n1 times n2 is n3    n2 plus n3 is n4
% ------------------------------------- T-Succ
% S(n1) times n2 is n4
s(N1) times N2 is N4 :-
    N1 times N2 is N3, N2 plus N3 is N4.

% --- ロード完了後のカインド一括検証 ---
:- type_check_all.

:- begin_tests(eval_nat_exp).
    % 0 + 2 ⇓ 2
    test(1):- z + s(s(z)) ⇓ s(s(z)).
    % 2 + 0 ⇓ 2
    test(2):- s(s(z)) + z ⇓ s(s(z)).
    % 3 + 2 * 1 ⇓ 5
    test(3):- s(s(s(z))) + s(s(z)) * s(z) ⇓ s(s(s(s(s(z))))).
:- end_tests(eval_nat_exp).
:- run_tests.
:- halt.
