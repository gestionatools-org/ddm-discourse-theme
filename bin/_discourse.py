"""Minimal Discourse API client for the category work. Stdlib only, like bin/tags-verify."""
import json
import os
import re
import time
import urllib.error
import urllib.parse
import urllib.request

PAUSE = 1.3  # PRE rate-limits at roughly 1 req/s

# The environment is read at call time, not at import. Importing this module must stay
# free of credentials so a caller's pure-function self-test can run without .env.local —
# which is exactly what a rule test should need.


def _url():
    return os.environ["PRE_DISCOURSE_URL"].rstrip("/")


def _user():
    return os.environ["PRE_DISCOURSE_API_USERNAME"]


def _key(elevated):
    """Ask for the key the call needs, so an ordinary read never carries a write-capable
    credential.

    `elevated` is not the same as "writes". Every write needs the Global key, but so do
    several *reads*: /c/<id>/show.json, /tags.json and /tag_groups.json all answer 403
    with the granular read-only key, which is why this flag is named after the key it
    picks rather than after the HTTP verb. Never log either value.
    """
    return os.environ["PRE_DISCOURSE_GLOBAL_API_KEY" if elevated else "PRE_DISCOURSE_API_KEY"]


def request(method, path, data=None, elevated=False, retries=4, allow_404=False):
    """One API call. `data` is a list of (key, value) pairs, form-encoded.

    Rails wants repeated keys for arrays (`topic_ids[]`) and bracketed keys for nested
    hashes (`operation[type]`), which a plain dict cannot express — hence the pair list.
    """
    headers = {"Api-Key": _key(elevated), "Api-Username": _user(), "Accept": "application/json"}
    body = None
    if data is not None:
        body = urllib.parse.urlencode(data).encode()
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    # Percent-encode the path, because group names on this instance carry accents and
    # urllib raises UnicodeEncodeError on a non-ASCII request line rather than encoding it
    # — `/groups/Certificación.json` died that way. `%` is safe, so a caller that already
    # encoded its path is not double-encoded.
    url = _url() + urllib.parse.quote(path, safe="/?=&%[]")
    for attempt in range(retries):
        req = urllib.request.Request(url, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req) as response:
                payload = response.read()
            time.sleep(PAUSE)
            return json.loads(payload or b"{}")
        except urllib.error.HTTPError as exc:
            if exc.code == 429 and attempt < retries - 1:
                time.sleep(PAUSE * 2 ** (attempt + 1))
                continue
            if exc.code == 404 and allow_404:
                # A verifier must be able to ask "does this exist?" and record the answer
                # as a failure. Raising SystemExit here would kill the run instead.
                time.sleep(PAUSE)
                return None
            detail = exc.read()[:300].decode("utf-8", "replace")
            raise SystemExit(f"{method} {path} -> HTTP {exc.code}: {detail}")


def get(path, elevated=False):
    return request("GET", path, elevated=elevated)


def group(name):
    """The group record, or None if it does not exist. Needs the Global key."""
    found = request("GET", f"/groups/{name}.json", elevated=True, allow_404=True)
    return (found or {}).get("group")


def group_members(name):
    """Every member of a group, paged. Returns {user_id: username}.

    Needs the Global key. Usernames are member data: count them, never commit them —
    `docs/.../*-prior-state.json` is gitignored for the same reason.
    """
    out = {}
    offset = 0
    while True:
        data = get(f"/groups/{name}/members.json?limit=100&offset={offset}", elevated=True)
        batch = data.get("members") or []
        if not batch:
            return out
        out.update({m["id"]: m["username"] for m in batch})
        offset += len(batch)
        if offset >= (data.get("meta") or {}).get("total", offset):
            return out


def category(cid):
    """`/c/<id>/show.json` is the working shape; the slug form genuinely errors.

    It needs the Global key: the granular read-only key answers 403 here, which is why
    category permissions were long believed to be readable only in admin.
    """
    return get(f"/c/{cid}/show.json", elevated=True)["category"]


def definition_topic_id(cid):
    """The category's own "Acerca de la categoría …" topic.

    It is NOT in `topic_count` but it IS in the listing, so any rule derived from a crawl
    will propose it like an ordinary topic — and a bulk move takes it along, leaving the
    category describing itself from somewhere else. Measured 2026-09-11: topics 3, 16 and
    33 for categories 4, 5 and 18.

    The id is only exposed as the tail of `topic_url`; `/categories.json` does not carry
    it at all.
    """
    match = re.search(r"/(\d+)$", category(cid).get("topic_url") or "")
    return int(match.group(1)) if match else None


def tag_names(topic):
    """Tags arrive as strings on older serializers and as objects on newer ones."""
    return [t["name"] if isinstance(t, dict) else t for t in (topic.get("tags") or [])]


def _original_author(topic, users):
    """The poster flagged as author. Discourse localises the description, so match on the
    substring both locales share: 'Autor original' (es) and 'Original Poster' (en).
    """
    for poster in topic.get("posters") or []:
        if "original" in (poster.get("description") or "").lower():
            return users.get(poster["user_id"])
    return None


def crawl_category(cid, max_pages=40):
    """Every topic whose own category is `cid`, across all listing pages.

    A category's listing carries its children's topics too, so filter on category_id
    before counting anything. The listing 301-redirects; urllib follows that for GET.
    """
    out = {}
    for page in range(max_pages):
        data = get(f"/c/{cid}/l/latest.json?page={page}")
        topics = data["topic_list"]["topics"]
        if not topics:
            break
        users = {u["id"]: u["username"] for u in data.get("users", [])}
        for topic in topics:
            if topic["category_id"] != cid or topic["id"] in out:
                continue
            topic["_author"] = _original_author(topic, users)
            out[topic["id"]] = topic
    return out
