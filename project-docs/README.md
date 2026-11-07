# Project documentation

Developer notes and historical audits for this repository. The published site remains in the docs directory.

## Audits

- [audit823.md](audits/audit823.md): Simple GLP audit823
- [ios27SimpleGLP.md](audits/ios27SimpleGLP.md): iOS 27 compatibility audit: Simple GLP
- [state-machines-2026-11-06.md](audits/state-machines-2026-11-06.md): state machine audit: 10 bugs (7 proved by test), 9 product calls, repro suite alongside.
- [state-machines-2026-11-06-review.md](audits/state-machines-2026-11-06-review.md): independent review of that audit: 1 confirmed, 8 confirmed-minor, 0 rejected, 1 unverified; re-ranked.
- [state-machines-2026-11-06-fixes.md](audits/state-machines-2026-11-06-fixes.md): fixes for the reviewed claims: 10 fixed, 0 skipped, 3 decisions held for Jack; full suite 143 passed, S10 proved by a UI test.
- [state-machines-2026-11-06-verify.md](audits/state-machines-2026-11-06-verify.md): independent check of those fixes: FAIL, 9 of 10 work, the S1 change drops a daily pill's next reminder after some time zone changes; full suite 143 passed.

## Marketing

- [aso-plan.md](marketing/aso-plan.md): aso-plan.md: Simple GLP ASO Plan

## ASO

- [2026-10-28-aso-pass.md](aso/2026-10-28-aso-pass.md): evidence and metadata changes for the October 2026 ASO pass.

## Android

- [Android](android/README.md): port implementation and verification.
