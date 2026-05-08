import json
import shutil
from pathlib import Path

from libqtile import bar, layout, widget
from libqtile.config import Click, Drag, Group, Key, Match, Screen
from libqtile.lazy import lazy

SETTINGS_PATH = Path.home() / ".config" / "cde" / "settings.json"


def default_terminal() -> str:
    return "kitty" if shutil.which("kitty") else "xterm"


def default_file_manager() -> str:
    return "dolphin" if shutil.which("dolphin") else "xdg-open ~"


DEFAULT_SETTINGS = {
    "mod": "mod4",
    "terminal": default_terminal(),
    "launcher": "rofi -show drun -modi drun,filebrowser",
    "launcher_fullscreen": "rofi -show drun -modi drun,filebrowser -fullscreen -show-icons",
    "file_manager": default_file_manager(),
    "bar_height": 34,
    "background": "#1f2335",
    "bar_background": "#1a1b26",
    "accent": "#7aa2f7",
    "text": "#c0caf5",
    "border_normal": "#292e42",
    "border_width": 2,
}


def load_settings() -> dict:
    settings = DEFAULT_SETTINGS.copy()
    if not SETTINGS_PATH.exists():
        return settings

    with SETTINGS_PATH.open(encoding="utf-8") as f:
        user_settings = json.load(f)
    if not isinstance(user_settings, dict):
        raise ValueError(f"Invalid CDE settings format in {SETTINGS_PATH}")

    for key, default in DEFAULT_SETTINGS.items():
        value = user_settings.get(key)
        if isinstance(value, type(default)):
            settings[key] = value
    return settings


settings = load_settings()
mod = settings["mod"]
terminal = settings["terminal"]

keys = [
    Key([mod], "q", lazy.spawn(terminal), desc="Launch terminal"),
    Key([mod], "space", lazy.spawn(settings["launcher"]), desc="Open launcher and file search"),
    Key([mod], "a", lazy.spawn(settings["launcher_fullscreen"]), desc="Open fullscreen app launcher"),
    Key([mod], "e", lazy.spawn(settings["file_manager"]), desc="Open file manager"),
    Key([mod], "comma", lazy.spawn("cde-settings"), desc="Open CDE settings"),
    Key([mod], "w", lazy.window.kill(), desc="Close focused window"),
    Key([mod], "f", lazy.window.toggle_fullscreen(), desc="Toggle fullscreen"),
    Key([mod], "t", lazy.window.toggle_floating(), desc="Toggle floating"),
    Key([mod, "control"], "r", lazy.reload_config(), desc="Reload CDE config"),
    Key([mod, "control"], "q", lazy.shutdown(), desc="Log out from CDE"),
]

groups = [Group(i) for i in "123456789"]
for group in groups:
    keys.extend(
        [
            Key([mod], group.name, lazy.group[group.name].toscreen(), desc=f"Switch to {group.name}"),
            Key(
                [mod, "shift"],
                group.name,
                lazy.window.togroup(group.name, switch_group=False),
                desc=f"Send window to {group.name}",
            ),
        ]
    )

layouts = [
    layout.Floating(
        border_focus=settings["accent"],
        border_normal=settings["border_normal"],
        border_width=settings["border_width"],
    )
]

widget_defaults = dict(
    font="sans",
    fontsize=13,
    padding=6,
    foreground=settings["text"],
    background=settings["bar_background"],
)
extension_defaults = widget_defaults.copy()

screens = [
    Screen(
        bottom=bar.Bar(
            [
                widget.TextBox(
                    text=" Apps ",
                    foreground=settings["accent"],
                    fontsize=14,
                    mouse_callbacks={"Button1": lazy.spawn(settings["launcher_fullscreen"])},
                ),
                widget.TextBox(
                    text=" Files ",
                    foreground=settings["text"],
                    fontsize=14,
                    mouse_callbacks={"Button1": lazy.spawn(settings["file_manager"])},
                ),
                widget.TextBox(
                    text=" Settings ",
                    foreground=settings["text"],
                    fontsize=14,
                    mouse_callbacks={"Button1": lazy.spawn("cde-settings")},
                ),
                widget.GroupBox(
                    highlight_method="block",
                    this_current_screen_border=settings["accent"],
                    active=settings["text"],
                    inactive="#565f89",
                ),
                widget.TaskList(highlight_method="block", border=settings["accent"]),
                widget.Spacer(),
                widget.Systray(),
                widget.Clock(format="%a %I:%M %p"),
            ],
            settings["bar_height"],
            background=settings["bar_background"],
        ),
        background=settings["background"],
    )
]

mouse = [
    Drag([mod], "Button1", lazy.window.set_position_floating(), start=lazy.window.get_position()),
    Drag([mod], "Button3", lazy.window.set_size_floating(), start=lazy.window.get_size()),
    Click([mod], "Button2", lazy.window.bring_to_front()),
]

dgroups_key_binder = None
dgroups_app_rules = []
follow_mouse_focus = True
bring_front_click = True
floats_kept_above = True
cursor_warp = False
floating_layout = layout.Floating(
    border_focus=settings["accent"],
    border_normal=settings["border_normal"],
    border_width=settings["border_width"],
    float_rules=[
        *layout.Floating.default_float_rules,
        Match(wm_class="confirmreset"),
        Match(wm_class="makebranch"),
        Match(wm_class="maketag"),
        Match(wm_class="ssh-askpass"),
        Match(title="branchdialog"),
        Match(title="pinentry"),
    ],
)
auto_fullscreen = True
focus_on_window_activation = "smart"
focus_previous_on_window_remove = False
reconfigure_screens = True
auto_minimize = True
wl_input_rules = None
wl_xcursor_theme = None
wl_xcursor_size = 24
wmname = "LG3D"
