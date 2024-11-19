/*
 * Copyright 2023-2024 elementary, Inc (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-only
 */

public sealed class Terminal.SettingsPopover : Gtk.Popover {
    public signal void show_theme_editor ();

    public TerminalWidget? terminal {
        owned get {
            return terminal_binding.source as TerminalWidget;
        }

        set {
            terminal_binding.source = value;
        }
    }

    private const string STYLE_CSS = """
        .color-button.%s radio {
            background-color: %s;
            color: %s;
        }
    """;

    private BindingGroup terminal_binding;
    public Gtk.Box theme_buttons { get; private set; }

    public SettingsPopover () {
        Object ();
    }

    construct {
        var zoom_out_button = new Gtk.Button.from_icon_name ("zoom-out-symbolic") {
            tooltip_markup = Granite.markup_accel_tooltip (
                TerminalWidget.ACCELS_ZOOM_OUT,
                _("Zoom out")
            )
        };

        zoom_out_button.clicked.connect (() => terminal.decrease_font_size ());

        var zoom_default_button = new Gtk.Button () {
            tooltip_markup = Granite.markup_accel_tooltip (
                TerminalWidget.ACCELS_ZOOM_DEFAULT,
                _("Default zoom level")
            )
        };

        zoom_default_button.clicked.connect (() => terminal.default_font_size ());

        var zoom_in_button = new Gtk.Button.from_icon_name ("zoom-in-symbolic") {
            tooltip_markup = Granite.markup_accel_tooltip (
                TerminalWidget.ACCELS_ZOOM_IN,
                _("Zoom in")
            )
        };

        zoom_in_button.clicked.connect (() => terminal.increase_font_size ());

        var font_size_box = new Gtk.Box (HORIZONTAL, 0) {
            homogeneous = true,
            hexpand = true,
            margin_start = 12,
            margin_end = 12,
            margin_bottom = 6
        };
        font_size_box.append (zoom_out_button);
        font_size_box.append (zoom_default_button);
        font_size_box.append (zoom_in_button);

        font_size_box.add_css_class (Granite.STYLE_CLASS_LINKED);

        theme_buttons = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0) {
            homogeneous = true,
            margin_bottom = 6,
            margin_top = 6
        };

        var theme_revealer = new Gtk.Revealer () {
            child = theme_buttons
        };

        var follow_system_button = new Granite.SwitchModelButton (_("Follow System Style")) {
            active = Application.settings.get_boolean ("follow-system-style"),
        };

        var theme_box = new Gtk.Box (VERTICAL, 0);
        theme_box.append (follow_system_button);
        theme_box.append (theme_revealer);

        var hc_button = add_theme_button (Themes.HIGH_CONTRAST);
        hc_button.tooltip_text = _("High Contrast");

        var light_button = add_theme_button (Themes.LIGHT);
        light_button.tooltip_text = _("Solarized Light");
        light_button.group = hc_button;

        var dark_button = add_theme_button (Themes.DARK);
        dark_button.tooltip_text = _("Dark");
        dark_button.group = hc_button;

        Gtk.CssProvider custom_button_provider;
        var custom_button = add_theme_button (Themes.CUSTOM, out custom_button_provider);
        custom_button.tooltip_text = _("Custom");
        custom_button.group = hc_button;

        update_active_colorbutton (dark_button, Application.settings.get_string ("theme"));

        var natural_copy_paste_button = new Granite.SwitchModelButton (_("Natural Copy/Paste")) {
            description = _("Shortcuts don’t require Shift; may interfere with CLI apps"),
            active = Application.settings.get_boolean ("natural-copy-paste")
        };

        var unsafe_paste_alert_button = new Granite.SwitchModelButton (_("Unsafe Paste Alert")) {
            description = _("Warn when pasted text contains multiple or administrative commands"),
            active = Application.settings.get_boolean ("unsafe-paste-alert")
        };

