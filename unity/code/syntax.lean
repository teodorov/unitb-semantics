
import unity.models.nondet
import unity.predicate

import util.data.option
import util.data.sum

universe variables u v

open nat predicate

section

parameters (σ : Type) (lbl : Type)

@[reducible]
def pred := σ → Prop

parameters {σ}

inductive code : pred → pred → Type
  | skip {} : ∀ p, code p p
  | action : ∀ p q, lbl → code p q
  | seq : ∀ {p q r}, code p q → code q r → code p r
  | if_then_else : ∀ p {pa pb q}, pred → code pa q → code pb q → code p q
  | while : ∀ {p inv} q, pred → code p inv → code inv q

parameters {σ lbl}

@[pattern,reducible]
def if_then_else : ∀ p {pa pb q}, pred → code pa q → code pb q → code p q :=
code.if_then_else

@[pattern,reducible]
def while : ∀ {p inv} q, pred → code p inv → code inv q :=
@code.while

inductive current : ∀ {p q}, code p q → Type
  | action : ∀ p q l, current (code.action p q l)
  | seq_left : ∀ p q r (c₀ : code p q) (c₁ : code q r), current c₀ → current (code.seq c₀ c₁)
  | seq_right : ∀ p q r (c₀ : code p q) (c₁ : code q r), current c₁ → current (code.seq c₀ c₁)
  | if_then_else_cond  : ∀ p t pa pb q (c₀ : code pa q) (c₁ : code pb q),
         current (code.if_then_else p t c₀ c₁)
  | if_then_else_left  : ∀ p t pa pb q (c₀ : code pa q) (c₁ : code pb q),
         current c₀ → current (code.if_then_else p t c₀ c₁)
  | if_then_else_right : ∀ p t pa pb q (c₀ : code pa q) (c₁ : code pb q),
         current c₁ → current (code.if_then_else p t c₀ c₁)
  | while_cond : ∀ p inv q w (c : code p inv),
         current (code.while q w c)
  | while_body : ∀ p inv q w (c : code p inv),
         current c → current (code.while q w c)

@[reducible]
def seq_left {p q r} {c₀ : code p q} (c₁ : code q r)
  (cur : current c₀)
: current (code.seq c₀ c₁) :=
current.seq_left _ _ _ c₀ _ cur

@[reducible]
def seq_right {p q r} (c₀ : code p q) {c₁ : code q r}
  (cur : current c₁)
: current (code.seq c₀ c₁) :=
current.seq_right _ _ _ c₀ _ cur

@[reducible]
def ite_cond (p t) {pa pb q} (c₀ : code pa q) (c₁ : code pb q)
: current (if_then_else p t c₀ c₁) :=
current.if_then_else_cond p t _ _ _ c₀ c₁

@[reducible]
def ite_left (p t) {pa pb q} {c₀ : code pa q} (c₁ : code pb q) (cur₀ : current c₀)
: current (if_then_else p t c₀ c₁) :=
current.if_then_else_left p t _ _ _ c₀ c₁ cur₀

@[reducible]
def ite_right (p t) {pa pb q} (c₀ : code pa q) {c₁ : code pb q} (cur₁ : current c₁)
: current (if_then_else p t c₀ c₁) :=
current.if_then_else_right p t _ _ _ c₀ c₁ cur₁

@[reducible]
def while_cond {p inv} (q w) (c : code p inv)
: current (code.while q w c) :=
current.while_cond p inv q w c

@[reducible]
def while_body {p inv} (q w) {c : code p inv}
  (cur : current c)
: current (code.while q w c) :=
current.while_body p inv q w c cur

