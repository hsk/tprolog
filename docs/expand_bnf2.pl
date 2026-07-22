% 引数なしのコンストラクタは作る
:-op(1200,xfx,[::=,:::]).
:-op(600,xfy,[$]).
:- dynamic (:::)/2.
expand_bnf(T::=T2):-T2\=(_|_),assertz(T:::T2).
expand_bnf(T::=TE):-flat(TE,Cs),alts(Cs,T,Ts),assertz(T:::Ts).
flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
alts([],_,[]).
alts([Op->T|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->G),alts(Ts,G,Cs).
expr::=int_t|atom_t|expr+expr|expr*expr|expr$expr|λ(atom_t,expr).
a::=e.
t::=int|(t->t).
:-findall(T::=TE,T::=TE,BNFs),maplist(expand_bnf,BNFs).
:-forall(A:::B,writeln(A:::B)).
:-halt.
