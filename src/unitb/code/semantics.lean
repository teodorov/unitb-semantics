
import unitb.code.syntax
import unitb.code.instances
import unitb.code.rules
import unitb.code.lemmas
import unitb.refinement.superposition
import unitb.category.transformer

import util.logic
import util.meta.tactic
import util.predicate
import util.data.subtype

import temporal_logic

namespace code.semantics

section
open code predicate temporal nondet

parameters (σ : Type)
@[reducible]
private def pred := pred' σ
parameters {p : nondet.program σ}
parameters {term : pred}
parameters {c : code p.lbl p.first term}

parameter Hterm : ∀ ae : p.lbl, term ⟹ -p.coarse_sch_of ae

structure state :=
  (pc : option (current c))
  (intl : σ)
  (assertion : assert_of pc intl)

parameter {σ}
parameter Hcorr : ∀ pc, state_correctness p c pc

-- include Hcorr

section event

parameter (e : p.lbl)
parameter (s : state)
parameter (h₀ : selects s.pc e)
parameter (h₁ : true)

section implicit

include h₁

theorem evt_guard
: p.guard e s.intl :=
(Hcorr s.pc).enabled e h₀ s.intl s.assertion

theorem evt_coarse_sch
: p.coarse_sch_of e s.intl :=
evt_guard.left

theorem evt_fine_sch
: p.fine_sch_of e s.intl :=
evt_guard.right

end implicit

