
import unity.code.syntax

section finite

open nat

parameters (σ : Type) {lbl : Type}

private def pred := σ → Prop

parameters {σ}

def control_nodes : Π {p q : pred}, code lbl p q → ℕ
  | ._ ._ (code.skip _) := 0
  | ._ ._ (code.action _ _ _) := 1
  | ._ ._ (@code.seq ._ ._ p q r c₀ c₁) := control_nodes c₀ + control_nodes c₁
  | ._ ._ (@code.if_then_else ._ ._ c pa pb q _ c₀ c₁) :=
     control_nodes c₀ + control_nodes c₁ + 1
  | ._ ._ (@code.while ._ ._ p inv q c b) :=
     control_nodes b + 1

def to_fin : Π {p q : pred} {c : code lbl p q}, current c → fin (control_nodes c)
  | ._ ._ ._ (current.action _ _ _) := ⟨0,zero_lt_one⟩
  | ._ ._ ._ (current.seq_left p q r c₀ c₁ pc) := fin.nest (to_fin pc)
  | ._ ._ ._ (current.seq_right p q r c₀ c₁ pc) := fin.shift (to_fin pc)
  | ._ ._ ._ (current.if_then_else_cond p t pa pb q c₀ c₁) :=
    (fin.max : fin (succ $ _ + _))
  | ._ ._ ._ (current.if_then_else_left p t pa pb q c₀ c₁ pc) :=
    (fin.nest $ fin.nest $ to_fin pc : fin (control_nodes c₀ + control_nodes c₁ + 1))
  | ._ ._ ._ (current.if_then_else_right p t pa pb q c₀ c₁ pc) :=
    (fin.nest $ fin.shift $ to_fin pc : fin (control_nodes c₀ + control_nodes c₁ + 1))
  | ._ ._ ._ (current.while_cond p inv q w c) :=
    (fin.max : fin (control_nodes c + 1))
  | ._ ._ ._ (current.while_body p inv q w c pc) :=
    (fin.nest $ to_fin pc : fin (control_nodes c + 1))

