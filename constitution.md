# Project Constitution

This document defines the non-negotiables for this project. Unlike `specs/`
(which describes *what* we're building) or `CLAUDE.md` (which describes how
the operator works), this file captures the principles that govern *how this
particular project* must be built.

Populated during the Claude.ai ideation phase. Do not edit mid-project
without deliberate thought — changes here ripple through every decision
downstream.

---

## Purpose

_One paragraph: what problem does this project solve, and for whom?_

## Non-Negotiables

_What must be true no matter what. Examples:_
- _Every user-facing string must be translatable (i18n from day one)._
- _No third-party analytics. Privacy-first._
- _Offline-first; network is a progressive enhancement._

## Testing Philosophy

_Examples:_
- _TDD for business logic, integration tests for API boundaries, E2E for
  critical user paths only._
- _Coverage target: 80% for business logic, no target for glue code._

## Out of Scope

_What this project is explicitly NOT. Prevents scope creep during iteration._

## Success Criteria

_How we'll know the project is "done enough" to ship a v1. Written as
testable statements where possible._
