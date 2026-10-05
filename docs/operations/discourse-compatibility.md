### Why this repo no longer cuts compatibility branches

`d-compat-branch.yml` was deleted on 2026-08-26 after it froze PRE for nine hours. The whole
episode is worth keeping, because the failure is silent and the reasoning is not obvious.

**What the workflow did.** It cut `d-compat/<core-version>` from a fixed base and never
advanced it — the shared workflow's own source says `Branch #{branch} already exists on
origin. Skipping.`, so every later run is a no-op. The 01:08 UTC run on 2026-08-26 logged
`Cutting d-compat/2026.8 from 760df745 (2026-08-25T10:52:10Z)`, the first compat branch this
repo ever had, and `main` was already a commit past that base. **The branch was born behind
and stayed there.**

**How an instance gets captured.** The theme has no branch pinned — `branch: None` on the
`remote_theme` record. Discourse looks for a `d-compat/<its own core version>` branch on the
remote and prefers it over the default branch, recording the result in `remote_compat_ref`.
PRE reported `remote_compat_ref: d-compat/2026.8`, `commits_behind: 0`, `theme_version
0.17.0` — perfectly up to date with a branch nobody chose.

**The version it matches is the *current* one, not an older one.** Discourse's latest tag was
`v2026.8.0` and PRE ran `2026.8.0-latest.1`. So there is no core upgrade that escapes the
branch: it captures every instance, including one that is fully current. An earlier draft of
this note claimed the opposite and it was wrong.

**Why deletion rather than management.** This theme serves instances that track latest core,
and `minimum_discourse_version` in `about.json` already states what it needs. A compat branch
therefore protects nothing here and costs the one thing that matters on a development target:
seeing merged work. Deleting the branch alone would not have held — the nightly run recreates
it, since the condition is "already exists", not "ever existed" — so the workflow had to go
with it.

**What is given up.** If an instance ever has to sit on an older core, the mechanism for that
is `.discourse-compatibility`, which maps core versions to theme commits and is currently
empty (comments only). That is the deliberate, explicit tool; the branch was the implicit one
that fired on its own.

**The symptom, so it is recognisable.** A feature demonstrably on `main` and demonstrably
absent from the site, with no error anywhere. A whole homepage lane failed to appear this way,
and the missing icon it was hunted through was a red herring — neither the lane nor its
`svg_icons` entry existed in the compiled theme. Before concluding anything about what an
instance runs, read its `remote_theme` record:

```bash
curl -s -H "Api-Key: $KEY" -H "Api-Username: $USER" "$URL/admin/themes/<id>.json" |
  python3 -c "import json,sys; rt=json.load(sys.stdin)['theme']['remote_theme']; \
    print({k: rt[k] for k in ['branch','remote_compat_ref','local_version','commits_behind']})"
```

`remote_compat_ref` being non-null means the instance is not following `main`, whatever the
admin page says.

