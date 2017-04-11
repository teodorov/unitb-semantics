
import data.stream

import unity.predicate
import unity.safety

import util.logic

universe variables u

namespace unity

section connectors

open predicate

-- variable s : Type
-- def pred : Type := s → Prop

class system (α : Type u) extends has_safety α : Type (u+1) :=
   (transient : α → pred' σ → Prop)
   (init : α → pred' σ → Prop)
   (transient_false : ∀ s : α, transient s $ λ _, false)
   (transient_str : ∀ (s : α) {p q : σ → Prop},
         (∀ i, p i → q i) →
         transient s q →
         transient s p )

def system.state := system.σ

-- def state α [system α] := system.state α

def transient {α} [system α] (s : α) (p : pred α) : Prop
:= system.transient s p

def init {α} [system α] (s : α) (p : pred α) : Prop
:= system.init s p

-- inductive unless {s} (p q : pred s) : Prop
--   | un : unless

-- variable t : @pred s

inductive leads_to {α} [system α] (s : α) : pred α → pred α → Prop
  | basis : ∀ {p q},
          transient s (p && ~ q) →
          unless s p q →
          leads_to p q
--  | impl : ∀ {p q : pred α}, (∀ i, p i → q i) → leads_to p q
  | trans : ∀ {p} q {r}, leads_to p q → leads_to q r → leads_to p r
  | disj : ∀ {t : Type} {p : t → pred α} {q},
         (∀ i, leads_to (p i) q) →
         leads_to (λ s, ∃ i, p i s) q


-- def select {α β γ} (p q : α) : β ⊕ γ → α
--   | (inl _) := p
--   | (inr _) := q

-- set_option pp.notation false

-- check @leads_to.disj
-- check bool
-- check sum

end connectors

-- def leads_to.rw_lhs

theorem system.unless_conj {α} [system α] (s : α) {p₀ q₀ p₁ q₁ : pred α} :
         unless s p₀ q₀ →
         unless s p₁ q₁ →
         unless s (p₀ && p₁) (q₀ || q₁) :=
begin
  intros h₀ h₁,
  note h₂ := unless_conj_gen _ h₀ h₁,
  apply unless_weak_rhs _ _ h₂,
  intros i,
  unfold p_and p_or, intro h,
  cases h with h h,
  cases h with h h,
  { cases h with h₂ h₃, exact or.inl h₂ },
  { cases h with h₂ h₃, exact or.inr h₃ },
  { cases h with h₂ h₃, exact or.inl h₂ },
end


theorem leads_to.impl {α} [system α] (s : α) {p q : pred α}
   (h : ∀ i, p i → q i)
   : leads_to s p q :=
begin
  apply leads_to.basis,
  { assert h' : (p && ~q) = λ _, false,
    { apply funext,
      intro x, unfold p_and p_not,
      apply eq_false_of_not_eq_true,
      apply eq_true_intro,
      intros h, cases h with hp hq,
      apply absurd (h _ hp) hq },
    rw h',
    apply system.transient_false },
  apply impl_unless _ h
end

theorem leads_to.weaken_lhs {α} [system α] {s : α} (q : pred α) {p r : pred α}
    (H : ∀ i, p i → q i)
    (P₀ : leads_to s q r)
    : leads_to s p r :=
begin
  apply leads_to.trans,
  apply leads_to.impl s H,
  apply P₀
end

theorem leads_to.strengthen_rhs {α} [system α] {s : α} (q : pred α) {p r : pred α}
    (H : ∀ i, q i → r i)
    (P₀ : leads_to s p q)
    : leads_to s p r :=
begin
  apply leads_to.trans,
  apply P₀,
  apply leads_to.impl s H,
end

lemma leads_to.disj_rng {α} [system α] {s : α} {t : Type} {p : t → pred α} {q} {r : t → Prop}
         (h : ∀ i, r i → leads_to s (p i) q)
         : leads_to s (λ s, ∃ i, r i ∧ p i s) q :=
begin
  assert h' : (λ s, ∃ (i : t), r i ∧ p i s) =
              (λ s, ∃ (i : { x : t // r x }), p i s),
  { apply funext, intro x,
    rw -iff_eq_eq, split,
    { intro h, cases h with j h,
      existsi subtype.mk j h^.left, apply h^.right },
    { intro h₀, cases h₀ with j h₀, cases j with j h₁ h₂,
      existsi j,
      split, apply h₁, apply h₀ } },
  rw h',
  apply leads_to.disj,
  intro i,
  apply h,
  apply i^.property
end

theorem leads_to.disj' {α} [system α] {s : α} {p q r : pred α}
    (Pp : leads_to s p r)
    (Pq : leads_to s q r)
    : leads_to s (p || q) r :=
begin
  apply leads_to.weaken_lhs (λ i, (∃ x : bool, (if x then p else q) i)),
  { intro i,
    apply or.rec,
    { intro h,
      existsi tt, apply h },
    { intro h,
      existsi ff, apply h }, },
  { apply @leads_to.disj _ _ _ bool (λ (x : bool) i, (if x then p else q) i),
    intro i,
    cases i,
    { refine leads_to.weaken_lhs _ _ Pq,
      intros σ h, apply h },
    { refine leads_to.weaken_lhs _ _ Pp,
      intros σ h, apply h }, }
end

theorem leads_to.gen_disj {α} [system α] {s : α} {p q r₀ r₁ : pred α}
    (Pp : leads_to s p r₀)
    (Pq : leads_to s q r₁)
    : leads_to s (p || q) (r₀ || r₁) :=
begin
  apply leads_to.disj',
  { apply leads_to.strengthen_rhs _ _ Pp,
    intro i, apply or.inl },
  { apply leads_to.strengthen_rhs _ _ Pq,
    intro i, apply or.inr },
end

-- print heq

def foo : ∀ (t₀ t₁ : Type) (x : t₀) (y : t₁), x == y → t₀ = t₁
  | t t' x y h := begin cases h, refl end

theorem leads_to.cancellation {α} [system α] {s : α} (q : pred α) {p r b : pred α}
    (P₀ : leads_to s p (q || b))
    (P₁ : leads_to s q r)
    : leads_to s p ( r || b ) :=
begin
  apply leads_to.trans _ P₀,
  apply leads_to.gen_disj P₁,
  apply leads_to.impl,
  intro, apply id
end

-- print notation &&
-- print notation ||

-- set_option pp.implicit true
-- set_option pp.notation false

def rel α [system α] : Type := system.state α → system.state α → Prop

theorem leads_to.induction {α} [system α] {s : α} {lt' : rel α} [wf : well_founded lt']
    {p q : pred α}
    (P : ∀ v, leads_to s (p && eq v) (p && flip lt' v || q))
  : leads_to s p q :=
begin
  pose lt := flip lt',
  assert P' : leads_to s (λ v', ∃ v, p v' ∧ eq v v') q,
  { apply leads_to.disj, intro i,
    pose PP := λ i, leads_to s (λ (v' : system.state α), p v' ∧ i = v') q,
    change PP i,
    apply @well_founded.induction _ lt' wf PP,
    intros j IH,
    change leads_to _ _ _,
    -- assert h₀ : q = (q || q), { admit },
    apply leads_to.strengthen_rhs (q || q),
    { intro, unfold p_or, rw or_self, exact id },
    apply leads_to.cancellation (p && lt j) (P _),
    assert h' : (p && lt j) = (λ s, ∃v, lt j v ∧ p s ∧ v = s),
    { apply funext,
      intro x,
      rw -iff_eq_eq, split,
      { intros H₀, cases H₀ with H₀ H₁,
        existsi x,
        repeat { split, assumption }, refl },
      { intro h, apply exists.elim h,
        intros s h', cases h' with h₀ h₁, cases h₁, subst s,
        exact ⟨a,h₀⟩ }, },
    rw h', clear h',
    apply leads_to.disj_rng,
    apply IH, },
  { assert h : (λ (v' : state α), ∃ (v : state α), p v' ∧ v = v') = p,
    { apply funext,
      intro x, rw -iff_eq_eq, split,
      { intro h, cases h with x h, cases h with h, apply h },
      { intro h, existsi x, split, assumption, refl } },
    rw h at P',
    apply P' }
end

theorem leads_to.PSP {α} [system α] {s : α} {p q r b : pred α}
    (P : leads_to s p q)
    (S : unless s r b)
    : leads_to s (p && r) ( (q && r) || b ) :=
begin
  induction P with p₀ q₀ t₀ u₀ p₁ q₁ r₁ PP₀ PP₁,
  { apply leads_to.basis,
    { apply system.transient_str _ _ t₀, intro i,
      unfold p_or p_not p_and p_or, intro h,
      cases h with h h', cases h with h₀ h₁,
      split, apply h₀,
      intro h₂, apply h', apply or.inl,
      unfold p_and,
      split, assumption, assumption, },
    { assert H : unless s r (r || b),
      { apply impl_unless, intro, apply or.inl },
      assert H' : unless s p₀ (q₀ || b),
      { apply unless_weak_rhs _ _ u₀,
        intro, apply or.inl },
      note H'' := unless_conj_gen _ u₀ S,
      apply unless_weak_rhs _ _ H'',
      intro i, unfold p_or p_and,
      intro hh, cases hh with hh₀ hh₀, cases hh₀ with hh₀ hh₀,
      { cases hh₀ with hh₀ hh₁, exact or.inl ⟨hh₀,hh₁⟩ },
      { cases hh₀ with hh₀ hh₁, exact or.inr hh₁ },
      { cases hh₀ with hh₀ hh₁, exact or.inr hh₁ } } },
  { note H := leads_to.cancellation _ ih_1 ih_2,
    assert H' : (r₁ && r || b || b) = (r₁ && r || b),
    { apply funext, intro,
      rw -iff_eq_eq,
      unfold p_or p_and, rw or_assoc, rw or_self },
    rw -H', apply H },
  { apply leads_to.weaken_lhs (λ s, ∃i, p_1 i s ∧ r s),
    { intros s h, cases h with h h',
      cases h with i h, existsi i,
      exact ⟨h,h'⟩ },
    apply leads_to.disj, intro i,
    apply ih_1 i, },
end

open predicate

class system_sem (α : Type u) extends system α :=
  (ex : α → stream _ → Prop)
  (inhabited : ∀s, ∃τ, ex s τ)
  (transient_sem : ∀ {s : α} {p : pred' _} (H : transient s p) (τ : stream _),
         ex s τ →
         ∀ i, p (τ i) → ∃ j, ¬ p (τ $ i+j))

namespace system_sem

variables {α : Type u}
variable [system_sem α]

lemma leads_to_sem {s : α} {p q : pred α} (P : leads_to s p q)
    (τ : stream _)
    (sem : ex s τ)
    (saf : saf_ex s τ)
: ∀ i, p (τ i) → ∃ j, q (τ $ i+j) :=
begin
  induction P with p' q' T S
        p q r P₀ P₁ H₀ H₁
        X p q P₀ H₀ x y z,
    -- transient and unless
  { intros i hp,
    note saf' := unless_sem _ saf S i hp,
    cases saf' with saf' saf',
    { cases classical.em (q' (τ i)) with hq hnq,
      { existsi 0, simp, apply hq },
      { note T' := transient_sem T τ sem,
        note T'' := T' i ⟨hp,hnq⟩,
        cases T'' with j T'',
        simp [not_and_iff_not_or_not,not_not_iff_self] at T'',
        cases T'' with T'' T'',
        { existsi j, apply T'' },
        { cases T'' (saf' _) } } },
    { apply saf' } },
    -- transitivity
  { intros i hp,
    note hq := H₀ i hp,
    cases hq with j hq,
    note hr := H₁ _ hq,
    cases hr with k hr,
    simp at hr,
    existsi (j+k),
    apply hr },
    -- disjunction
  { intros i hp,
    cases hp with x hp,
    apply H₀ x i hp,  }
end

end system_sem

end unity
