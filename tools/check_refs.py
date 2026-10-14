#!/usr/bin/env python3
"""Static reference check for PixelLegends — runs without Godot, gates every commit.

gdlint only sees one file at a time, so it cannot tell you that a screen calls
`UiKit.card_title()` when the only method is `card()`. This script is the
cheap compiler we can run in CI (and inside a sandbox with no Godot binary):

  * every `class_name` is unique and every `extends` target exists
  * every autoload declared in project.godot points at a real script
  * every `Class.member` access on one of *our* classes resolves to a method,
    constant, variable or signal that actually exists (walking base classes)
  * every enum member access (`GameTypes.Region.ASIA`) resolves
  * every `res://` path written in code or in a `.tscn` exists on disk
  * every `Loc.t(&"literal.key")` has a row in *every* locale table
  * every `.tscn` is structurally sane (ext_resource paths, node headings)

Exit code is non-zero if anything fails, so it can be used as a pre-commit or
CI gate. `--verbose` prints the full index it built.

Usage:
    python3 tools/check_refs.py
    python3 tools/check_refs.py --verbose
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "src"

CLASS_RE = re.compile(r"^class_name\s+([A-Za-z_]\w*)")
EXTENDS_RE = re.compile(r"^extends\s+([A-Za-z_][\w.]*)")
FUNC_RE = re.compile(r"^\s*(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(")
VAR_RE = re.compile(r"^(?:@\w+(?:\([^)]*\))?\s+)*var\s+([A-Za-z_]\w*)")
CONST_RE = re.compile(r"^const\s+([A-Za-z_]\w*)")
SIGNAL_RE = re.compile(r"^signal\s+([A-Za-z_]\w*)")
ENUM_RE = re.compile(r"^enum\s+([A-Za-z_]\w*)")
ENUM_BLOCK_RE = re.compile(r"^enum\s+([A-Za-z_]\w*)?\s*\{")

# `Foo.bar` / `Foo.EnumValue.member` where Foo is capitalised: our namespace,
# never a Godot built-in class (those are not in the index and get skipped).
MEMBER_RE = re.compile(r"(?<![\w.\"'])([A-Z]\w*)\s*\.\s*([A-Za-z_]\w*)")
CHAIN_RE = re.compile(r"\b([A-Z]\w*)\s*\.\s*([A-Z]\w*)\s*\.\s*([A-Za-z_]\w*)")
RES_PATH_RE = re.compile(r'"(res://[^"]+)"')
LOC_KEY_RE = re.compile(r'Loc\.\w+\(\s*&?"([A-Za-z0-9_.]+)"')
TSCN_EXT_RE = re.compile(r'^\[ext_resource[^\]]*path="(res://[^"]+)"')
TSCN_NODE_RE = re.compile(r'^\[node\s+name="([^"]+)"\s+type="([^"]+)"')
AUTOLOAD_RE = re.compile(r'^([A-Z]\w*)="\*?(res://[^"]+)"')
THEME_VARIATION_RE = re.compile(r'set_type_variation\(\s*&?"([^"]+)"')
THEME_USE_RE = re.compile(r'theme_type_variation\s*=\s*&"([^"]+)"')
STRINGNAME_LITERAL_RE = re.compile(r'&"([^"]+)"')
TEXT_VARIATION_RE = re.compile(r'UiKit\.(?:label|display|heading|subheading|muted|caption|micro|paragraph)'
                               r'\([^)]*?&"([A-Za-z]\w*)"')
PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}")
LOC_CALL_RE = re.compile(r'Loc\.t\(\s*&?"([^"]+)"\s*(?:,\s*\{([^}]*)\})?\s*\)')

# Godot classes we do not try to validate; if a name is not in our own index we
# simply skip it, so this list only matters for names that shadow a built-in.
GODOT_TYPES = {
    "Node", "Node2D", "Node3D", "Control", "RefCounted", "Resource", "Object",
    "CanvasItem", "NodePath", "Vector2", "Vector2i", "Vector3", "Color",
    "Dictionary", "Array", "String", "StringName", "PackedByteArray",
    "PackedStringArray", "PackedVector2Array", "PackedInt32Array", "Time",
    "Engine", "OS", "Input", "InputMap", "DisplayServer", "ProjectSettings",
    "TranslationServer", "DirAccess", "FileAccess", "JSON", "HTTPRequest",
    "HTTPClient", "TCPServer", "PacketPeerUDP", "ENetMultiplayerPeer",
    "MultiplayerAPI", "SceneTree", "Timer", "Tween", "ClassDB", "AudioServer",
    "AudioStreamWAV", "AudioStreamPlaybackPolyphonic", "AudioStreamGenerator",
    "RandomNumberGenerator", "Crypto", "HashingContext", "Marshalls", "Image",
    "ImageTexture", "FontFile", "FontVariation", "SystemFont", "Theme",
    "StyleBoxFlat", "StyleBoxEmpty", "StyleBoxTexture", "Callable", "Signal",
    "PackedFloat32Array", "PackedInt64Array", "Vector4", "Rect2", "RID",
    "VBoxContainer", "HBoxContainer", "GridContainer", "FlowContainer",
    "MarginContainer", "ScrollContainer", "VScrollBar", "HScrollBar",
    "PopupPanel", "PopupMenu", "CheckBox", "CheckButton", "ProgressBar",
    "HSlider", "VSlider", "LineEdit", "TextEdit", "TabContainer", "Label",
    "Button", "PanelContainer", "Panel", "TextureRect", "RichTextLabel",
    "Window", "AcceptDialog", "ConfirmationDialog", "Tree", "ItemList",
    "Separator", "HSeparator", "VSeparator", "SpinBox", "OptionButton",
}

## `&"Name"` literals that are legitimately *not* theme variations: progress-bar
## node names and audio bus names. Keeping this list explicit (rather than
## matching any CamelCase literal) is what makes the variation check sharp.
NON_VARIATION_NAMES = {
    "XpBar", "RankBar", "ThinBar", "HealthBar", "AmmoBar", "ZoneTimerBar",
}
# Note: audio bus names are deliberately *not* listed here — they are read from
# default_bus_layout.tres below, so renaming a bus cannot leave a stale copy
# behind that keeps validating the old name.

# Members provided by Godot on every Node/Control/Resource, used when a class
# of ours extends an engine type and therefore has no in-repo base members.
ENGINE_MEMBERS = {
    "new", "free", "queue_free", "get", "set", "call", "call_deferred",
    "has_method", "get_script", "get_parent", "get_tree", "get_node",
    "get_children", "add_child", "remove_child", "connect", "emit", "disconnect",
    "duplicate", "instance", "instantiate", "resource_path", "get_class",
    "is_inside_tree", "is_visible_in_tree", "set_process", "set_physics_process",
    "queue_redraw", "notification", "get_instance_id", "set_meta", "get_meta",
    "has_meta", "remove_meta", "get_property_list", "property_list_changed_notify",
}


class TypeInfo:
    def __init__(self, name: str, path: Path) -> None:
        self.name = name
        self.path = path
        self.base: str = ""
        self.methods: set[str] = set()
        self.consts: set[str] = set()
        self.vars: set[str] = set()
        self.signals: set[str] = set()
        self.enums: set[str] = set()
        self.enum_members: dict[str, set[str]] = {}
        self.signatures: dict[str, tuple[int, int]] = {}   # name -> (min, max)
        self.signal_params: dict[str, int] = {}
        self.is_autoload = False

    def all_members(self) -> set[str]:
        return self.methods | self.consts | self.vars | self.signals | self.enums | ENGINE_MEMBERS


def strip_comments(line: str) -> str:
    """Remove a trailing `#` comment, ignoring `#` inside string literals."""
    out = []
    in_string = False
    quote = ""
    index = 0
    while index < len(line):
        char = line[index]
        if in_string:
            if char == "\\":
                out.append(line[index:index + 2])
                index += 2
                continue
            if char == quote:
                in_string = False
            out.append(char)
        elif char in "\"'":
            in_string = True
            quote = char
            out.append(char)
        elif char == "#":
            break
        else:
            out.append(char)
        index += 1
    return "".join(out)


def strip_literals(line: str) -> str:
    """Remove comments *and* the contents of string literals.

    Call detection has to run on code only: `"%s (music stays silent)"` looks
    exactly like a call to `s()` once the quotes are ignored, and a made-up
    report is worse than no report.
    """
    out: list[str] = []
    index = 0
    in_string = False
    quote = ""
    while index < len(line):
        char = line[index]
        if in_string:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                in_string = False
                out.append(quote)
            index += 1
            continue
        if char in "\"'":
            in_string = True
            quote = char
            out.append(quote)
        elif char == "#":
            break
        else:
            out.append(char)
        index += 1
    return "".join(out)


def split_top_level(text: str) -> list[str]:
    """Split a parameter/argument list on commas that are not nested."""
    parts: list[str] = []
    depth = 0
    current: list[str] = []
    in_string = False
    quote = ""
    index = 0
    while index < len(text):
        char = text[index]
        if in_string:
            if char == "\\":
                current.append(text[index:index + 2])
                index += 2
                continue
            if char == quote:
                in_string = False
            current.append(char)
        elif char in "\"'":
            in_string = True
            quote = char
            current.append(char)
        elif char in "([{":
            depth += 1
            current.append(char)
        elif char in ")]}":
            depth -= 1
            current.append(char)
        elif char == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(char)
        index += 1
    tail = "".join(current).strip()
    if parts or tail:
        parts.append(tail)
    return [part for part in (piece.strip() for piece in parts) if part]


def parse_params(header: str) -> tuple[int, int]:
    """(required, allowed) argument count for a `func name(...)` header line."""
    start = header.find("(")
    end = header.rfind(")")
    if start < 0 or end < start:
        return (0, 0)
    inner = header[start + 1:end]
    params = split_top_level(inner)
    if not params:
        return (0, 0)
    required = 0
    for param in params:
        if param.startswith("*"):
            return (required, 1 << 30)
        if "=" in param.split(":", 1)[-1] or ("=" in param and ":" not in param):
            continue
        required += 1
    return (required, len(params))


def parse_signal_params(header: str) -> int:
    start = header.find("(")
    end = header.rfind(")")
    if start < 0 or end < start:
        return 0
    return len(split_top_level(header[start + 1:end]))


def join_declaration(lines: list[str], index: int) -> tuple[str, int]:
    """Join a `func`/`signal` line with its continuations until parens balance.

    Multi-line signatures are the norm in this codebase (gdlint caps lines at
    150 bytes), so a single-line parse would silently report every parameter
    list as empty and make the argument-count check useless.
    """
    line = strip_comments(lines[index])
    consumed = index
    while line.count("(") > line.count(")") and consumed + 1 < len(lines):
        consumed += 1
        line += " " + strip_comments(lines[consumed]).strip()
    return line, consumed


def parse_gdscript(path: Path, autoloads: set[str]) -> TypeInfo | None:
    info = TypeInfo(path.stem, path)
    text = path.read_text(encoding="utf-8")
    raw_lines = text.splitlines()
    cursor = 0
    while cursor < len(raw_lines):
        raw = raw_lines[cursor]
        if FUNC_RE.match(strip_comments(raw)) or SIGNAL_RE.match(strip_comments(raw)):
            joined, consumed = join_declaration(raw_lines, cursor)
            raw = joined
            cursor = consumed + 1
        else:
            cursor += 1
        line = raw
        if not line.strip():
            continue
        match = CLASS_RE.match(line)
        if match:
            info.name = match.group(1)
            continue
        match = EXTENDS_RE.match(line)
        if match:
            base = match.group(1)
            info.base = "" if base in ("RefCounted", "Object") else base
            continue
        match = FUNC_RE.match(line)
        if match:
            # Nested `func` lines (inner classes such as HexIcon's shape
            # drawers) are indexed too: a bare call inside the outer class must
            # resolve, and a name collision is harmless for this check.
            info.methods.add(match.group(1))
            if not raw.startswith(("\t", " ")):
                info.signatures[match.group(1)] = parse_params(line)
            continue
        match = SIGNAL_RE.match(line)
        if match:
            info.signals.add(match.group(1))
            info.signal_params[match.group(1)] = parse_signal_params(line)
            continue
        match = CONST_RE.match(line)
        if match:
            info.consts.add(match.group(1))
            continue
        match = ENUM_RE.match(line)
        if match:
            info.enums.add(match.group(1))
            info.enum_members.setdefault(match.group(1), set())
            if "{" in line:
                body = line[line.index("{") + 1:]
                info.enum_members[match.group(1)] |= set(re.findall(r"([A-Za-z_]\w*)", body))
            continue
        match = VAR_RE.match(line)
        if match and not line.lstrip().startswith("static"):
            info.vars.add(match.group(1))
            continue
    # Inline enums (`enum Foo { A, B }` on multiple lines) — collect members by
    # scanning the block that follows the enum header.
    lines = text.splitlines()
    for index, raw in enumerate(lines):
        line = strip_comments(raw)
        match = ENUM_BLOCK_RE.match(line)
        if not match or "{" in line and "}" in line:
            continue
        if not match.group(1):
            continue
        name = match.group(1)
        depth = line.count("{") - line.count("}")
        cursor = index
        while depth > 0 and cursor + 1 < len(lines):
            cursor += 1
            body = strip_comments(lines[cursor])
            info.enum_members.setdefault(name, set())
            info.enum_members[name] |= set(re.findall(r"^\s*([A-Za-z_]\w*)", body))
            depth += body.count("{") - body.count("}")
    if info.name in autoloads:
        info.is_autoload = True
    return info


def collect_i18n() -> tuple[dict[str, set[str]], list[str]]:
    tables: dict[str, set[str]] = {}
    problems: list[str] = []
    i18n_dir = SRC_DIR / "i18n"
    for path in sorted(i18n_dir.glob("strings_*.gd")):
        locale = path.stem.replace("strings_", "")
        keys: set[str] = set()
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            match = re.match(r'\s*"((?:[^"\\]|\\.)*)"\s*:\s*"', raw)
            if match:
                key = match.group(1)
                if key in keys:
                    problems.append(f"{path.name}:{lineno}: duplicate key {key!r}")
                keys.add(key)
        tables[locale] = keys
    return tables, problems


CALL_RE = re.compile(r"(?<![\w.])([A-Z]\w*)\.([a-z_]\w*)\s*\(")
# Bare `helper(` calls: methods inherited from a repo base class are called
# without a receiver (`header(...)`, `card(...)`), which no member-access check
# can see. Anything not defined in the repo and not an engine global is a typo.
BARE_CALL_RE = re.compile(r"(?<![\w.$])([a-z_]\w*)\s*\(")
KEYWORDS = {
    "if", "elif", "else", "while", "for", "match", "when", "return", "and",
    "or", "not", "in", "is", "as", "await", "yield", "func", "var", "const",
    "class", "class_name", "extends", "enum", "signal", "static", "break",
    "continue", "pass", "self", "super", "preload", "load", "assert", "print",
}
## Engine globals and the Node/Object/Resource methods this project calls
## without a receiver. Kept explicit so that a typo cannot hide behind it.
ENGINE_GLOBALS = {
    "abs", "absf", "absi", "acos", "asin", "atan", "atan2", "ceil", "ceilf",
    "ceili", "clamp", "clampf", "clampi", "cos", "cosh", "db_to_linear",
    "deg_to_rad", "ease", "error_string", "exp", "floor", "floorf", "floori",
    "fmod", "fposmod", "hash", "instance_from_id", "inverse_lerp", "lerp",
    "lerp_angle", "lerpf", "linear_to_db", "log", "max", "maxf", "maxi", "min",
    "minf", "mini", "move_toward", "nearest_po2", "pingpong", "posmod", "pow",
    "print_rich", "print_verbose", "printerr", "printraw", "prints", "printt",
    "push_error", "push_warning", "rad_to_deg", "rand_from_seed", "randf",
    "randf_range", "randfn", "randi", "randi_range", "randomize", "remap",
    "rotate_toward", "round", "roundf", "roundi", "seed", "sign", "signf",
    "signi", "sin", "sinf", "sinh", "smoothstep", "snapped", "snappedf",
    "snappedi", "cosf", "tanf",
    "sqrt", "step_decimals", "str", "str_to_var", "tan", "tanh", "type_convert",
    "type_string", "typeof", "var_to_bytes", "var_to_str", "weakref", "wrap",
    "wrapf", "wrapi", "len", "ord", "char", "range",
    # Type constructors/casts spelled in lower case.
    "int", "float", "bool", "ceil", "trunc",
    # Node / Object / Control methods used without a receiver.
    "add_child", "remove_child", "queue_free", "get_node", "get_tree",
    "get_parent", "get_children", "queue_redraw", "set_process",
    "set_process_input", "set_process_unhandled_input", "is_inside_tree",
    "is_node_ready", "is_visible_in_tree", "has_method", "call", "callv",
    "call_deferred", "connect", "disconnect", "emit_signal", "get",
    "set", "set_deferred", "set_meta", "get_meta", "has_meta", "free",
    "duplicate", "get_viewport", "get_window", "notification", "new",
    "add_theme_constant_override", "add_theme_stylebox_override",
    "add_theme_color_override", "add_theme_font_override",
    "add_theme_font_size_override", "get_script", "get_class",
    "set_anchors_preset", "set_offsets_preset", "grab_focus", "release_focus",
    "instantiate", "instance", "resize", "fill", "update", "create_tween",
    "get_rid", "emit_changed", "get_instance_id", "has_signal",
    "rpc", "rpc_id", "rpc_config", "get_process_delta_time", "get_ticks_msec",
    "accept_event", "set_input_as_handled", "get_viewport_rect", "mark_dirty",
    "is_instance_valid", "is_instance_id_valid", "get_path", "get_index",
    # Annotation-shaped callables (`@export_group(...)`, `@rpc(...)`).
    "export", "export_group", "export_subgroup", "export_range", "export_enum",
    "export_flags", "export_file", "export_dir", "export_multiline",
    "export_color_no_alpha", "export_node_path", "export_storage",
    "export_placeholder", "export_custom", "tool",
    # CanvasItem drawing API, used bare inside `_draw()`.
    "draw_line", "draw_polyline", "draw_polyline_colors", "draw_multiline",
    "draw_multiline_colors", "draw_rect", "draw_circle", "draw_arc",
    "draw_colored_polygon", "draw_polygon", "draw_string", "draw_texture",
    "draw_texture_rect", "draw_texture_rect_region", "draw_set_transform",
    "draw_set_transform_matrix", "draw_dashed_line", "draw_primitive",
    "draw_char", "draw_mesh", "draw_multimesh", "draw_animation_slice",
}
# `EventBus.thing_happened.connect(_on_thing)` — signal wiring, checked against
# the signal's own parameter list.
SIGNAL_WIRE_RE = re.compile(
    r"(?<![\w.])([A-Z]\w*)\.([a-z_]\w*)\.(emit|connect|disconnect)\s*\("
)


def _span_after(text: str, open_index: int) -> int:
    """Index just past the parenthesis that closes the one at `open_index`."""
    depth = 0
    in_string = False
    quote = ""
    index = open_index
    while index < len(text):
        char = text[index]
        if in_string:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                in_string = False
        elif char in "\"'":
            in_string = True
            quote = char
        elif char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index + 1
        index += 1
    return -1


def _check_arity(rel: Path, text: str, index: dict[str, TypeInfo]) -> list[str]:
    problems: list[str] = []
    cleaned = "\n".join(strip_comments(line) for line in text.splitlines())
    for match in CALL_RE.finditer(cleaned):
        type_name, member = match.group(1), match.group(2)
        info = index.get(type_name)
        if info is None or member in ENGINE_MEMBERS:
            continue
        open_index = cleaned.index("(", match.end() - 1)
        close_index = _span_after(cleaned, open_index)
        if close_index < 0:
            continue
        arguments = split_top_level(cleaned[open_index + 1:close_index - 1])
        count = len(arguments)
        signature = _lookup_signature(index, info, member)
        if signature is None:
            continue
        low, high = signature
        if low <= count <= high:
            continue
        lineno = cleaned.count("\n", 0, match.start()) + 1
        expected = f"{low}" if low == high else f"{low}..{high}"
        problems.append(
            f"{rel}:{lineno}: {type_name}.{member}() called with {count} argument(s), "
            f"expected {expected}"
        )
    return problems


def _check_signal_wiring(rel: Path, text: str, index: dict[str, TypeInfo]) -> list[str]:
    """Signals must be emitted and connected with the right number of values.

    A mismatched `emit` is a runtime error that only fires when that code path
    runs, which for a "player left the room" toast means it ships.
    """
    problems: list[str] = []
    cleaned = "\n".join(strip_comments(line) for line in text.splitlines())
    owner: TypeInfo | None = None
    for info in index.values():
        if info.path == Path(REPO_ROOT / rel):
            owner = info
            break
    for match in SIGNAL_WIRE_RE.finditer(cleaned):
        type_name, signal_name, verb = match.group(1), match.group(2), match.group(3)
        info = index.get(type_name)
        if info is None or signal_name not in info.signal_params:
            continue
        expected = info.signal_params[signal_name]
        open_index = cleaned.index("(", match.end() - 1)
        close_index = _span_after(cleaned, open_index)
        if close_index < 0:
            continue
        arguments = split_top_level(cleaned[open_index + 1:close_index - 1])
        lineno = cleaned.count("\n", 0, match.start()) + 1
        if verb == "emit":
            if len(arguments) != expected:
                problems.append(
                    f"{rel}:{lineno}: {type_name}.{signal_name}.emit() passes "
                    f"{len(arguments)} value(s), the signal declares {expected}"
                )
            continue
        if verb == "connect" and arguments and arguments[0].startswith("_"):
            handler = arguments[0]
            if owner is None or handler not in owner.signatures:
                continue
            low, high = owner.signatures[handler]
            if not (low <= expected <= high):
                problems.append(
                    f"{rel}:{lineno}: {type_name}.{signal_name} ({expected} arg(s)) "
                    f"connected to {handler}() which accepts {low}..{high}"
                )
    return problems


def _lookup_signature(index: dict[str, TypeInfo], info: TypeInfo, member: str,
                      seen: set[str] | None = None) -> tuple[int, int] | None:
    seen = seen or set()
    if info.name in seen:
        return None
    seen.add(info.name)
    if member in info.signatures:
        return info.signatures[member]
    for parent_name in (info.base,):
        parent = index.get(parent_name)
        if parent is not None and parent is not info:
            found = _lookup_signature(index, parent, member, seen)
            if found is not None:
                return found
    return None


def check_tscn(path: Path) -> list[str]:
    """Structural checks for a hand-authored `.tscn` / `.tres`.

    These files are invisible to the GDScript checks above, and the loader is
    unforgiving in ways that give confusing errors: a PackedScene that opens
    with `[gd_resource]` instead of `[gd_scene]` parses as an *empty* resource
    and every `[node]` after it is rejected, so the game fails to boot with a
    message pointing at a node rather than at the header.
    """
    problems: list[str] = []
    rel = path.relative_to(REPO_ROOT)
    text = path.read_text(encoding="utf-8")
    is_scene = path.suffix == ".tscn"
    header = next((line for line in text.splitlines() if line.startswith("[")), "")
    expected = "[gd_scene" if is_scene else "[gd_resource"
    if not header.startswith(expected):
        problems.append(
            f"{rel}: must open with {expected!r}, found {header[:40]!r} "
            f"(a PackedScene written as [gd_resource] loads empty and rejects the "
            f"[node] sections below it)"
        )
    if is_scene and "[node " not in text:
        problems.append(f"{rel}: has no [node] heading")

    # load_steps is ext + sub + 1; the editor writes it and the loader trusts it
    # for progress reporting, so a hand edit that adds a resource without
    # touching it is a real (if quiet) inconsistency.
    steps = re.search(r"load_steps=(\d+)", header)
    ext_total = len(re.findall(r"^\[ext_resource", text, re.M))
    sub_total = len(re.findall(r"^\[sub_resource", text, re.M))
    if steps and int(steps.group(1)) != ext_total + sub_total + 1:
        problems.append(
            f"{rel}: load_steps={steps.group(1)} but the file declares "
            f"{ext_total} ext_resource + {sub_total} sub_resource (+1)"
        )

    ids: set[str] = set()
    for lineno, raw in enumerate(text.splitlines(), 1):
        script_ref = TSCN_EXT_RE.match(raw)
        if script_ref:
            target = script_ref.group(1)
            if not (REPO_ROOT / target.replace("res://", "", 1)).exists():
                problems.append(f"{rel}:{lineno}: missing ext_resource {target}")
        identifier = re.match(r'^\[(?:ext|sub)_resource[^\]]*id="([^"]+)"', raw)
        if identifier:
            if identifier.group(1) in ids:
                problems.append(f"{rel}:{lineno}: duplicate resource id "
                                f"{identifier.group(1)!r}")
            ids.add(identifier.group(1))
        node = TSCN_NODE_RE.match(raw)
        if node and not node.group(2):
            problems.append(f"{rel}:{lineno}: node without a type")
    for lineno, raw in enumerate(text.splitlines(), 1):
        for identifier in re.findall(r'(?:Ext|Sub)Resource\(\s*&?"([^"]+)"\s*\)', raw):
            if identifier not in ids:
                problems.append(f"{rel}:{lineno}: references undefined resource "
                                f"{identifier!r}")
    for ref in RES_PATH_RE.findall(text):
        if not (REPO_ROOT / ref.replace("res://", "", 1)).exists():
            problems.append(f"{rel}: missing referenced resource {ref}")
    return problems


def _table_values() -> dict[str, str]:
    path = SRC_DIR / "i18n" / "strings_en.gd"
    values: dict[str, str] = {}
    if path.exists():
        for raw in path.read_text(encoding="utf-8").splitlines():
            match = re.match(r'\s*"((?:[^"\\]|\\.)*)"\s*:\s*"((?:[^"\\]|\\.)*)"', raw)
            if match:
                values[match.group(1)] = match.group(2)
    return values


_EN_VALUES: dict[str, str] = {}


def _value_of(key: str) -> str:
    return _EN_VALUES.get(key, "")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verbose", action="store_true", help="dump the built index")
    parser.add_argument("--no-arity", action="store_true", help="skip argument-count checks")
    args = parser.parse_args()

    problems: list[str] = []

    global _EN_VALUES
    _EN_VALUES = _table_values()

    # ------------------------------------------------------------------ index
    project_text = (REPO_ROOT / "project.godot").read_text(encoding="utf-8")
    autoload_paths: dict[str, str] = {}
    in_autoload = False
    for raw in project_text.splitlines():
        line = strip_comments(raw).strip()
        if line.startswith("["):
            in_autoload = line == "[autoload]"
            continue
        if in_autoload:
            match = AUTOLOAD_RE.match(line)
            if match:
                autoload_paths[match.group(1)] = match.group(2)
    for name, target in autoload_paths.items():
        if not (REPO_ROOT / target.replace("res://", "", 1)).exists():
            problems.append(f"project.godot: autoload {name} points at missing {target}")

    autoload_names = set(autoload_paths)
    index: dict[str, TypeInfo] = {}
    for path in sorted(SRC_DIR.rglob("*.gd")):
        info = parse_gdscript(path, autoload_names)
        if info.name in index:
            problems.append(
                f"duplicate class_name {info.name!r}: "
                f"{index[info.name].path.relative_to(REPO_ROOT)} and {path.relative_to(REPO_ROOT)}"
            )
            continue
        index[info.name] = info

    # Autoload singletons are addressed by their *autoload* name (`Rooms`), which
    # is deliberately different from the script's `class_name` (`RoomService`).
    # Register the autoload name as an alias so member checks cover calls
    # through either name.
    for name, target in autoload_paths.items():
        stem = Path(target.replace("res://", "", 1)).stem
        for info in list(index.values()):
            if info.path.stem == stem:
                index.setdefault(name, info)
                break
        else:
            problems.append(f"project.godot: autoload {name} -> {target} is not indexed")

    i18n_tables, i18n_problems = collect_i18n()
    problems.extend(i18n_problems)
    if i18n_tables:
        reference = i18n_tables.get("en") or next(iter(i18n_tables.values()))
        for locale, keys in i18n_tables.items():
            for key in sorted(reference - keys):
                problems.append(f"i18n: {locale} is missing key {key!r}")
            for key in sorted(keys - reference):
                problems.append(f"i18n: {locale} has extra key {key!r}")

    def resolves(type_name: str, member: str, seen: set[str] | None = None) -> bool:
        seen = seen or set()
        if type_name in seen or type_name not in index:
            return False
        seen.add(type_name)
        info = index[type_name]
        if member in info.all_members():
            return True
        # `Foo.BAR` may be an enum member of any enum declared in Foo.
        for members in info.enum_members.values():
            if member in members:
                return True
        if info.base:
            if resolves(info.base, member, seen):
                return True
        return True if member in ENGINE_MEMBERS else False

    # --------------------------------------------------------------- call sites
    gd_files = sorted(SRC_DIR.rglob("*.gd"))
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        text = path.read_text(encoding="utf-8")
        for lineno, raw in enumerate(text.splitlines(), 1):
            line = strip_comments(raw)
            for ref in RES_PATH_RE.findall(line):
                if ref.startswith("res://") and not (REPO_ROOT / ref.replace("res://", "", 1)).exists():
                    problems.append(f"{rel}:{lineno}: references missing resource {ref}")
            # A double-escaped control sequence is always a typo in a GDScript
            # string: `"\\n"` is a backslash and an "n", not a newline. It reads
            # correctly in the source and renders as literal junk at runtime, so
            # nothing but a checker will ever catch it.
            for escape in re.findall(r'\\\\[ntr]', raw):
                problems.append(
                    f"{rel}:{lineno}: the string contains {escape!r} (a literal "
                    f"backslash and letter) — use a single backslash for a real "
                    f"escape"
                )
            for locale_key in LOC_KEY_RE.findall(line):
                for locale, keys in i18n_tables.items():
                    if locale_key not in keys:
                        problems.append(f"{rel}:{lineno}: i18n key {locale_key!r} not in {locale} table")
            # Three-level enum access first, so `A.B.c` is not misread as two.
            for outer, mid, member in CHAIN_RE.findall(line):
                if outer not in index:
                    continue
                if mid in index[outer].enums or mid in index[outer].enum_members:
                    if member not in index[outer].enum_members.get(mid, set()):
                        # Could be a nested class_name reference; only flag when
                        # the middle segment is a known enum.
                        if mid in index[outer].enum_members or mid in index[outer].enums:
                            problems.append(
                                f"{rel}:{lineno}: enum member {outer}.{mid}.{member} does not exist"
                            )
            for type_name, member in MEMBER_RE.findall(line):
                if type_name not in index:
                    continue
                if not resolves(type_name, member):
                    problems.append(
                        f"{rel}:{lineno}: {type_name}.{member} does not exist "
                        f"(defined in {index[type_name].path.relative_to(REPO_ROOT)})"
                    )

        # Argument counts. Checked on the whole-file text (not line by line)
        # because a call may be wrapped across lines; the balanced scan below
        # finds the closing parenthesis either way.
        if not args.no_arity:
            problems.extend(_check_arity(rel, text, index))
            problems.extend(_check_signal_wiring(rel, text, index))

    # ------------------------------------------------------------------- scenes

    # ------------------------------------------------------- bare helper calls
    repo_functions: set[str] = set()
    for info in index.values():
        repo_functions |= info.methods
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        owner = None
        for info in index.values():
            if info.path == Path(REPO_ROOT / rel):
                owner = info
                break
        if owner is None:
            continue
        # Names reachable from this class: itself, its repo base classes, and
        # every helper on an engine ancestor.
        reachable = set(owner.methods) | set(owner.vars) | set(owner.consts)
        base = owner.base
        guard = 0
        while base and base in index and guard < 8:
            parent = index[base]
            reachable |= set(parent.methods) | set(parent.vars) | set(parent.consts)
            base = parent.base
            guard += 1
        source_lines = path.read_text(encoding="utf-8").splitlines()
        # A lambda or a Callable stored in a local (`var s := func(): ...`,
        # `var cb := ...`) is called bare as `s(...)`. Collect local and loop
        # variable names so those calls are not reported as typos.
        locals_: set[str] = set()
        for raw in source_lines:
            for match in re.finditer(r"\b(?:var|for)\s+([a-z_]\w*)", strip_literals(raw)):
                locals_.add(match.group(1))
            for match in re.finditer(r"^\s*(?:var\s+)?([a-z_]\w*)\s*:=\s*func\b",
                    strip_literals(raw)):
                locals_.add(match.group(1))
        for lineno, raw in enumerate(source_lines, 1):
            line = strip_literals(raw)
            stripped = line.strip()
            if stripped.startswith(("func ", "signal ", "static func ")):
                continue
            for match in BARE_CALL_RE.finditer(line):
                name = match.group(1)
                if name in KEYWORDS or name in ENGINE_GLOBALS or name in reachable:
                    continue
                if name in locals_:
                    continue
                if name in repo_functions:
                    continue        # defined elsewhere in the repo: engine-level
                problems.append(
                    f"{rel}:{lineno}: call to {name}() resolves to nothing "
                    f"(not in this class, its repo bases, the engine globals, or the repo)"
                )

    # ---------------------------------------------------- audio bus names exist
    # The bus names live in three places — the layout resource, the audio
    # service, and the volume table in Settings. A rename in any one of them is
    # silent at runtime: the player keeps "working", routed to Master, and the
    # volume slider moves nothing. So the layout resource is the source of
    # truth and every name in code is checked against it.
    # Bus 0 is implicit: Godot's AudioBusLayout constructor seeds it as
    # "Master" and the editor therefore never writes a `bus/0/name` line, which
    # is why it is added here by hand.
    bus_names: set[str] = {"Master"}
    layout_path = REPO_ROOT / "default_bus_layout.tres"
    if layout_path.exists():
        bus_names |= set(re.findall(r'^bus/\d+/name\s*=\s*&"([^"]+)"',
                                    layout_path.read_text(encoding="utf-8"), re.M))
    if not bus_names:
        problems.append("default_bus_layout.tres declares no named audio buses")
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comments(raw)
            for bus in re.findall(r'\bbus\s*=\s*&"([^"]+)"', line) \
                    + re.findall(r'"bus":\s*"([^"]+)"', line):
                if bus not in bus_names:
                    problems.append(
                        f"{rel}:{lineno}: audio bus {bus!r} does not exist in "
                        f"default_bus_layout.tres (found {sorted(bus_names)})"
                    )

    # ------------------------------------------------- theme variations exist
    design_info = index.get("Design")
    defined_variations: set[str] = set()
    if design_info is not None:
        design_source = design_info.path.read_text(encoding="utf-8")
        # design.gd declares its variations inside data tables that are iterated
        # at build time, so every `&"Name"` literal in the file counts as a
        # definition. Anything the UI asks for but design.gd never mentions is
        # a typo waiting to silently fall back to the engine theme.
        for match in STRINGNAME_LITERAL_RE.finditer(design_source):
            name = match.group(1)
            if name[:1].isupper():
                defined_variations.add(name)
    # Every CamelCase `&"Name"` in the UI must be a variation design.gd builds,
    # an engine type used as a variation, a progress-bar node name or a bus
    # name. design.gd itself is the definition site and is skipped here.
    design_path = design_info.path if design_info is not None else None
    for path in gd_files:
        if path == design_path:
            continue
        rel = path.relative_to(REPO_ROOT)
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comments(raw)
            for match in STRINGNAME_LITERAL_RE.finditer(line):
                name = match.group(1)
                if not name[:1].isupper():
                    continue
                if name in defined_variations or name in GODOT_TYPES \
                        or name in NON_VARIATION_NAMES or name in bus_names:
                    continue
                problems.append(
                    f"{rel}:{lineno}: {name!r} is neither a theme variation defined in "
                    f"design.gd, an engine type, nor a known node/bus name"
                )

    # ---------------------------------------------------- i18n placeholder use
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            line = strip_comments(raw)
            match = LOC_CALL_RE.search(line)
            if not match or match.group(2) is None:
                continue
            key = match.group(1)
            required = set()
            for table_keys in i18n_tables.values():
                if key in table_keys:
                    required |= set(PLACEHOLDER_RE.findall(_value_of(key)))
                    break
            supplied = set(re.findall(r'&?"([a-zA-Z_]\w*)"\s*:', match.group(2)))
            missing = required - supplied
            if missing:
                problems.append(
                    f"{rel}:{lineno}: Loc.t({key!r}) is missing placeholder(s) "
                    f"{sorted(missing)}"
                )

    # ------------------------------------------------ dynamic i18n key sources
    # Keys built with a format string cannot be checked literally, so the
    # generators that produce them are enumerated here instead. Every entry
    # must keep matching its source of truth in the codebase.
    dynamic_keys: list[str] = []
    dynamic_keys += [
        "settings.tab.game", "settings.tab.graphics", "settings.tab.audio",
    ]
    for source in (SRC_DIR / "core").rglob("*.tres"):
        for literal in STRINGNAME_LITERAL_RE.findall(source.read_text(encoding="utf-8")):
            if "." in literal and not literal.startswith("res://"):
                dynamic_keys.append(literal)
    profile_text = (SRC_DIR / "core" / "player_profile.gd").read_text(encoding="utf-8")
    tiers = re.search(r"RANK_TIER_KEYS[^\]]*\[([^\]]+)\]", profile_text)
    if tiers:
        dynamic_keys += re.findall(r"&?(\w+\.\w+)", tiers.group(1))
    for key in sorted(set(dynamic_keys)):
        for locale, keys in i18n_tables.items():
            if key not in keys:
                problems.append(f"i18n: dynamically built key {key!r} is not in {locale}")

    # ------------------------------------------------------------------- scenes
    scenes = sorted((SRC_DIR / "ui").rglob("*.tscn"))
    for scene in scenes:
        problems.extend(check_tscn(scene))
    # Data resources get the same header/load_steps/reference treatment; the
    # field-name check further down assumes the file parsed at all.
    for resource in sorted(REPO_ROOT.rglob("*.tres")):
        if ".godot" in resource.parts or resource.parts[-1] == ".godot":
            continue
        problems.extend(check_tscn(resource))

    router_text = (SRC_DIR / "autoload" / "router.gd").read_text(encoding="utf-8")
    for ref in RES_PATH_RE.findall(router_text):
        if not (REPO_ROOT / ref.replace("res://", "", 1)).exists():
            problems.append(f"router.gd: screen scene {ref} does not exist")

    main_scene = re.search(r'run/main_scene="(res://[^"]+)"', project_text)
    if main_scene and not (REPO_ROOT / main_scene.group(1).replace("res://", "", 1)).exists():
        problems.append(f"project.godot: main scene {main_scene.group(1)} does not exist")

    if args.verbose:
        print(f"indexed {len(index)} classes, {len(autoload_paths)} autoloads, "
              f"{len(gd_files)} scripts, {len(scenes)} scenes, "
              f"{len(i18n_tables.get('en', ()))} en keys")
        for name in sorted(index):
            info = index[name]
            print(f"  {name:<22} {len(info.methods):>3} funcs  "
                  f"{len(info.consts):>3} consts  {len(info.vars):>3} vars  "
                  f"<- {info.base or 'engine'}")

    # ------------------------------------- project.godot resource references
    # The `res://` scan above only walks GDScript; `project.godot` references
    # the icon, the bus layout, the default environment and every autoload by
    # hand, and a rename there fails silently until the game boots.
    for lineno, raw in enumerate(project_text.splitlines(), 1):
        for ref in RES_PATH_RE.findall(strip_comments(raw)):
            if ref in set(autoload_paths.values()):
                continue  # already reported with a clearer message above
            if not (REPO_ROOT / ref.replace("res://", "", 1)).exists():
                problems.append(f"project.godot:{lineno}: references missing resource {ref}")

    # ------------------------------------------- data resource field names
    # `.tres` files are invisible to every check above: a typo in a field name
    # (`titel_key = &"mode.tdm.name"`) becomes an unused property on an
    # otherwise perfectly valid resource, and the UI then renders the key.
    for res in sorted(SRC_DIR.rglob("*.tres")):
        rel = res.relative_to(REPO_ROOT)
        text = res.read_text(encoding="utf-8")
        header = re.search(r'^\[gd_resource\s+type="[^"]+"\s+script_class="([^"]+)"', text, re.M)
        script_ref = re.search(r'^\[ext_resource\s+type="Script"\s+path="(res://[^"]+)"', text, re.M)
        if script_ref:
            script_path = REPO_ROOT / script_ref.group(1).replace("res://", "", 1)
            if not script_path.exists():
                problems.append(f"{rel}: ext_resource script {script_ref.group(1)} is missing")
        owner = header.group(1) if header else ""
        if not owner or owner not in index:
            # Plain engine resources (Environment, AudioBusLayout, Theme) use
            # engine-defined property names we cannot verify from here.
            continue
        known = set(index[owner].vars) | set(index[owner].consts)
        for lineno, raw in enumerate(text.splitlines(), 1):
            if not raw or raw[0] in "[;#":
                continue
            field = re.match(r"^([A-Za-z_]\w*)\s*=", raw)
            if field is None:
                continue  # continuation of a multi-line value
            name = field.group(1)
            if name == "script" or name in known:
                continue
            problems.append(
                f"{rel}:{lineno}: field {name!r} is not declared by {owner} "
                f"({index[owner].path.relative_to(REPO_ROOT)})"
            )

    # -------------------------------------------------- settings keys exist
    # `Settings.get_bool("game/keep_screen_on")` on a key that is not in the
    # schema returns the fallback silently: the toggle saves, nothing reads it,
    # and the value is forgotten on the next launch. Two real bugs of exactly
    # that shape (`game/keep_screen_awake` declared but never read,
    # `net/allow_bots` read but never declared) are why this check exists.
    settings_info = index.get("Settings")
    declared_settings: set[str] = set()
    if settings_info is not None:
        declared_settings = set(re.findall(
            r'"([a-z][a-z0-9_]*/[a-z0-9_]+)"',
            settings_info.path.read_text(encoding="utf-8"),
        ))
    if not declared_settings:
        problems.append("settings_service.gd declares no settings keys")
    ROW_KEY_RE = re.compile(
        r'_\w*_row\(\s*&?"[^"]+"\s*,\s*"([^"]+)"')
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            # strip_comments, not strip_literals: the key *is* a literal.
            line = strip_comments(raw)
            # The lookbehind matters: without it `ProjectSettings.get_setting`
            # matches too, and every engine project setting is "undeclared".
            keys = re.findall(r'(?<![A-Za-z_.])Settings\.\w+\(\s*&?"([^"]+)"', line)
            if path.name == "settings_page.gd":
                keys += ROW_KEY_RE.findall(line)
            for key in keys:
                if "/" not in key or key in declared_settings:
                    continue
                problems.append(
                    f"{rel}:{lineno}: settings key {key!r} is not declared in "
                    f"settings_service.gd (_build_defaults) — reading it returns "
                    f"the fallback forever"
                )


    # A signal on an autoload outlives every widget, and `build()` runs again
    # on each language change — so a raw `.connect()` there subscribes twice,
    # which Godot reports as an error and which fires every handler twice. The
    # only places a raw autoload `.connect()` is correct are the lifecycle
    # callbacks that run exactly once; everything else must go through the
    # idempotent helper. Enforced rather than documented, because the symptom
    # (duplicate handlers) only shows up after a language switch.
    LIFECYCLE_FUNCS = {"_ready", "_init", "_enter_tree"}
    for path in gd_files:
        rel = path.relative_to(REPO_ROOT)
        owner = ""
        for lineno, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if re.match(r"^class\s", raw):
                owner = ""          # inside an inner class: don't attribute
                continue
            declaration = re.match(r"^func\s+([A-Za-z_]\w*)", raw)
            if declaration:
                owner = declaration.group(1)
                continue
            line = strip_literals(raw)
            for outer, member in re.findall(r"\b([A-Z]\w*)\.(\w+)\.connect\(", line):
                if outer not in autoload_paths or owner in LIFECYCLE_FUNCS:
                    continue
                problems.append(
                    f"{rel}:{lineno}: {outer}.{member}.connect() inside {owner or 'top level'}() "
                    f"— a rebuild would subscribe twice; use UiKit.listen({outer}.{member}, ...) "
                    f"or move it into _ready()"
                )

    # ------------------------------------------------------------------ report
    unique = sorted(set(problems))
    for problem in unique:
        print(f"FAIL {problem}")
    if unique:
        print(f"\n{len(unique)} problem(s) found.")
        return 1
    print(f"OK  {len(index)} classes · {len(gd_files)} scripts · {len(scenes)} scenes · "
          f"{len(i18n_tables.get('en', ()))} localized keys · no dangling references")
    return 0


if __name__ == "__main__":
    sys.exit(main())
