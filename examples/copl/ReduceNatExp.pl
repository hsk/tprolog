:- use_module('../../tprolog').

:- op(590,xfy,-->). % ⟶
:- op(590,xfx,->*). % ⟶*
:- op(590,xfx,->>). % ⟶d
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
(!)    ::= [].
peano  ::= [nat].
plus   ::= [nat, nat_is].
times  ::= [nat, nat_is].
(-->)  ::= [exp, exp].
(->>)  ::= [exp, exp].
(->*)  ::= [exp, exp].

peano(z).
peano(s(N)) :-
    peano(N).

% n1 plus n2 is n3
% ---------------- R-Plus
% n1 + n2 -> n3
N1 + N2 --> N3 :-
    N1 plus N2 is N3, !.

% n1 times n2 is n3
% ---------------- R-Times
% n1 * n2 -> n3
N1 * N2 --> N3 :-
    N1 times N2 is N3, !.

% e1 -> e1'
% ------------------- R-PlusL
% e1 + e2 -> e1' + e2
E1 + E2 --> E1_ + E2 :-
    E1 --> E1_.

% e2 -> e2'
% ------------------- R-PlusR
% e1 + e2 -> e1 + e2'
E1 + E2 --> E1 + E2_ :-
    E2 --> E2_.

% e1 -> e1'
% ------------------- R-TimesL
% e1 * e2 -> e1' * e2
E1 * E2 --> E1_ * E2 :-
    E1 --> E1_.

% e2 -> e2'
% ------------------- R-TimesR
% e1 * e2 -> e1 * e2'
E1 * E2 --> E1 * E2_ :-
    E2 --> E2_.

% ------- MR-Zero
% e ->* e
E ->* E.

% e -> e'
% ------- MR-One
% e ->* e'
E ->* E_ :-
    E --> E_.

% e -> e'   e' ->* e''
% --------------------- MR-Multi'
% e ->* e''
E ->* E__ :-
    E --> E_, E_ ->* E__.

% DR-Plus
N1 + N2 ->> N3 :-
    peano(N1), peano(N2), peano(N3),
    N1 plus N2 is N3, !.

% DR-Times
N1 * N2 ->> N3 :-
    peano(N1), peano(N2), peano(N3),
    N1 times N2 is N3, !.

% DR-PlusL
E1 + E2 ->> E1_ + E2 :-
    E1 ->> E1_, !.

% DR-PlusR
N1 + E2 ->> N1 + E2_ :-
    peano(N1), E2 ->> E2_, !.

% DR-TimesL
E1 * E2 ->> E1_ * E2 :-
    E1 ->> E1_, !.

% DR-TimesR
N1 * E2 ->> N1 * E2_ :-
    peano(N1), E2 ->> E2_, !.

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

:- begin_tests(reduce_nat_exp).
    % 0 + 2 -> 2
    test(1):- z + s(s(z)) --> s(s(z)).
    % 2 + 0 -> 2
    test(2):- s(s(z)) + z --> s(s(z)).
    % 2 * 0 -> 0
    test(3):- s(s(z)) * z --> z.
    % 2 * 1 -> 2
    test(4):- s(s(z)) * s(z) --> s(s(z)).
    % 1 * 1 + 1 * 1 -> 1 * 1 + 1
    test(5):- s(z) * s(z) + s(z) * s(z) --> s(z) * s(z) + s(z).
    % 0 + 2 ->* 2
    test(6):- z + s(s(z)) ->* s(s(z)), !.
    % 1 * 1 + 1 * 1 ->d 1 + 1 * 1
    test(7):- s(z) * s(z) + s(z) * s(z) ->> s(z) + s(z) * s(z).
    % 1 * 1 + 1 * 1 ->* 2
    % --> は e1/e2 のどちらを先に簡約してもよい非決定的な関係なので、
    % ->* の探索途中で複数の簡約順序(choicepoint)が生まれる。
    % ここでは「少なくとも1つの導出が存在する」ことだけを見たいので
    % ! で最初の解に確定させる。
    test(8):- s(z) * s(z) + s(z) * s(z) ->* s(s(z)),!.
:- end_tests(reduce_nat_exp).
:- run_tests.
:- halt.
