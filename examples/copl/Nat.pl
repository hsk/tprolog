:- use_module('../../tprolog').

:- op(700,xfx,is).
:- op(800,xfx,plus).
:- op(800,xfx,times).

% --- 型 (Peano自然数) ---
nat ::= z | s(nat).

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

:- begin_tests(nat).
    % 1 + 1 = 2
    test(1) :- s(z) plus s(z) is s(s(z)).
    % 2 * 3 = 6
    test(2) :- s(s(z)) times s(s(s(z))) is s(s(s(s(s(s(z)))))).
:- end_tests(nat).
:- run_tests.
:- halt.
