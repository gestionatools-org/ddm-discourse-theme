#!/usr/bin/env python3
"""Pure judgement of a theme install. No I/O: theme-verify gathers state, this decides.

Every check here exists because its failure is silent on the instance: a missing tag or a
dead category id empties a homepage lane with a 200 and no error, and a member-field id one
off reads a national ID onto the front page.
"""
import copy

CATEGORY_SETTINGS = ("events_category_id", "ideas_category_id", "hero_default_category_id")
TAG_SETTINGS = ("ideas_tag", "highlights_podcast_tag", "highlights_newsletter_tag", "highlights_news_tag")
FIELD_SETTINGS = ("highlights_member_entity_field_id", "highlights_member_role_field_id")
ROOMS_SETTING = "header_room_category_ids"


def setting_changes(current, wanted):
    """{name: wanted value} for every wanted setting whose current value differs.

    Compared as strings: the API returns integers for integer settings and strings for the
    rest, and an expectation file cannot tell the two apart.
    """
    return {k: v for k, v in wanted.items() if str(current.get(k)) != str(v)}


def problems(state, expect):
    theme = state.get("theme")
    if theme is None:
        return ["theme not installed"]
    out = []
    if theme["remote_url"] != expect["remote_url"]:
        out.append(f"remote_url is {theme['remote_url']!r}, expected {expect['remote_url']!r}")
    if theme["remote_compat_ref"]:
        out.append(f"following {theme['remote_compat_ref']}, not main")
    if theme["local_version"] != state["main_sha"]:
        out.append(f"local_version {theme['local_version'][:7]} is not main {state['main_sha'][:7]}")
    if theme["default"] != expect["default"]:
        out.append(f"default is {theme['default']}, expected {expect['default']}")
    settings = theme["settings"]
    for name, value in setting_changes(settings, expect["settings"]).items():
        out.append(f"setting {name} is {settings.get(name)!r}, expected {value!r}")
    for name, value in setting_changes(theme["site_settings"], expect["site_settings"]).items():
        out.append(f"theme site setting {name} is {theme['site_settings'].get(name)!r}, expected {value!r}")

    cats = state["categories"]
    for name in CATEGORY_SETTINGS:
        cid = int(settings[name])
        c = cats.get(cid)
        if c is None:
            out.append(f"{name} {cid} does not exist")
        elif c["parent"] is not None:
            out.append(f"{name} {cid} is not top level")
        elif not c["topic_count"]:
            out.append(f"{name} {cid} has no topics")
    for cid in (int(x) for x in str(settings[ROOMS_SETTING]).split("|") if x):
        c = cats.get(cid)
        if c is None or c["parent"] != expect["rooms_parent"]:
            out.append(f"{ROOMS_SETTING}: {cid} is not a room under {expect['rooms_parent']}")

    for name in TAG_SETTINGS:
        tag = settings[name]
        if not tag:
            continue
        count = state["tags"].get(tag)
        if count is None:
            out.append(f"{name} {tag!r} does not exist")
        elif count == 0:
            out.append(f"{name} {tag!r} has no topics")

    for name in FIELD_SETTINGS:
        fid = int(settings[name])
        if fid == 0:
            continue
        field = state["user_fields"].get(fid)
        wanted = expect["user_fields"][name]
        if field is None or field["name"] != wanted or not field["show_on_profile"]:
            out.append(f"{name}: field {fid} is {field!r}, expected visible {wanted!r}")
    return out


