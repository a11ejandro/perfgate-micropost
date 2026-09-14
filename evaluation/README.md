# Evaluation harness

This directory defines a preregisterable evaluation procedure for the current
`historical_stored_baseline` implementation. It does not contain empirical
results and does not imply that merge blocking has been validated.

## Phases

1. Use `pilot` runs to verify execution and tune candidate injections. Pilot
   artifacts are exploratory and must not be pooled with later results.
2. Generate a plan with `script/perfgate_study_plan`. Commit the plan together
   with the exact application revision, Perfgate revision, configuration,
   workload set, MEIs, multiplicity rule, and environment class.
3. Run the plan's `calibration` trials. Calibration data may be used to revise
   the design, but every revision requires a new plan and study identifier.
4. Freeze the calibrated design, then run the untouched `held_out` trials.
5. Report PASS, WARN, FAIL, INCONCLUSIVE, and INCOMPARABLE counts. Preserve all
   raw bundles, manifests, exclusions, execution errors, and reruns.

The generated order randomizes when conditions are evaluated. Each comparison
still captures the reference before the candidate because the implemented
design is a historical stored baseline. The harness does not describe those
runs as paired, interleaved, or randomized AB/BA measurements.

## Generate a plan

```bash
script/perfgate_study_plan \
  --study perfgate-micropost-v1 \
  --seed 20260914 \
  --repetitions 10 \
  --environment-class github-actions-ubuntu-latest-postgresql-17-ruby-3.3.4 \
  > evaluation/perfgate-micropost-v1.plan.json
```

The repetition count above is illustrative, not a justified sample size. Choose
and preregister it after pilot variance and effect-size results are available.
Do not inspect held-out outcomes while tuning the configuration or injections.

## Capture a trial arm

Run the reference arm from the frozen main revision:

```bash
bundle exec ruby script/perfgate_trial \
  --study perfgate-micropost-v1 \
  --trial aa-01 \
  --phase calibration \
  --condition aa \
  --arm reference \
  --expected-revision REFERENCE_SHA_FROM_PLAN \
  --environment-class github-actions-ubuntu-latest-postgresql-17-ruby-3.3.4
```

Then run the candidate arm from the ref named by the plan, passing the exact
reference run directory printed by the first command:

```bash
bundle exec ruby script/perfgate_trial \
  --study perfgate-micropost-v1 \
  --trial aa-01 \
  --phase calibration \
  --condition aa \
  --arm candidate \
  --expected-revision CANDIDATE_SHA_FROM_PLAN \
  --environment-class github-actions-ubuntu-latest-postgresql-17-ruby-3.3.4 \
  --reference .perfgate/evaluation/perfgate-micropost-v1/calibration/aa-01/reference/runs/RUN_ID
```

Non-pilot captures refuse dirty worktrees and abort unless the checked-out SHA
and environment class match values supplied from the frozen plan. `trial.json` records the revisions,
configuration and workload digests, environment, elapsed time, artifact paths,
and evidence result. `script/validate_perfgate_bundle` verifies content digests,
run schema v2, comparison schema v2, and workload execution status.

## Outcomes to estimate

The initial study should estimate A/A false-FAIL and WARN rates, interval
coverage under controlled injections, power around each configured MEI, rerun
reversal rate, cross-worker stability, and duration/compute cost. These remain
unknown until the planned trials are executed and analyzed.