def from_fin : Π {p q} (c : code lbl p q), fin (control_nodes c) → current c
  | ._ ._ (code.skip _) ⟨_,P⟩ := by cases (nat.not_lt_zero _ P)
  | ._ ._ (code.action p q l) _ := current.action p q l
  | ._ ._ (@code.seq ._ ._ p q r c₀ c₁) m :=
    match fin.split m with
     | (sum.inl n) := seq_left  c₁ $ from_fin c₀ n
     | (sum.inr n) := seq_right c₀ $ from_fin c₁ n
    end
  | ._ ._ (@code.if_then_else ._ ._ p pa pb q t c₀ c₁) n :=
    match (fin.split n : fin (control_nodes c₀ + control_nodes c₁) ⊕ fin 1) with
     | (sum.inl n') :=
        match (fin.split n' : fin (control_nodes c₀) ⊕ fin (control_nodes c₁)) with
         | (sum.inl n) := ite_left  _ _ c₁ $ from_fin c₀ n
         | (sum.inr n) := ite_right _ _ c₀ $ from_fin c₁ n
        end
     | (sum.inr _) := ite_cond p t c₀ c₁
    end
  | ._ ._ (@code.while ._ ._ p inv q t b) n :=
    match (fin.split n : fin (control_nodes b) ⊕ fin 1) with
     | (sum.inl n') := while_body q t $ from_fin b n'
     | (sum.inr _) := while_cond q t b
    end

section g_over_constr

lemma from_fin_eq_seq_left
  {p q r : pred}
  {c₀ : code lbl p q} {c₁ : code lbl q r}
  {n : fin (control_nodes c₀ + control_nodes c₁)}
  {k : fin (control_nodes c₀)}
  (Hk : fin.split n = sum.inl k)
:   from_fin (code.seq c₀ c₁) n
  = seq_left c₁ (from_fin c₀ k) :=
by { unfold from_fin, simp [Hk], refl }

lemma from_fin_eq_seq_right
  {p q r : pred}
  {c₀ : code lbl p q} {c₁ : code lbl q r}
  {n : fin (control_nodes c₀ + control_nodes c₁)}
  {k : fin (control_nodes c₁)}
  (Hk : fin.split n = sum.inr k)
:   from_fin (code.seq c₀ c₁) n
  = seq_right c₀ (from_fin c₁ k) :=
by { unfold from_fin, simp [Hk], refl }

lemma from_fin_eq_ite_left
  {p t pa pb q : pred}
  {c₀ : code lbl pa q} {c₁ : code lbl pb q}
  {n  : fin (control_nodes c₀ + control_nodes c₁ + 1)}
  {k  : fin (control_nodes c₀ + control_nodes c₁)}
  {k' : fin (control_nodes c₀)}
  (Hk : fin.split n = sum.inl k)
  (Hk' : fin.split k = sum.inl k')
:   from_fin (if_then_else p t c₀ c₁) n
  = ite_left p t c₁ (from_fin c₀ k') :=
begin
  unfold from_fin, simp [Hk],
  unfold from_fin._match_2, simp [Hk'],
  refl,
end

lemma from_fin_eq_ite_right
  {p t pa pb q : pred}
  {c₀ : code lbl pa q} {c₁ : code lbl pb q}
  {n  : fin (control_nodes c₀ + control_nodes c₁ + 1)}
  {k  : fin (control_nodes c₀ + control_nodes c₁)}
  {k' : fin (control_nodes c₁)}
  (Hk : fin.split n = sum.inl k)
  (Hk' : fin.split k = sum.inr k')
:   from_fin (if_then_else p t c₀ c₁) n
  = ite_right p t c₀ (from_fin c₁ k') :=
begin
  unfold from_fin, simp [Hk],
  unfold from_fin._match_2, simp [Hk'],
  refl,
end

lemma from_fin_eq_ite_cond
  {p t pa pb q : pred}
  {c₀ : code lbl pa q} {c₁ : code lbl pb q}
  {n  : fin (control_nodes c₀ + control_nodes c₁ + 1)}
  {k  : fin 1}
  (Hk : fin.split n = sum.inr k)
:   from_fin (if_then_else p t c₀ c₁) n
  = ite_cond p t c₀ c₁ :=
by { unfold from_fin, simp [Hk], refl }

lemma from_fin_eq_while_body
  {p t inv q : pred}
  {c₀ : code lbl p inv}
  {n  : fin (control_nodes c₀ + 1)}
  {k  : fin $ control_nodes c₀}
  (Hk : fin.split n = sum.inl k)
:   from_fin (while q t c₀) n
  = while_body q t (from_fin c₀ k) :=
by { unfold from_fin, simp [Hk], refl }

lemma from_fin_eq_while_cond
  {p t inv q : pred}
  {c₀ : code lbl p inv}
  {n  : fin (control_nodes c₀ + 1)}
  {k  : fin 1}
  (Hk : fin.split n = sum.inr k)
:   from_fin (while q t c₀) n
  = while_cond q t c₀  :=
by { unfold from_fin, simp [Hk], refl }

end g_over_constr

lemma from_fin_inv {p q} {c : code lbl p q} (n : fin (control_nodes c))
: to_fin (from_fin c n) = n :=
begin
  induction c
  ; unfold control_nodes at n,
  { apply fin.elim0 n, },
  { unfold from_fin to_fin
  ; apply fin.eq_of_veq,
    unfold fin.val,
    apply le_antisymm (zero_le _),
    apply le_of_lt_succ,
    apply n.is_lt },
  { destruct fin.split n
    ; intros k Hk,
    { rw [from_fin_eq_seq_left Hk], unfold to_fin,
      rw [ih_1,fin.nest_eq_iff_eq_split,Hk], },
    { rw [from_fin_eq_seq_right Hk], unfold to_fin,
      rw [ih_2,fin.shift_eq_iff_eq_split,Hk], }, },
  { destruct fin.split n
    ; intros k Hk,
    destruct fin.split k
    ; intros k' Hk',
    { rw [from_fin_eq_ite_left Hk Hk'], unfold to_fin,
      simp [ih_1,fin.nest_eq_iff_eq_split,Hk],
      apply congr_arg,
      simp [fin.nest_eq_iff_eq_split,Hk'] },
    { rw [from_fin_eq_ite_right Hk Hk'], unfold to_fin,
      simp [ih_2,fin.nest_eq_iff_eq_split,Hk],
      apply congr_arg,
      simp [fin.shift_eq_iff_eq_split,Hk'] },
    { rw [from_fin_eq_ite_cond Hk], unfold to_fin,
      apply fin.split_injective _ n,
      simp [Hk,eq_comm],
      rw [-fin.shift_eq_iff_eq_split,fin.all_eq_zero k],
      apply fin.eq_of_veq, simp [fin.val_shift_zero], refl }, },
  { destruct fin.split n
    ; intros k Hk,
    { rw [from_fin_eq_while_body Hk], unfold to_fin,
      rw [ih_1,fin.nest_eq_iff_eq_split,Hk], },
    { rw [from_fin_eq_while_cond Hk], unfold to_fin,
      apply fin.split_injective _ n,
      simp [Hk,eq_comm],
      rw [-fin.shift_eq_iff_eq_split,fin.all_eq_zero k],
      apply fin.eq_of_veq, simp [fin.val_shift_zero], refl, }, }
end

lemma to_fin_inv {p q} {c : code lbl p q} (pc : current c)
: from_fin c (to_fin pc) = pc := sorry

instance current_finite {p q : pred} {c : code lbl p q} : finite (current c) :=
⟨ control_nodes c,
  bijection.mk to_fin (from_fin c) to_fin_inv from_fin_inv ⟩

instance current_sched {p q : pred} {c : code lbl p q} : scheduling.sched (current c) :=
scheduling.sched.fin (by apply_instance)

end finite