def selects' : Π {p q} {c : code p q}, current c → lbl → Prop
  | ._ ._ ._ (current.action _ _ e') e := e = e'
  | ._ ._ ._ (current.seq_left _ _ _ s c p) e := selects' p e
  | ._ ._ ._ (current.seq_right _ _ _ _ _ p) e := selects' p e
  | ._ ._ ._ (current.if_then_else_cond _ _ _ _ _ _ _) e    := false
  | ._ ._ ._ (current.if_then_else_left _ _ _ _ _ _ _ p) e  := selects' p e
  | ._ ._ ._ (current.if_then_else_right _ _ _ _ _ _ _ p) e := selects' p e
  | ._ ._ ._ (current.while_cond _ _ _ _ _) e   := false
  | .(inv) .(q) ._ (current.while_body p inv q _ _ pc) e := selects' pc e

def selects {p q} {c : code p q} : option (current c) → lbl → Prop
  | (some c) := selects' c
  | none := False

def is_control' : Π {p q} {c : code p q}, current c → bool
  | ._ ._ ._ (current.action _ _ l) := ff
  | ._ ._ ._ (current.seq_left  p q r _ _ pc)       := is_control' pc
  | ._ ._ ._ (current.seq_right p q r _ _ pc)       := is_control' pc
  | .(p) .(q) ._ (current.if_then_else_cond  p t pa pb q _ _) := tt
  | ._ ._ ._ (current.if_then_else_left  p t _ _ _ _ _ pc)    := is_control' pc
  | ._ ._ ._ (current.if_then_else_right p t _ _ _ _ _ pc)    := is_control' pc
  | .(inv) .(q) ._ (current.while_cond p inv q t _) := tt
  | ._ ._ ._ (current.while_body _ _ _ _ _ pc)      := is_control' pc

def is_control {p q} {c : code p q} : option (current c) → bool
  | (some pc) := is_control' pc
  | none := ff

-- def control {p q} (c : code p q) := subtype (@is_control _ _ c)

-- instance is_control_decidable
-- : ∀ {p q} {c : code p q} (cur : current c), decidable (is_control cur)
--   | ._ ._ ._ (current.action _ _ _) := decidable.false
--   | ._ ._ ._ (current.seq_left p q r c₀ c₁ cur) := is_control_decidable cur
--   | ._ ._ ._ (current.seq_right p q r c₀ c₁ cur) := is_control_decidable cur
--   | ._ ._ ._ (current.if_then_else_cond  p t pa pb q c₀ c₁) := decidable.true
--   | ._ ._ ._ (current.if_then_else_left  p t pa pb q c₀ c₁ cur) := is_control_decidable cur
--   | ._ ._ ._ (current.if_then_else_right p t pa pb q c₀ c₁ cur) := is_control_decidable cur
--   | ._ ._ ._ (current.while_cond p t inv q c) := decidable.true
--   | ._ ._ ._ (current.while_body p t inv q c cur) := is_control_decidable cur

def condition' : Π {p q} {c : code p q} (pc : current c), is_control' pc → σ → Prop
  | ._ ._ ._ (current.action _ _ _) h := by cases h
  | ._ ._ ._ (current.seq_left  p q r c₀ c₁ pc) h := condition' pc h
  | ._ ._ ._ (current.seq_right p q r c₀ c₁ pc) h := condition' pc h
  | .(p) .(q) ._ (current.if_then_else_cond  p c pa pb q c₀ c₁) h := c
  | .(p) .(q) ._ (current.if_then_else_left  p c pa pb q c₀ c₁ pc) h := condition' pc h
  | .(p) .(q) ._ (current.if_then_else_right p c pa pb q c₀ c₁ pc) h := condition' pc h
  | .(inv) .(q) ._ (current.while_cond p inv q c _) h    := c
  | .(inv) .(q) ._ (current.while_body p inv q _ _ pc) h := condition' pc h

def condition {p q} {c : code p q} : ∀ pc : option $ current c, is_control pc → σ → Prop
  | (some pc) := condition' pc
  | none := take h, by cases h

def action_of : Π {p q} {c : code p q} (cur : current c),
{ p // ∃ P, condition (some cur) P = p }  ⊕ subtype (selects (some cur))
  | ._ ._ ._ (current.action _ _ l) := sum.inr ⟨l,rfl⟩
  | ._ ._ ._ (current.seq_left  p q r _ _ pc) := action_of pc
  | ._ ._ ._ (current.seq_right p q r _ _ pc) := action_of pc
  | .(p) .(q) ._ (current.if_then_else_cond  p t pa pb q _ _) := sum.inl ⟨t,rfl,rfl⟩
  | ._ ._ ._ (current.if_then_else_left  p t _ _ _ _ _ pc) := action_of pc
  | ._ ._ ._ (current.if_then_else_right p t _ _ _ _ _ pc) := action_of pc
  | .(inv) .(q) ._ (current.while_cond p inv q t _)    := sum.inl ⟨t,rfl,rfl⟩
  | ._ ._ ._ (current.while_body _ _ _ _ _ pc) := action_of pc

def assert_of' : Π {p q} {c : code p q}, current c → σ → Prop
  | .(p) ._ ._ (current.action p _ _) := p
  | ._ ._ ._ (current.seq_left  _ _ _ _ _ pc) := assert_of' pc
  | ._ ._ ._ (current.seq_right _ _ _ _ _ pc) := assert_of' pc
  | .(p) ._ ._ (current.if_then_else_cond  p _ _ _ _ _ _)  := p
  | ._ ._ ._ (current.if_then_else_left  _ _ _ _ _ _ _ pc) := assert_of' pc
  | ._ ._ ._ (current.if_then_else_right _ _ _ _ _ _ _ pc) := assert_of' pc
  | .(inv) .(q) ._ (current.while_cond p inv q _ _)  := inv
  | ._ ._ ._ (current.while_body _ _ _ _ _ pc) := assert_of' pc

def assert_of {p q} {c : code p q} : option (current c) → σ → Prop
  | none := q
  | (some pc) := assert_of' pc

local attribute [instance] classical.prop_decidable

noncomputable def next_assert' : Π {p q} {c : code p q}, current c → σ → σ → Prop
  | ._ .(q) ._ (current.action _ q _) := λ _, q
  | ._ ._ ._ (current.seq_left  _ _ _ _ _ pc) := next_assert' pc
  | ._ ._ ._ (current.seq_right _ _ _ _ _ pc) := next_assert' pc
  | .(p) .(q) ._ (current.if_then_else_cond  p t pa pb q _ _)  := λ s, if t s then pa else pb
  | ._ ._ ._ (current.if_then_else_left  _ _ _ _ _ _ _ pc) := next_assert' pc
  | ._ ._ ._ (current.if_then_else_right _ _ _ _ _ _ _ pc) := next_assert' pc
  | .(inv) .(q) ._ (current.while_cond p inv q t _)  := λ s, if t s then p else q
  | ._ ._ ._ (current.while_body _ _ _ _ _ pc) := next_assert' pc

noncomputable def next_assert {p q} {c : code p q} : option (current c) → σ → σ → Prop
  | none := λ _, q
  | (some pc) := next_assert' pc

def first : Π {p q} (c : code p q), option (current c)
  | ._ ._ (code.skip p) := none
  | ._ ._ (code.action p _ l) := some $ current.action _ _ _
  | .(p) .(r) (@code.seq ._ ._ p q r c₀ c₁) :=
        seq_left c₁ <$> first _
    <|> seq_right _ <$> first _
  | ._ ._ (@if_then_else ._ ._ p _ _ _ c b₀ b₁) :=
    some $ ite_cond _ _ _ _
  | ._ ._ (@code.while ._ ._ _ _ _ c b) :=
    some $ while_cond _ _ _

lemma assert_of_first {p q} {c : code p q}
: assert_of (first c) = p :=
begin
  induction c
  ; try { refl },
  { unfold first,
    destruct first a,
    { intro h,
      simp [h],
      destruct first a_1,
      { intro h',
        simp [h'], unfold assert_of,
        simp [h'] at ih_2, unfold assert_of at ih_2,
        simp [h] at ih_1, unfold assert_of at ih_1,
        subst r, subst q_1 },
      { intros x h', simp [h'],
        unfold assert_of assert_of',
        rw h at ih_1, rw h' at ih_2,
        unfold assert_of at ih_1 ih_2,
        subst p_1, rw ih_2, } },
    { intros x h,
      simp [h],
      unfold assert_of assert_of',
      rw h at ih_1, unfold assert_of at ih_1,
      rw ih_1 }, }
end

noncomputable def next' (s : σ) : ∀ {p q} {c : code p q}, current c → option (current c)
  | ._ ._ ._ (current.action p q l) := none
  | ._ ._ ._ (current.seq_left _ _ _ c₀ c₁ cur₀) :=
        seq_left c₁ <$> next' cur₀
    <|> seq_right c₀ <$> first c₁
  | ._ ._ ._ (current.seq_right _ _ _ c₀ c₁ cur₁) :=
        seq_right _ <$> next' cur₁
  | .(p) .(q) ._ (current.if_then_else_cond p c pa pb q b₀ b₁) :=
      if c s
         then ite_left _ _ _ <$> first b₀
         else ite_right _ _ _ <$> first b₁
  | ._ ._ ._ (current.if_then_else_left _ _ _ _ _ b₀ b₁ cur₀) :=
      ite_left _ _ b₁ <$> next' cur₀
  | ._ ._ ._ (current.if_then_else_right _ _ _ _ _ b₀ b₁ cur₁) :=
      ite_right _ _ _ <$> next' cur₁
  | .(inv) .(q) ._ (current.while_cond p inv q c b) :=
      if c s
      then while_body q c <$> first b <|> some (while_cond _ _ b)
      else none
  | ._ ._ ._ (current.while_body _ _ q c b cur) :=
          while_body q c <$> next' cur
      <|> some (while_cond _ _ b)

noncomputable def next (s : σ) {p q : pred} {c : code p q}
: option (current c) → option (current c)
  | (some pc) := next' s pc
  | none := none

lemma first_eq_none_imp_eq {p q : pred} {c : code p q}
: first c = none → p = q :=
begin
  induction c ; unfold first,
  { simp },
  { contradiction, },
  { destruct first a,
    { intro h', simp [h'],
      intro h'', rw [ih_1 h',ih_2 h''], },
    { intros pc h,
      simp [h], contradiction }, },
  { contradiction },
  { contradiction },
end

lemma assert_of_next {p q : pred} {c : code p q} (pc : option (current c)) (s : σ)
: assert_of (next s pc) = next_assert pc s :=
begin
  cases pc with pc,
  { refl },
  unfold next next_assert,
  induction pc
  ; try { refl }
  ; unfold next' next_assert',
  { rw -ih_1,
    cases next' s a,
    destruct first c₁,
    { intros h₀,
      simp [h₀],
      unfold assert_of,
      cases c₁ ; try { refl }
      ; unfold first at h₀
      ; try { contradiction },
      { simp at h₀,
        simp [first_eq_none_imp_eq h₀.left,first_eq_none_imp_eq  h₀.right] }, },
    { intros pc h₀,
      simp,
      rw [h₀,fmap_some],
      unfold assert_of assert_of',
      change assert_of (some pc) = _,
      rw [-h₀,assert_of_first] },
    { simp, refl } },
  { rw -ih_1,
    cases next' s a ; refl },
  { cases classical.em (t s) with h h,
    { rw [if_pos h,if_pos h],
      destruct first c₀,
      { intros h, simp [h], have h := first_eq_none_imp_eq h,
        unfold assert_of, subst pa },
      { intros pc h, simp [h],
        unfold assert_of assert_of',
        change assert_of (some pc) = _,
        rw [-h,assert_of_first], }, },
    { rw [if_neg h,if_neg h],
      destruct first c₁,
      { intros h, simp [h],
        have h := first_eq_none_imp_eq h,
        unfold assert_of, subst pb },
      { intros pc h, simp [h],
        unfold assert_of assert_of',
        change assert_of (some pc) = _,
        rw [-h,assert_of_first], }, }, },
  { rw -ih_1, clear ih_1,
    cases next' s a with pc ; simp,
    { refl },
    { unfold assert_of assert_of', refl }, },
  { rw -ih_1, clear ih_1,
    cases next' s a with pc ; simp,
    { refl },
    { unfold assert_of assert_of', refl }, },
  { cases classical.em (w s) with h h ;
    destruct first c_1,
    { intro h',
      rw [if_pos h,if_pos h,h'],
      have h'' := first_eq_none_imp_eq h', subst inv,
      refl, },
    { intros pc h',
      rw [if_pos h,if_pos h,h'],
      simp,
      change assert_of (some pc) = _,
      rw [-h',assert_of_first], },
    { intros h',
      rw [if_neg h,if_neg h], refl },
    { intros pc h',
      rw [if_neg h,if_neg h], refl }, },
  { rw -ih_1, clear ih_1,
    destruct next' s a,
    { intros h',
      simp [h'], refl },
    { intros pc h',
      simp [h'], refl }, },
end

end