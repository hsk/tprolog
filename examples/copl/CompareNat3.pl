:- use_module('../../tprolog').

:- op(800,xfx,isLessThan).

% --- 型 (Peano自然数) ---
nat ::= z | s(nat).

% --- 述語シグネチャ ---
(!)        ::= [].
isLessThan ::= [nat, nat].

% ------------------- L-Succ
% n is less than S(n)
N isLessThan s(N) :- !.

% n1 is less than n2
% ------------------ L-SuccR
% n1 is less than S(n2)
N1 isLessThan s(N2) :-
    N1 isLessThan N2.

% --- ロード完了後のカインド一括検証 ---
:- type_check_all.

:- begin_tests(compare_nat3).
    % 1 < 2
    test(1):- s(z) isLessThan s(s(z)).
    % 2 < 3
    test(2):- s(s(z)) isLessThan s(s(s(z))).
:- end_tests(compare_nat3).
:- run_tests.
:- halt.
