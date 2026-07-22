:-op(1200,xfx,[::=,:::]).
:-op(700,xfx,⊢).
:-op(600,xfy,[$,<:,#]).
_⊢T<:T:-!.
Γ⊢T1<:T2:-member(Elm,Γ),Elm==(T1<:T2),!.
_⊢T1<:T2:-var(T1),!,T1=T2.
Γ⊢T1<:T2:-(T1:::R1),R1\=(_->_),!,[T1<:T2|Γ]⊢R1<:T2.
Γ⊢T1<:T2:-(T2:::R2),R2\=(_->_),!,[T1<:T2|Γ]⊢T1<:R2.
Γ⊢T1<:T2:-is_list(T1),is_list(T2),!,forall(member(X,T1),([T1<:T2|Γ]⊢[X]<:T2)).
Γ⊢T1<:T2:-is_list(T2),!,member(Y,T2),(T1=Y;[T1<:T2|Γ]⊢T1<:Y),!.
tp(Γ,M,T):-var(M),!,lookup_env(M,T,Γ).
tp(_,M,T):-integer(M),!,[]⊢int_t<:T.
tp(_,M,T):-atom(M),(M:::[]->T1),!,[]⊢T1<:T.
tp(_,M,T):-atom(M),!,[]⊢atom_t<:T.
tp(_,[],T):-!,[]⊢list(A)<:T,[]⊢T<:list(A).
tp(Γ,[H|Tail],list(A)):-!,tp(Γ,H,A),tp(Γ,Tail,list(A)).
tp(Γ,M,T):-compound(M),!,M=..[C|Ms],(C:::Ts->T1),[]⊢T1<:T,maplist(tp(Γ),Ms,Ts).
lookup_env(M,T,[M1:T1|_]):-M==M1,!,([]⊢T<:T1;[]⊢T1<:T).
lookup_env(M,T,[Elm|_]):-var(Elm),!,Elm=(M:T).
lookup_env(M,T,[_|Rest]):-lookup_env(M,T,Rest).
goal(Γ,G):-G=..[P|Ms],(P:::Ts),maplist(tp(Γ),Ms,Ts).
body(_,true):-!.
body(Γ,(A,B)):-!,body(Γ,A),body(Γ,B).
body(Γ,G):-goal(Γ,G).
check(Γ,Head:-Body):-goal(Γ,Head),body(Γ,Body).
check(Γ,Head):-goal(Γ,Head).
expand_bnf(T::=T2):-T2\=(_|_),assertz(T:::T2).
expand_bnf(T::=TE):-flat(TE,Cs),alts(Cs,T,Ts),assertz(T:::Ts).
flat(T|T2,[T|Ts]):-!,flat(T2,Ts).
flat(T,[T]).
alts([],_,[]).
alts([Op->T|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->T),alts(Ts,G,Cs).
alts([Op|Ts],G,[C|Cs]):-Op=..[C|As],G\=C,assertz(C:::As->G),alts(Ts,G,Cs).
:- dynamic (:::)/2. :- discontiguous (:::)/2.
term_expansion(A::=B,[]):-expand_bnf(A::=B).
'[|]'  ::= [A,list(A)]->list(A).
(+)    ::= [int_t,int_t]->int_t.
(*)    ::= [int_t,int_t]->int_t.
append ::= [list(X),list(X),list(X)].
integer::= [_].
is     ::= [int_t,int_t].
member ::= [A,list(A)].
atom   ::= [atom_t].
(!)    ::= [].
(:)    ::= [atom_t,V]->atom_t:V.
env    ::= list(atom_t:v).
expr   ::= int_t|atom_t|expr+expr|expr*expr|expr$expr|λ(atom_t,expr).
v      ::= int_t|clause(env,atom_t,expr).
eval   ::= [expr,int_t].
ev     ::= [env,expr,v].
t      ::= i | (t->t).
tc     ::= [expr,t].
:-begin_tests(t).
test(1):-check(_,(append([1],[2],[1,2]):-true)),!.
test(2):-check(_,(eval(I,I):-integer(I))),!.
test(3):-check(_,(eval(E1+E2,I):-eval(E1,I1),eval(E2,I2),I is I1+I2)),!.
test(4):-check(_,(eval(E1*E2,I):-eval(E1,I1),eval(E2,I2),I is I1*I2)),!.
test(5):-check(_,(ev(_,I,I):-integer(I),!)),!.
test(6):-check(_,(ev(Γ,E1+E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1+I2)),!.
test(7):-check(_,(ev(Γ,E1*E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1*I2)),!.
test(8):-check(_,(ev(Γ,X,V):-atom(X),!,member(X:V,Γ))),!.
test(9):-check(_,(ev(Γ,E1$E2,I):-ev(Γ,E1,clause(Γ2,X,E)),ev(Γ,E2,V2),ev([X:V2|Γ2],E,I))),!.
test(10):-check(_,(ev(Γ,λ(X,E),clause(Γ,X,E)))),!.
test(11):-[]⊢int_t<:expr,!.
test(12):-check(_,(tc(I,i):-integer(I))),!.
:-end_tests(t).
:-run_tests.
:-halt.
