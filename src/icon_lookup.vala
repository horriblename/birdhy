
public class IconLookup {
	static GLib.List<GLib.AppInfo> desktop_info = GLib.AppInfo.get_all();
	Gee.HashMap<string, weak GLib.Icon> cache = new Gee.HashMap<string, weak GLib.Icon>();
	// FIXME: idk how I should handle default icons
	GLib.Icon default_icon;

	public IconLookup() {
		try {
			this.default_icon = (!) GLib.Icon.new_for_string("application");
		} catch (Error e) {
			print("error finding icon 'application': %s", e.message);
		}

		foreach (var entry in this.desktop_info) {
			var id = entry.get_id() ?? "no_id";
		}
	}

	/// guesses icon from app_id (a.k.a window class)
	public unowned GLib.Icon find_icon(string app_id) {
		// GLib.Icon.get_id() returns "app_id.desktop" for some reason??
		string id = app_id + ".desktop";
		if (this.cache.has_key(id)) {
			return this.cache[id];
		}

		foreach (var entry in this.desktop_info) {
			string? maybe_entry_id = entry.get_id();
			if (maybe_entry_id == null) {
				continue;
			}
			string entry_id = (!) maybe_entry_id;
			if (entry_id == id) {
				weak GLib.Icon icon = entry.get_icon() ?? this.default_icon;
				this.cache.set(id, icon);
				return icon;
			}
		}

		print(@"[debug] no valid desktop entry found for: '$id'\n");
		this.cache.set(id, this.default_icon);
		return this.default_icon;
	}
} 