def machine.run_event (s' : state) : Prop :=
(p.event $ some e).step s.intl evt_coarse_sch evt_fine_sch s'.intl

end event

def machine.step
  (e : current c)
  (s  : state)
  (h : some e = s.pc)
  (s' : state) : Prop :=
  s'.pc = next s.intl s.pc
∧ match action_of e with
   | (sum.inr ⟨l,hl⟩) :=
         have h : selects (s.pc) l,
              by { simp [h] at hl, apply hl },
         machine.run_event l s h trivial s'
   | (sum.inl _) := s'.intl = s.intl
  end

def machine.step_fis
  (e : current c)
  (s  : state)
  (h : some e = s.pc)
: ∃ (s' : state), machine.step e s h s' :=
begin
  destruct action_of e
  ; intros l Hl,
  { have Hss' : assert_of (next s.intl s.pc) s.intl,
    { rw assert_of_next,
      cases l with l H, cases H with P H,
      rw ← h,
      cases classical.em (condition (some e) P s.intl) with Hc Hnc,
      { apply (Hcorr $ some e).cond_true _ _ _ Hc,
        rw h,
        apply s.assertion, },
      { apply (Hcorr $ some e).cond_false _ _ _ Hnc,
        rw h,
        apply s.assertion } },
    let ss' := state.mk (next s.intl s.pc) s.intl Hss',
    existsi ss',
    unfold machine.step,
    split,
    { refl },
    { rw Hl, unfold machine.step._match_1 machine.run_event } },
  { cases l with l hl,
    rw h at hl,
    have CS := evt_coarse_sch Hcorr l s hl trivial,
    have FS := evt_fine_sch Hcorr l s hl trivial,
    cases (p.event l).fis s.intl CS FS with s' H,
    have Hss' : assert_of (next s.intl s.pc) s',
    { rw [assert_of_next],
      apply (Hcorr _).correct _ hl s.intl _ _ ⟨CS,FS,H⟩,
      apply s.assertion },
    let ss' := state.mk (next s.intl s.pc) s' Hss',
    existsi ss',
    unfold machine.step,
    split,
    { refl },
    { rw Hl, unfold machine.step._match_1 machine.run_event,
      apply H } }
end

def machine.event (cur : current c) : nondet.event state :=
  { coarse_sch := λ s, some cur = s.pc
  , fine_sch   := True
  , step := λ s hc _ s', machine.step cur s hc s'
  , fis  := λ s hc _, machine.step_fis cur s hc }

def mch_of : nondet.program state :=
 { lbl := current c
 , lbl_is_sched := by apply_instance
 , first := λ ⟨s₀,s₁,_⟩, s₀ = first c ∧ p.first s₁
 , first_fis :=
   begin cases p.first_fis with s Hs,
         have Hss : assert_of (first c) s,
         { rw assert_of_first, apply Hs },
         let ss := state.mk (first c) s Hss,
         existsi ss,
         unfold mch_of._match_1,
         exact ⟨rfl,Hs⟩
   end
 , event' := machine.event }

@[simp]
lemma coarse_sch_of_mch_of_some (e : mch_of.lbl)
: mch_of.coarse_sch_of (some e) = (λ s : state, some e = s.pc) :=
by { cases e ; refl }

lemma event_mch_of_some (e : mch_of.lbl)
: mch_of.event (some e) = machine.event e :=
by { cases e ; refl }

@[simp]
lemma fine_sch_of_mch_of (e : option mch_of.lbl)
: mch_of.fine_sch_of e = True :=
by { cases e ; refl }

@[simp]
lemma step_of_mch_of (e : mch_of.lbl) (s : state)
: mch_of.step_of (some e) s = (λ s', ∃ Hc : some e = s.pc, machine.step e s Hc s') :=
begin
  apply funext, intro s',
  dunfold code.semantics.mch_of program.step_of program.event program.event',
  dunfold code.semantics.machine.event nondet.event.step_of,
  dunfold event.coarse_sch event.fine_sch event.step,
  apply iff.to_eq,
  apply exists_congr ,
  intro Hc ,
  dsimp [True_eq_true] ,
  rw exists_true,
end

lemma step_event'_mch_of_imp_pc_eq_next (e : mch_of.lbl) (s s' : state)
  (Hc : mch_of.coarse_sch_of (some e) s)
  (Hf : mch_of.fine_sch_of (some e) s)
  (H : (mch_of.event' e).step s Hc Hf s')
: s'.pc = next s.intl s.pc :=
H.left

open superposition

def rel (l : option mch_of.lbl) : option p.lbl → Prop
  | (some e) := selects l e
  | none     := is_control l ∨ l = none

lemma ref_sim (ec : option mch_of.lbl)
: ⟦mch_of.step_of ec⟧ ⟹
      ∃∃ (ea : {ea // rel ec ea}), ⟦p.step_of (ea.val) on state.intl⟧ :=
begin
  rw exists_action,
  apply action_entails_action,
  intros s s' H,
  cases ec with pc,
  case none
  { let x : {ea // rel Hcorr none ea},
    { existsi none, unfold rel is_control, right, refl },
    existsi x, unfold function.on_fun,
    unfold mch_of nondet.program.step_of nondet.program.event
           nondet.skip nondet.event.step_of
           nondet.event.fine_sch nondet.event.coarse_sch
           nondet.event.step  at H,
    unfold nondet.program.step_of nondet.program.event
           nondet.skip nondet.event.step_of
           nondet.event.fine_sch nondet.event.coarse_sch
           nondet.event.step,
    apply exists_imp_exists' (assume _, trivial) _ H, intro,
    apply exists_imp_exists' (assume _, trivial) _, intros _,
    simp, intro, subst s, },
  case some
  { destruct action_of pc,
    case sum.inl
    { intros c Hact,
      cases c with c Hc,
      cases Hc with P Hc,
      let x : {ea // rel Hcorr (some pc) ea},
      { existsi none, unfold rel is_control, left, apply P },
      existsi x,
      unfold function.on_fun nondet.program.step_of nondet.program.event
             nondet.event.step_of,
      unfold nondet.program.step_of nondet.program.event
             nondet.event.step_of at H,
      apply exists_imp_exists' (assume _, trivial) _ H, intro,
      apply exists_imp_exists' (assume _, trivial) _, intros _,
      intros H',
      change _ = _,
      dunfold code.semantics.mch_of nondet.program.event'
              code.semantics.machine.event
              nondet.event.step
              code.semantics.machine.step at H',
      rw Hact at H',
      symmetry, apply H'.right, },
    case sum.inr
    { intros e Hact,
      cases e with e He,
      let x : {ea // rel Hcorr (some pc) ea},
      { existsi (some e), apply He },
      existsi x, unfold function.on_fun,
      dunfold code.semantics.mch_of nondet.program.step_of nondet.program.event
              nondet.program.event' code.semantics.machine.event nondet.event.step_of
              nondet.event.coarse_sch nondet.event.fine_sch
              nondet.event.step at H,
      cases H with Hc H, cases H with Hf H,
      dunfold code.semantics.machine.step at H,
      rw Hact at H, unfold machine.step._match_1 machine.run_event at H,
      rw Hc at He,
      have Hen := (Hcorr s.pc).enabled e He _ s.assertion,
      exact ⟨Hen.left,Hen.right,H.right⟩, }, },
end

section ref_resched

parameter ea : option p.lbl

variable ec : { ec // rel ec ea }

section leads_to

open unitb
parameter pc : current c
parameters p' q' : pred
parameter c' : code p.lbl p' q'
parameter H : subtree c' c
parameter e : p.lbl

@[reducible]
def lt_sched := except (λ s : state, selects s.pc e) (leads_to mch_of)

@[trans]
def lt_sched_trans
  {α} (β) {γ : pred' state}
  (h₀ : lt_sched α β)
  (h₁ : lt_sched β γ)
: lt_sched α γ :=
h₁ <<< h₀

local infix `  ↦.  `:60 := lt_sched

lemma evt_leads_to_aux
: (λ s : state, within H s.pc)
    ↦.
  (λ s : state, exits H s.pc) :=
begin
  induction c',
  case code.skip
  { apply lifted_pred.imp,
    intro s,
    apply not_within_skip },
  case code.action
  { apply except_lift,
    apply @ensure_rule _ (mch_of Hcorr) _ _ (some (counter H)),
      -- EN
    { rw coarse_sch_of_mch_of_some,
      intro s, simp [not_or_iff_not_and_not,and_shunting,exits],
      intros H₀ H₁,
      apply counter_action_of_within H₀ H₁, },
      -- FLW
    { simp [fine_sch_of_mch_of],
      apply leads_to.trivial },
      -- STEP
    { intros s s' Hp Hstep,
      rw step_of_mch_of at Hstep,
      cases Hstep with Hc Hstep,
      unfold machine.step at Hstep,
      cases Hstep with Hstep₀ Hstep₁,
      rw [Hstep₀,← Hc],
      rw next_counter_action,
      unfold exits, },
      -- STABLE
    { apply unless_rule,
      intros ec s Hc Hf s' Hstep Hp,
--      rw [not_or_iff_not_and_not,and_shunting],
      intros Hnq₀,
      right,
      unfold exits,
      have Hp := counter_action_of_within Hp Hnq₀,
      rw [← next_counter_action s.intl H, Hp],
      symmetry,
      apply Hstep.left, }, },
  case code.seq p₀ q r c₀ c₁ ih_1 ih_2 H
  { have Pright : lt_sched Hcorr e
                  (λ (s : state), within H.right (s.pc))
                  (λ (s : state), exits H (s.pc)),
    { simp [exits_iff_exits_right],
      apply ih_2 H.right },
    have Pleft : lt_sched Hcorr e
                 (λ (s : state), within H.left (s.pc))
                 (λ (s : state), exits H (s.pc)),
    { apply lt_sched_trans Hcorr e (λ (s : state), exits H.left (s.pc)),
      { apply ih_1 },
      apply antimono_left,
      { intro, apply exits_left_imp_within_right H },
      { apply Pright } },
    simp [within_left_or_within_right_iff_within_seq],
    apply disj _ Pleft Pright, },
  case code.if_then_else
  { admit },
  case code.while
  { admit },
end

end leads_to

open unitb
include Hterm

lemma evt_leads_to
: (p.coarse_sch_of ea ⋀ (p.event ea).fine_sch) ∘ state.intl
    ↦
      -(p.coarse_sch_of ea ∘ state.intl)
      ⋁ ∃∃ ec : { ec // rel ec ea }, mch_of.coarse_sch_of ec.val
   in mch_of :=
begin
  cases ea with ea,
  { apply unitb.leads_to.imp,
    apply entails_p_or_of_entails_right,
    intros s h, simp,
    let ec : {ec // rel Hcorr ec none},
    { existsi none, apply or.inr, refl },
    existsi [ec.val,ec.property], unfold_local ec,
    simp },
  have H := (evt_leads_to_aux Hcorr _ _ c subtree.rfl ea).run,
  revert H,
  apply unitb.leads_to.monotonicity,
  { intros s q,
    apply within_rfl },
  apply p_or_entails_p_or,
  { -- type_check (term ∘ state.intl),
    -- type_check entails_trans (term ∘ state.intl),
    refine entails_trans (term ∘ state.intl) _ _,
    { intro s, simp [exits],
      intro H,
      have Hasrt := s.assertion,
      rw ← H at Hasrt,
      apply Hasrt, },
    { rw p_not_comp,
      refine comp_entails_comp _ _,
      apply Hterm }, },
  { intros s h,
    let ec : {ec // rel Hcorr ec (some ea)},
    { existsi s.pc, apply h, },
    apply p_exists_intro ec,
    revert ec, simp,
    destruct s.pc,
    { intros h, simp [h], },
    { intros ec Hec, simp [Hec], }, },
end

omit Hterm


lemma evt_resched
: (p.coarse_sch_of ea ⋀ p.fine_sch_of ea) ∘ state.intl ⋀ True
  ⋀ mch_of.coarse_sch_of ec
    >~>
      mch_of.fine_sch_of ec  in  mch_of :=
begin
  simp,
  apply unitb.often_imp_often.basis,
  apply unitb.leads_to.trivial,
end

include Hterm

lemma evt_delay
: (p.coarse_sch_of ea ⋀ (p.event ea).fine_sch) ∘ state.intl
    >~>
      -(p.coarse_sch_of ea ∘ state.intl)
      ⋁ ∃∃ ec : { ec // rel ec ea }, True ⋀ mch_of.coarse_sch_of ec.val
   in mch_of :=
begin
  simp,
  apply often_imp_often.basis,
  apply evt_leads_to Hterm Hcorr ea,
end

omit Hterm

lemma evt_stable
: unless_except mch_of
      (True ⋀ mch_of.coarse_sch_of ec)
      (-(p.coarse_sch_of ea ∘ state.intl))
      { e | ∃ (l : {ec // rel ec ea}), mch_of.event l = e } :=
begin
  apply unless_except_rule,
  intros e s Hc Hf s' Hexcp H₀ H₁ H₂,
  simp [function.comp],
  simp [mem_set_of,not_exists_iff_forall_not] at Hexcp,
  simp [program.event,mch_of,machine.event,program.coarse_sch_of] at H₁ Hc,
  cases ec with ec Hec,
  specialize Hexcp ec Hec,
  cases ec with ec,
  { right, trivial, },
  simp at H₁,
  exfalso, apply Hexcp,
  dsimp [program.event,code.semantics.mch_of,program.event,machine.event] at H₁ Hc,
  rw ← Hc at H₁,
  rw H₁,
  refl
end

lemma evt_sim
:    ⟦mch_of.step_of (ec.val)⟧
 ⟹ ⟦p.step_of ea on state.intl⟧ :=
begin
  apply action_entails_action,
  intros s s',
  dunfold function.on_fun,
  cases ec with ec Hec,
  cases ea,
  case some ea
  { dunfold code.semantics.rel at Hec,
    cases ec with ec,
    { cases Hec },
    { unfold_projs,
      have Hgrd : (machine.event Hcorr ec).coarse_sch s
                → (p.event' ea).guard (s.intl),
      { unfold machine.event,
        unfold nondet.event.coarse_sch, intro H,
        rw H at Hec,
        apply (Hcorr s.pc).enabled _ Hec,
        apply s.assertion },
      have Hcs : (machine.event Hcorr ec).coarse_sch s
               → (p.event' ea).coarse_sch (s.intl),
      { apply and.left ∘ Hgrd },
      rw [step_of_mch_of],
      apply exists_imp_exists' Hcs,
      intros Hcs,
      have Hfs : (p.event' ea).fine_sch (s.intl),
      { apply (Hgrd Hcs).right },
      simp [machine.step],
      destruct action_of ec,
      case sum.inr
      { intros ea' Hea, cases ea' with ea' Hea',
        simp [Hea,machine.step._match_1,machine.run_event],
        intros ea'' Hea'',
        simp [nondet.program.event,mch_of,nondet.program.event'] at *,
        existsi Hfs,
        have H := selects_and_selects_imp_eq _ Hec Hea',
        subst ea', assumption, },
      case sum.inl
      { intros pc Hea, rw Hea,
        simp [machine.step._match_1],
        intros H₀ _, rw H₀,
        cases pc with pc P, cases P with P₀ P₁,
        cases not_selects_and_is_control Hec P₀, } } },
  case none
  { cases ec with ec ;
    simp [program.event],
    { have Hcs : nondet.skip.coarse_sch s → nondet.skip.coarse_sch s.intl,
      { apply id },
      intros Hcs', subst s, },
    { unfold rel at Hec,
      cases Hec,
      case or.inl Hec
        { intros Hc Hstep,
          destruct (action_of ec),
          case sum.inr
            { intros ea Hea₀,
              cases ea with ea Hea₁,
              cases not_selects_and_is_control Hea₁ Hec },
          case sum.inl
            { intros ea Hea,
              simp [Hea,machine.step,machine.step._match_1] at Hstep,
              rw Hstep.left  } },
      case or.inr Hec
        { contradiction } } }
end

lemma ref_resched
: evt_ref_wk state.intl {ec // rel ec ea} mch_of (p.event ea)
      (λ (ec : {ec // rel ec ea}), mch_of.event (ec.val)) :=
{ witness := λ _, True
, resched := evt_resched
, stable  := evt_stable
, delay   := evt_delay
, sim     := evt_sim }

end ref_resched

lemma code_refs_machine
: refined state.intl p mch_of :=
{ sim_init := by { intros i, cases i, apply and.right, }
, ref := rel
, evt_sim := ref_sim
, events := ref_resched }

end

end code.semantics