        var audible_bell_button = new Granite.SwitchModelButton (_("Event Alerts")) {
            description = _("Notify for invalid input or multiple possible completions (subject to System Settings → Sound)"),
            active = Application.settings.get_boolean ("audible-bell")
        };

        var box = new Gtk.Box (VERTICAL, 6) {
            margin_bottom = 6,
            margin_top = 12,
        };

// <<<<<<< HEAD
        box.append (font_size_box);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (theme_box);
        box.append (new Gtk.Separator (HORIZONTAL));
        box.append (natural_copy_paste_button);
        box.append (unsafe_paste_alert_button);
        box.append (audible_bell_button);
// =======
//         box.add (font_size_box);
//         box.add (new Gtk.Separator (HORIZONTAL));
//         box.add (theme_box);
//         box.add (new Gtk.Separator (HORIZONTAL));
//         box.add (natural_copy_paste_button);
//         box.add (unsafe_paste_alert_button);
//         box.add (audible_bell_button);
// >>>>>>> master
        child = box;

        custom_button.toggled.connect (() => {
            if (custom_button.active) {
                show_theme_editor ();
                popdown ();
            }
        });

        terminal_binding = new BindingGroup ();
        terminal_binding.bind_property ("font-scale", zoom_default_button, "label", SYNC_CREATE, font_scale_to_zoom);

        follow_system_button.bind_property ("active", theme_revealer, "reveal-child", SYNC_CREATE | INVERT_BOOLEAN);

        Application.settings.bind ("follow-system-style", follow_system_button, "active", DEFAULT);
        Application.settings.bind ("natural-copy-paste", natural_copy_paste_button, "active", DEFAULT);
        Application.settings.bind ("unsafe-paste-alert", unsafe_paste_alert_button, "active", DEFAULT);
        Application.settings.bind ("audible-bell", audible_bell_button, "active", DEFAULT);

        Application.settings.changed.connect ((s, n) => {
            if (n == "background" || n == "foreground") {
                update_theme_provider (custom_button_provider, Themes.CUSTOM);
            } else if (n == "theme") {
                update_active_colorbutton (dark_button, s.get_string (n));
            }
        });
    }

    private Gtk.CheckButton add_theme_button (string theme, out Gtk.CssProvider css_provider = null) {
        var button = new Gtk.CheckButton () {
            halign = Gtk.Align.CENTER
        };

        button.set_data<string> ("theme", theme);
        button.add_css_class ("color-button");
        button.add_css_class (theme);

        css_provider = new Gtk.CssProvider ();
        Gtk.StyleContext.add_provider_for_display (
            Gdk.Display.get_default (),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1
        );

        update_theme_provider (css_provider, theme);

        button.toggled.connect ((b) => {
            if (((Gtk.CheckButton) b).active) {
                Application.settings.set_value ("theme", b.get_data<string> ("theme"));
            }
        });

        theme_buttons.append (button);
        return button;
    }

    private void update_active_colorbutton (Gtk.CheckButton default_button, string theme) {
        var child = theme_buttons.get_first_child ();
        var found = false;
        while (child != null && !found) {
            if (child is Gtk.CheckButton) {
                var b = (Gtk.CheckButton)child;
                if (b.get_data<string> ("theme") == theme) {
                    b.active = true;
                    return;
                }
            }

            child = child.get_next_sibling ();
        }

        default_button.active = true;
    }

    private static void update_theme_provider (Gtk.CssProvider css_provider, string theme) {
        var theme_palette = Themes.get_rgba_palette (theme);
        var background = theme_palette[Themes.PALETTE_SIZE - 3].to_string ();
        var foreground = theme_palette[Themes.PALETTE_SIZE - 2].to_string ();
        css_provider.load_from_string (STYLE_CSS.printf (theme, background, foreground));
    }

    private static bool font_scale_to_zoom (Binding binding, Value font_scale, ref Value label) {
        label.set_string ("%.0f%%".printf (font_scale.get_double () * 100));
        return true;
    }
}
