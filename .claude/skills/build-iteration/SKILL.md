---
name: build-iteration
description: Create the next Iteration's exercise and solution projects for the saas-handson curriculum. Designs from docs/ROADMAP.md's feature list, verifies with build/test, updates the matching haskell-reference chapter, and finishes with a sanitize-artifacts pass.
---

# build-iteration

Builds one Iteration of the saas-handson curriculum as a pair of independent cabal packages under `iterations/iteration-N/{exercise,solution}/`. Iteration 0 (`iterations/iteration-0/`) is the first applicant of this pattern; every later Iteration must match the design principles, directory layout, and verification procedure established there.

## When to use

Use this when asked to create the exercise and solution projects for the next Iteration of this curriculum (e.g. "build Iteration 1", "hands-on-ify Iteration 2").

## Scope

- Always covers exactly **one** Iteration per invocation. Do not build multiple Iterations in one pass.
- The target Iteration number N is the next one after the last completed Iteration.
- Deleting the old cumulative `saas-handson` / `saas-handson-solution` packages and the final cleanup of the root `README.md` / `cabal.project` once every Iteration is done is **out of scope**. That happens as a separate, manual step after the whole curriculum is migrated.

## Sources of truth

- What to implement in each Iteration, and why, comes only from the corresponding section of `docs/ROADMAP.md` ("実装する機能" / "含むリファクタリング" / "目的").
- Do not copy prose, comments, or test code from the old cumulative `saas-handson` / `saas-handson-solution` packages or their `docs/iteration-N.md`. That old structure was written before Iterations were split apart, so its TODO comments and type signatures already assume later Iterations' shapes — carrying that over would reintroduce the exact "later Iteration leaked into this one" problem that Iteration 0 was rebuilt to fix. Write the exercise instructions, solution explanations, and test code fresh, using only the ROADMAP.md feature list as the spec.
- The **implementation code of the previous Iteration's solution package** (`iterations/iteration-(N-1)/solution/src`, `app`, etc.) is the one thing that should be carried forward as-is — it is the working baseline the learner builds on, not something to rewrite. What gets newly authored is only the increment (new feature or refactor) that ROADMAP.md describes for this Iteration.

## Design principles (established while building Iteration 0)

1. **Each Iteration project is a complete, working snapshot of everything that should exist by that Iteration.** Whatever a previous Iteration introduced is handed over as finished code; only the new part introduced by this Iteration is TODO/exercise material.
2. **Never leak a later Iteration's shape into an earlier one.** Type signatures, function arguments, and module structure must not anticipate a later Iteration's design (e.g. taking a `Logger` or `Repository` argument before that Iteration exists). Comments should only describe what exists as of this Iteration; a brief forward-looking sentence ("a later Iteration will add...") is fine, but signatures and implementations themselves must not pre-adopt it.
3. **Tests are exercise material too.** The exercise package's `test/unit/Spec.hs` and `test/integration/Spec.hs` contain only the hspec-discover driver line (`{-# OPTIONS_GHC -F -pgmF hspec-discover #-}`) — no `*Spec.hs` files, and no `other-modules` entries pointing at files that don't exist yet. `docs/iteration-N.md` (exercise) must include a step that tells the learner concretely what to test (expected status codes, response bodies, edge cases) before they write it themselves. The solution package ships complete, passing implementation and tests.
4. **Write positively, never defensively.** Never write things like "this project doesn't depend on...", "...doesn't appear here", or "this project is self-contained and depends on nothing else" — these read as excuses justifying how the material was carved out, not as content the reader needs. State only what this Iteration builds, in positive terms. If the curriculum's overall arc needs mentioning, phrase it forward-looking ("this curriculum expands into X, Y, Z as Iterations progress"), never as an absence.

## Package names and directory layout

- Directories: `iterations/iteration-N/exercise/`, `iterations/iteration-N/solution/`
- Cabal package names: `saas-handson-iterationN`, `saas-handson-solution-iterationN` (**do not put a hyphen before the bare digit** — `saas-handson-iteration-1` fails to parse because cabal rejects an all-numeric hyphen-separated name component; `saas-handson-iteration1` is required. The directory name keeps the hyphen, e.g. `iteration-1`.)
- Name the `.cabal` file after the package (e.g. `saas-handson-iteration1.cabal`).

## Procedure

1. Read the Iteration N section of `docs/ROADMAP.md` for the feature and goal, and the Iteration N-1 section for context on where the previous Iteration left off.
2. Read `iterations/iteration-(N-1)/solution/` to see what code is being carried forward.
3. Read `iterations/iteration-0/` (both exercise and solution) as the reference for directory layout, `.cabal` conventions, the `docs/iteration-N.md` exercise numbering pattern (N-1, N-2, ... walking through: read/understand, confirm Red by writing your own tests, implement to Green, compare unit vs. integration tests, then an extension exercise), and README structure.
4. Create, from scratch:
   - `iterations/iteration-N/exercise/`: the previous Iteration's finished code as the baseline, with only the new feature/refactor that ROADMAP.md describes for this Iteration left as TODO in src/app. Tests are hspec-discover driver stubs only. Write `docs/iteration-N.md` (exercise) and `README.md` fresh.
   - `iterations/iteration-N/solution/`: the same new feature fully implemented, with newly written tests, all passing. Write `docs/iteration-N.md` (solution/explanation) and `README.md` fresh.
5. Add both new package paths to the root `cabal.project`'s `packages` list.
6. Run `cabal build` and confirm both packages compile. Remember `{-# LANGUAGE OverloadedStrings #-}` on any module that builds a `Text`-based record from a string literal.
7. Run `cabal test` on the solution package and confirm every test is GREEN.
8. Verify the exercise package's TDD cycle actually works: temporarily copy the solution's new spec file(s) into the exercise's `test/unit` and `test/integration`, temporarily add the matching `other-modules` entries to its `.cabal`, run `cabal test`, and confirm it goes RED for the expected reason (the TODO's `error`). Then **fully restore the exercise package to its shipped state** — delete the copied spec files and revert the `.cabal` file — before moving on. Never leave verification leftovers in the shipped exercise package.
9. Re-run `cabal test` on the restored exercise package and confirm it is back to the intended starting state (0 examples, or only the parts a learner would already have working).
10. Create or revise the matching chapter in `docs/haskell-reference/`. The numbering is offset by one from the Iteration number (`00-basics.md`, then `01-iteration-0.md`, `02-iteration-1.md`, ... so Iteration N's chapter is `0(N+1)-iteration-N.md`); update the table of contents in `docs/haskell-reference.md` if the chapter is new. Whether creating or revising, hold it to the same bar as `00-basics.md` and `01-iteration-0.md`: concrete, factual explanations grounded in actual type signatures and behavior — no hedging or metaphor dressed up as explanation (e.g. wrapping a vague word like "context" in quotes as a stand-in for a real definition, or reaching for an unrelated-language analogy instead of stating the type and its behavior directly).
11. Run a `/sanitize-artifacts` pass over everything newly written or changed in this Iteration (both projects' `README.md`, `docs/iteration-N.md`, source comments, and the haskell-reference chapter). Check especially for the defensive phrasing covered in design principle 4, and for any other trace of the conversation or production process.

## Troubleshooting

- Right after editing a `.cabal` file, `cabal test <package-name>` (with no component qualifier) can fail with `Ambiguous target ... exe:X (component) / lib:X (component)`. This is not a problem with the file — it's a stale `dist-newstyle` build-plan cache. Run `cabal clean`, then rebuild and retest.
