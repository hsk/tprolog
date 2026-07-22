:-op(1100,xfx,:::).
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
'[|]':::[A,list(A)]->list(A).
append:::[list(X),list(X),list(X)].
integer:::[_].
is:::[int_t,int_t].
(+):::[int_t,int_t]->int_t.
(*):::[int_t,int_t]->int_t.
member:::[A,list(A)].
atom:::[atom_t].
(!):::[].

(+):::[expr,expr]->expr.
(*):::[expr,expr]->expr.
λ:::[atom_t,expr]->expr.
($):::[expr,expr]->expr.
expr:::[int_t,atom_t,(+),(*),($),λ].
eval:::[expr,int_t].

(:):::[atom_t,V]->atom_t:V.
env:::list(atom_t:v).
clause:::[env,atom_t,expr]->v.
v:::[int_t,clause].
ev:::[env,expr,v].
(->):::[t,t]->t.
i:::[]->t.
t:::[i,->].
tc:::[expr,t].

:-check(_,(append([1],[2],[1,2]):-true)),!.
:-check(_,(eval(I,I):-integer(I))),!.
:-check(_,(eval(E1+E2,I):-eval(E1,I1),eval(E2,I2),I is I1+I2)),!.
:-check(_,(eval(E1*E2,I):-eval(E1,I1),eval(E2,I2),I is I1*I2)),!.
:-check(_,(ev(_,I,I):-integer(I),!)),!.
:-check(_,(ev(Γ,E1+E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1+I2)),!.
:-check(_,(ev(Γ,E1*E2,I):-ev(Γ,E1,I1),ev(Γ,E2,I2),I is I1*I2)),!.
:-check(_,(ev(Γ,X,V):-atom(X),!,member(X:V,Γ))),!.
:-check(_,(ev(Γ,E1$E2,I):-ev(Γ,E1,clause(Γ2,X,E)),ev(Γ,E2,V2),ev([X:V2|Γ2],E,I))),!.
:-check(_,(ev(Γ,λ(X,E),clause(Γ,X,E)))),!.
:-[]⊢int_t<:expr,!.
:-check(_,(tc(I,i):-integer(I))),!.
:-halt.
