:- use_module('../tprolog').

% --- 1. 基本型・演算子定義 ---
(+)    ::= [int_t, int_t] -> int_t.
(*)    ::= [int_t, int_t] -> int_t.
integer::= [_].
is     ::= [int_t, int_t].

% --- 2. 相互再帰型の定義 (Late Validation) ---
nat_even ::= zero | odd_succ(nat_odd).
nat_odd  ::= even_succ(nat_even).

% 型エイリアスの例
my_even  ::= nat_even.

% --- 3. 述語シグネチャと実装 ---
even ::= [nat_even].
odd  ::= [nat_odd].

even(zero).
even(odd_succ(O)) :- odd(O).

odd(even_succ(E)) :- even(E).

% --- 4. ロード完了後のカインド一括検証 ---
:- check_all_kinds(Results),
   ( member(error(_,_,_,_,_,_), Results) ->
       writeln('Kind check failed!')
   ;   writeln('All kinds validated successfully!')
   ).

% --- 5. サンプル実行プログラム ---
run :-
    writeln('--- 1. Mutual Recursion Execution ---'),
    Val = odd_succ(even_succ(zero)),
    ( even(Val) -> format('even(~p) succeeded!~n', [Val]) ; writeln('failed') ),

    writeln('--- 2. Type Checking Query ---'),
    ( check(_, (even(Val) :- true)) -> writeln('Type check PASSED for even(Val)') ),

    writeln('--- 3. Alias Kind Test ---'),
    ( tp([], zero, my_even) -> writeln('my_even alias recognised correctly!') ).
:- run.
:- halt.
