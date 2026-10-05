### `commits_behind: 0` is not proof of currency

Same family of failure, met again on 2026-08-27 and worth its own note because the reassuring
number is the one that lies. **A remote theme does not pull when a PR merges.** It pulls when
Discourse next checks, and `commits_behind` reports the result of *that* check — whose time is
in `updated_at`, right beside it.

PRE sat on `149fab6` for two hours reporting `commits_behind: 0`, because its last check ran at
10:46 and the commit that mattered merged at 11:20. In between, a tag was renamed on the
instance and the theme kept filtering the homepage's showcase lane by the old name: **zero
results, no error, an empty lane, and a theme record that said everything was up to date.**

So read `updated_at` alongside `commits_behind`, and force the pull rather than trusting the
number:

```bash
curl -s -X PUT -H "Api-Key: $KEY" -H "Api-Username: $USER" \
  -H "Content-Type: application/json" -d '{"theme":{"remote_update":true}}' \
  "$URL/admin/themes/<id>.json"
```

`POST /admin/themes/<id>/update.json` is a 404 — that route does not exist.

**And a setting written straight onto the instance becomes an override.** Fixing the lane by
`PUT /admin/themes/<id>/setting.json` works instantly and outlives the theme update, but if a
later release changes that setting's default and the instance does not follow, this is why.