def _good():
    expect = {
        "remote_url": "https://github.com/gestionatools-org/ddm-discourse-theme.git",
        "default": False,
        "rooms_parent": 5,
        "settings": {"header_room_category_ids": "90|91|92"},
        "site_settings": {"enable_welcome_banner": "false", "search_experience": "search_icon"},
        "user_fields": {
            "highlights_member_entity_field_id": "Nombre y tipo de entidad",
            "highlights_member_role_field_id": "Cargo",
        },
    }
    state = {
        "main_sha": "a" * 40,
        "theme": {
            "id": 20, "default": False, "remote_url": expect["remote_url"],
            "remote_compat_ref": None, "local_version": "a" * 40,
            "settings": {
                "events_category_id": 59, "ideas_category_id": 18, "hero_default_category_id": 5,
                "header_room_category_ids": "90|91|92",
                "ideas_tag": "idea-registrada", "highlights_podcast_tag": "podcast",
                "highlights_newsletter_tag": "newsletter", "highlights_news_tag": "nueva-version-gestiona",
                "highlights_member_entity_field_id": 2, "highlights_member_role_field_id": 4,
            },
            "site_settings": {"enable_welcome_banner": "false", "search_experience": "search_icon"},
        },
        "categories": {
            59: {"parent": None, "topic_count": 50}, 18: {"parent": None, "topic_count": 445},
            5: {"parent": None, "topic_count": 169}, 90: {"parent": 5, "topic_count": 0},
            91: {"parent": 5, "topic_count": 0}, 92: {"parent": 5, "topic_count": 0},
        },
        "tags": {"idea-registrada": 10, "podcast": 6, "newsletter": 30, "nueva-version-gestiona": 14},
        "user_fields": {
            1: {"name": "NIF", "show_on_profile": False},
            2: {"name": "Nombre y tipo de entidad", "show_on_profile": True},
            3: {"name": "CIF Entidad", "show_on_profile": False},
            4: {"name": "Cargo", "show_on_profile": True},
        },
    }
    return state, expect


def self_test():
    state, expect = _good()
    assert problems(state, expect) == [], problems(state, expect)

    def case(label, mutate, needle):
        s, e = copy.deepcopy(state), copy.deepcopy(expect)
        mutate(s, e)
        found = problems(s, e)
        assert any(needle in p for p in found), f"{label}: {needle!r} not in {found}"

    case("not installed", lambda s, e: s.update(theme=None), "theme not installed")
    case("compat ref", lambda s, e: s["theme"].update(remote_compat_ref="d-compat/2026.10"), "following d-compat/2026.10")
    case("behind main", lambda s, e: s["theme"].update(local_version="b" * 40), "is not main")
    case("wrong remote", lambda s, e: s["theme"].update(remote_url="https://example.com/x.git"), "remote_url")
    case("default too early", lambda s, e: s["theme"].update(default=True), "default is True")
    case("rooms default", lambda s, e: s["theme"]["settings"].update(header_room_category_ids="89|90|91"), "header_room_category_ids is")
    case("room not under 5", lambda s, e: (s["theme"]["settings"].update(header_room_category_ids="89|90|91"),
                                            e["settings"].update(header_room_category_ids="89|90|91"),
                                            s["categories"].update({89: {"parent": None, "topic_count": 1}})),
         "89 is not a room under 5")
    case("site setting", lambda s, e: s["theme"]["site_settings"].update(enable_welcome_banner="true"), "enable_welcome_banner")
    case("missing category", lambda s, e: s["categories"].update({59: None}), "events_category_id 59 does not exist")
    case("nested category", lambda s, e: s["categories"].update({18: {"parent": 5, "topic_count": 445}}), "ideas_category_id 18 is not top level")
    case("empty category", lambda s, e: s["categories"].update({5: {"parent": None, "topic_count": 0}}), "hero_default_category_id 5 has no topics")
    case("missing tag", lambda s, e: s["tags"].update({"idea-registrada": None}), "ideas_tag 'idea-registrada' does not exist")
    case("empty tag", lambda s, e: s["tags"].update({"nueva-version-gestiona": 0}), "highlights_news_tag 'nueva-version-gestiona' has no topics")
    case("hidden field", lambda s, e: s["theme"]["settings"].update(highlights_member_entity_field_id=1), "field 1")
    case("wrong field name", lambda s, e: s["user_fields"].update({4: {"name": "Puesto", "show_on_profile": True}}), "field 4")

    # An emptied tag setting and a zeroed field setting are the documented "drop it" values.
    s = copy.deepcopy(state)
    s["theme"]["settings"].update(highlights_news_tag="", highlights_member_role_field_id=0)
    assert problems(s, expect) == [], problems(s, expect)
    assert setting_changes({"a": 1, "b": "x"}, {"a": "1", "b": "y", "c": "z"}) == {"b": "y", "c": "z"}
    print("self-test OK: 18 checks")


if __name__ == "__main__":
    self_test()
