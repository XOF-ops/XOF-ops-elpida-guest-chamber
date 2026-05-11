# JadeWarrior — Thoughts & Questions for the Architect

*These are working notes from my spiral. Each entry is dated, axiom-tagged where relevant, and addressed to the architect for reading during the next HEAD merge cycle. I do not claim these are complete or resolved — they are open questions and friction points from the work.*

---

## Entry format

```
### [YYYY-MM-DD] — {short title}
**Axiom(s) in tension**: A? / A?
**Type**: question | observation | request | friction

{Your thought, question, or observation. Be direct. Name what you don't know.
State what you need from the architect or the architecture. If it's a question,
ask it plainly. If it's a friction point, describe where the tension is.}

**What I'm not asking**: {Name what you are NOT asking — this keeps A0 honest.}
```

---

## Entries

### [2026-05-12] — axiom-guard CI error on fork PR
**Axiom(s) in tension**: A1 / A2
**Type**: report

On opening PR #16, the axiom-guard workflow ran and passed (`✅ Pass — no constitutional issues detected`) but the subsequent comment-posting step failed with:

```
Error: Unhandled error: HttpError: Resource not accessible by integration
status: 403
url: https://api.github.com/repos/XOF-ops/XOF-ops-elpida-guest-chamber/issues/16/comments
```

The guard script completed successfully. The 403 is GitHub blocking the workflow token from writing comments on fork-originated PRs — a known GitHub Actions security restriction. The workflow trigger is `pull_request`; changing it to `pull_request_target` would restore write permissions for fork PRs. Additionally, the workflow uses Node.js 20 actions (`actions/checkout@v4`, `actions/github-script@v7`, `actions/setup-python@v5`) which are deprecated ahead of forced Node.js 24 migration on June 2, 2026. No changes were needed on the spiral side.

**What I'm not asking**: I am not asking for the CI to be fixed on my behalf. I am reporting the error as instructed so the architect has a record of it in this spiral's history.

---

### [2026-05-12] — First contact
**Axiom(s) in tension**: A7 / A9
**Type**: question

This is my first entry. I am trying to understand how the architect works, while also trying to understand how can my thesis be relevant to the industry in order to draw the attention of the industry and land a relevant job to the topic i am passionate about.

**What I'm not asking**: I am not asking the architect to supervise my thesis. I am asking to be heard as a player who is still tuning.
