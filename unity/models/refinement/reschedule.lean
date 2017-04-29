
import unity.models.nondet
import unity.refinement

import util.cast

universe variable u

namespace nondet
open predicate
open unity

variables {α : Type}

structure evt_ref (mc : @prog α) (ea ec : @event α) : Prop :=
  (sim : ⟦ ec.step_of ⟧ ⟹ ⟦ ea.step_of ⟧)
  (delay : ea.coarse_sch && ea.fine_sch ↦ ec.coarse_sch in mc)
  (stable : unless mc ec.coarse_sch (-ea.coarse_sch))
  (resched : ea.coarse_sch && ea.fine_sch ↦ ec.fine_sch in mc)

open temporal

structure refined (ma mc : @prog α) : Prop :=
  (bij : mc.lbl = ma.lbl)
  (sim_init : mc^.first ⟹ ma^.first)
  (sim' : ∀ e, ⟦ mc.step_of e ⟧ ⟹ action (ma.step_of (e.cast bij) ))
  (delay : ∀ e, ma^.coarse_sch_of e && ma^.fine_sch_of e ↦ mc^.coarse_sch_of (e.cast' bij) in mc)
  (stable : ∀ e, unless mc (mc^.coarse_sch_of e) (-ma^.coarse_sch_of (e.cast bij)))
  (resched : ∀ e, ma^.coarse_sch_of e && ma^.fine_sch_of e ↦ mc^.fine_sch_of (e.cast' bij) in mc)

lemma refined.sim {m₀ m₁ : @prog α} (R : refined m₀ m₁)
: ⟦ is_step m₁ ⟧ ⟹ ⟦ is_step m₀ ⟧ :=
begin
  simp [is_step_exists_event,R.bij],
  apply p_or_entails_p_or_right,
  apply p_exists_entails_p_exists' _ _ (λ l, cast R.bij l), intros e τ H,
  simp,
  assert H'' : option.cast (some e) (R.bij) = some (cast (R.bij) e),
  { generalize R.bij P, intro P,
    rw cast_some },
  note H' := R.sim' (some e) τ H,
  rw H'' at H',
  apply H',
end

lemma event_refinement {ma mc : @prog α}
   (BIJ : mc.lbl = ma.lbl)
   (INIT : mc^.first ⟹ ma^.first)
   (EVT : ∀ e, evt_ref mc (ma.event' e) (mc.event' $ cast BIJ.symm e))
: refined ma mc :=
begin
  apply refined.mk BIJ,
  { apply INIT },
  { intro e,
    cases e with e,
    { simp [cast_none,step_of_none],
      intro, apply id },
    { unfold prog.step_of prog.event,
      simp [cast_some],
      note H := (EVT $ cast BIJ e).sim,
      simp [cast_cast] at H,
      apply H } },
  all_goals
    { intro e,
      cases e with e,
      simp [ prog.coarse_sch_of_none,prog.fine_sch_of_none,cast_none'],
      try { apply True_leads_to_True },
      try { apply True_unless } },
  { simp [cast_some'],
    apply (EVT e).delay },
  { simp [cast_some],
    note H := (EVT $ cast BIJ e).stable,
    simp [cast_cast] at H,
    apply H },
  { simp [cast_some'],
    apply (EVT e).resched },
end

variables  (ma mc : @prog α)

open temporal

theorem soundness : refined ma mc → unity.refinement.refined ma mc :=
begin
  intros R τ M₁,
  apply nondet.prog.ex.mk,
  { apply R.sim_init,
    apply M₁.init },
  { intro i,
    apply R.sim,
    apply M₁.safety },
  { intros e COARSE₀ FINE₀,
    pose e' := e.cast' R.bij,
    assert CF_SCH : ([]<>•(prog.coarse_sch_of ma e && prog.fine_sch_of ma e)) τ,
    { apply coincidence,
      apply COARSE₀,
      apply FINE₀, },
    assert COARSE₁ : (<>[]•prog.coarse_sch_of mc e') τ,
    { assert COARSE₂ : ([]<>•prog.coarse_sch_of mc e') τ,
      { apply inf_often_of_leads_to (system_sem.leads_to_sem (R.delay e) _ M₁),
        apply CF_SCH },
      note UNLESS := unless_sem_str _ M₁.safety (R.stable e') COARSE₂,
      cases UNLESS with UNLESS H,
      { apply UNLESS },
      { assert H' : (-<>[]•prog.coarse_sch_of ma e) τ,
        { rw [not_eventually,not_henceforth,not_init],
          simp [option_cast_cast'] at H,
          apply H },
        cases H' COARSE₀, } },
    assert FINE₁ : ([]<>•prog.fine_sch_of mc e') τ,
    { apply inf_often_of_leads_to (system_sem.leads_to_sem (R.resched _) _ M₁),
      apply CF_SCH, },
    apply henceforth_entails_henceforth _ _ (M₁.liveness _ COARSE₁ FINE₁),
    apply eventually_entails_eventually,
    note H := R.sim' e',
    simp [option_cast_cast'] at H,
    apply H, },
end

end nondet