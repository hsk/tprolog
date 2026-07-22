:-op(1100,xfx,:::).
tp(Γ,M,T):-var(M),!,lookup_env(M,T,Γ).
tp(Γ,M,int):-integer(M),!,lookup_env(M,int,Γ).
tp(Γ,M,atom):-atom(M),!,lookup_env(M,atom,Γ).
tp(_,[],list(_)):-!.
tp(_,M,T):-atom(M),!,(M:::[]->T).
tp(Γ,M,T):-compound(M),!,M=..[C|Ms],(C:::Ts->T),maplist(tp(Γ),Ms,Ts).
lookup_env(M,T,[M1:T1|_]):-M==M1,!,T=T1.
lookup_env(M,T,[M:T|_]):-!.
lookup_env(M,T,[_|Rest]):-lookup_env(M,T,Rest).
goal(Γ,G):-G=..[P|Ms],(P:::Ts),maplist(tp(Γ),Ms,Ts).
body(_,true):-!.
body(Γ,(A,B)):-!,body(Γ,A),body(Γ,B).
body(Γ,G):-goal(Γ,G).
check(Γ,(Head:-Body)):-goal(Γ,Head),body(Γ,Body).
check(Γ,Head):-goal(Γ,Head).
'[|]':::[A,list(A)]->list(A).
append:::[list(X),list(X),list(X)].
int:::[int]->expr.
add:::[expr,expr]->expr.
mul:::[expr,expr]->expr.
eval:::[expr,int].
integer:::[int].
is:::[int,int].
(+):::[int,int]->int.
(*):::[int,int]->int.
var:::[atom]->expr.
abs:::[atom,expr]->expr.
app:::[expr,expr]->expr.
int:::[int]->v.
(:):::[atom,v]->atom:v.
env:::[list(atom:v)]->env.
clause:::[list(atom:v),atom,expr]->v.
ev:::[list(atom:v),expr,v].
member:::[A,list(A)].
:-check(_,(append([1],[2],[1,2]):-true)).%ok
:-check(_,(eval(int(I),I):-integer(I))).%ok
:-check(_,(eval(add(E1,E2),I):-eval(E1,I1),eval(E2,I2),I is I1+I2)).%ok
:-check(_,(eval(mul(E1,E2),I):-eval(E1,I1),eval(E2,I2),I is I1*I2)).%ok
:-check(_,(ev(_,int(I),int(I)))).%ok
:-check(_,(ev(Γ,add(E1,E2),int(I)):-ev(Γ,E1,int(I1)),ev(Γ,E2,int(I2)),I is I1+I2)).%ok
:-check(_,(ev(Γ,mul(E1,E2),int(I)):-ev(Γ,E1,int(I1)),ev(Γ,E2,int(I2)),I is I1+I2)).%ok
:-check(_,(ev(Γ,var(X),V):-member(X:V,Γ))).%ok
:-check(_,(ev(Γ,app(E1,E2),I):-ev(Γ,E1,clause(Γ2,X,E)),ev(Γ,E2,V2),ev([X:V2|Γ2],E,I))).%ok
:-check(_,(ev(Γ,abs(X,E),clause(Γ,X,E)))).%ok
:-halt.
