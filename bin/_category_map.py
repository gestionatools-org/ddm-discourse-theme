"""Pure helpers for the category target map. No I/O: the applier and the verifier both
import this, so the question "does this category match the map?" has one answer."""
import datetime

FIELDS = ("name", "slug", "color", "text_color", "default_list_filter", "topic_template")
CASE_INSENSITIVE = ("color", "text_color")


def resolve(ref, rooms, created):
    """A map reference to a category id: 85, "85", "room:<key>", "created:<key>"."""
    if isinstance(ref, int):
        return ref
    ref = str(ref)
    if ref.startswith("room:"):
        return rooms[ref[len("room:"):]]
    if ref.startswith("created:"):
        return created[ref[len("created:"):]]
    return int(ref)


def perms_of(category):
    """Extract group permissions from a category record as {group_name: permission_type}."""
    return {g["group_name"]: g["permission_type"] for g in (category.get("group_permissions") or [])}


def plan_changes(current, entry):
    """What `entry` still needs on `current`. `entry["parent"]` must already be an id or None.

    `add_permissions` adds groups at a level but never lowers or removes a row a group
    already holds; `permissions` replaces every row. Returns (fields to send, and the full
    permission rows to send or None to leave them unchanged).
    """
    changes = {}
    for field in FIELDS:
        if field not in entry:
            continue
        have, want = current.get(field) or "", entry[field] or ""
        if field in CASE_INSENSITIVE:
            have, want = have.lower(), want.lower()
        if have != want:
            changes[field] = entry[field]
    if "parent" in entry and current.get("parent_category_id") != entry["parent"]:
        changes["parent_category_id"] = "" if entry["parent"] is None else entry["parent"]
    have = perms_of(current)
    if "permissions" in entry:
        want = dict(entry["permissions"])
    elif "add_permissions" in entry:
        want = dict(have)
        for group, level in entry["add_permissions"].items():
            want.setdefault(group, level)
    else:
        want = have
    return changes, (None if want == have else want)


def not_yet(iso):
    """Check if a timestamp has not yet arrived."""
    if not iso:
        return False
    when = datetime.datetime.fromisoformat(iso.replace("Z", "+00:00"))
    return datetime.datetime.now(datetime.timezone.utc) < when


def self_test():
    """Validate all functions against their contract."""
    bad = []

    def expect(label, got, want):
        if got != want:
            bad.append(f"{label}: got {got!r}, expected {want!r}")

    rooms, created = {"analitica": 91}, {"developers_85": 95}
    expect("resolve int", resolve(85, rooms, created), 85)
    expect("resolve str", resolve("85", rooms, created), 85)
    expect("resolve room", resolve("room:analitica", rooms, created), 91)
    expect("resolve created", resolve("created:developers_85", rooms, created), 95)

    base = {"name": "Te contamos...", "slug": "te-contamos", "color": "12A89D",
            "text_color": "FFFFFF", "topic_template": None, "parent_category_id": None,
            "group_permissions": [{"group_name": "todos", "permission_type": 1}]}
    expect("rename", plan_changes(base, {"name": "Noticias", "slug": "noticias"}),
           ({"name": "Noticias", "slug": "noticias"}, None))
    expect("already there", plan_changes(base, {"name": "Te contamos..."}), ({}, None))
    expect("colour case", plan_changes(base, {"color": "12a89d"}), ({}, None))
    expect("template None vs empty", plan_changes(base, {"topic_template": ""}), ({}, None))
    child = {**base, "parent_category_id": 5}
    expect("promote", plan_changes(child, {"parent": None}), ({"parent_category_id": ""}, None))
    expect("reparent", plan_changes(base, {"parent": 5}), ({"parent_category_id": 5}, None))
    two = {**base, "group_permissions": [{"group_name": "Certificación", "permission_type": 1},
                                         {"group_name": "Analiza", "permission_type": 1}]}
    expect("add never lowers", plan_changes(two, {"add_permissions": {"Analiza": 3, "Developers": 3}}),
           ({}, {"Certificación": 1, "Analiza": 1, "Developers": 3}))
    expect("add already present", plan_changes(two, {"add_permissions": {"Analiza": 3}}), ({}, None))
    expect("replace", plan_changes(two, {"permissions": {"moderadores": 1}}), ({}, {"moderadores": 1}))
    expect("replace equal", plan_changes(two, {"permissions": {"Analiza": 1, "Certificación": 1}}), ({}, None))
    expect("past date", not_yet("2020-01-01T00:00:00Z"), False)
    expect("future date", not_yet("2999-01-01T00:00:00Z"), True)
    expect("no date", not_yet(None), False)
    return bad


if __name__ == "__main__":
    failures = self_test()
    print("\n".join(failures) if failures else "self-test OK")
    raise SystemExit(1 if failures else 0)
