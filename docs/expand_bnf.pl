:-op(1200,xfx,[::=,:::]).
:-op(600,xfy,[$]).
expand_bnf(T::=T2):-T2\=(_|_),assertz(T:::T2).
expand_bnf(T::=TE):-flat(TE,Cs),alts(Cs,T,Ts),assertz(T:::Ts).
flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
%flat(T,R):-foldl([X,I,O]>>(I=(X|O);(I=X,O=[])),R,T,[]),!.%一行でかけるが訳がわからないw
% 述語リストを順番に試して成功するまで頑張る述語
%call_any([G|_], X, I, O) :- call(G, X, I, O), !.
%call_any([_|Gs], X, I, O) :- call_any(Gs, X, I, O).
%flat(T,R):-foldl(call_any([[(H|N),N,H]>>!,[H,[],H]>>!]),T,R,[]),!.
% こう書きたいけどまぁ新しい言語が流行ったらだなw foldl({case(H|N,N,H),case(H,[],H)},T,R,[]).
alts([],_,[]).
alts([T|Ts],G,[T|Ts2]):-atom(T),!,alts(Ts,G,Ts2).
alts([Op->T|Ts],G,[C|Cs]):-compound(Op),!,Op=..[C|As],assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-compound(Op),!,Op=..[C|As],assertz(C:::As->G),alts(Ts,G,Cs).
expr::=int_t|atom_t|expr+expr|expr*expr|expr$expr|λ(atom_t,expr).
a::=e.
t::=int|(t->t).
:-findall(T::=TE,T::=TE,BNFs),maplist(expand_bnf,BNFs).
:-forall(A:::B,writeln(A:::B)).
:-halt.
