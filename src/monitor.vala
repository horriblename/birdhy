using Birdhy;

namespace Birdhy.Data {
public class Monitor {
	public int id;
	public int width;
	public int height;
	public bool focused;
	public Workspace active_workspace {get; private set;}

	public Monitor.from_json(JSON.Value val) throws JSON.TypeError {
		var dict = val.get_dict();
		this.id = dict.get("id").get_int();
		this.width = dict.get("width").get_int();
		this.height = dict.get("height").get_int();
		this.focused = dict.get("focused").get_bool();
		this.active_workspace = Workspace(
			dict.get("activeWorkspace").get_dict().get("id").get_int(),
			dict.get("activeWorkspace").get_dict().get("name").get_string()
		);
	}

	public string to_string() {
		return string.join(
			"\n",
			@"id: $id",
			@"width: $width",
			@"height: $height",
			@"focused: $focused",
			@"active_workspace: $(active_workspace.id)"
		);
	}
}

// simple wrapper cuz generics can't have Arrays
public class Monitors {
	public Monitor[] monitors {get; private set;}

	public Monitors(owned Monitor[] mons) {
		this.monitors = mons;
	}

	public Monitor[] take() {
		return this.monitors;
	}
}

public errordomain MonitorError {
	SPAWN_ERROR, DESERILIZE_ERROR
}

public Result<Monitors, MonitorError> get_monitors() {
	string stdout;
	try {
		Process.spawn_sync (
			null,
			{"hyprctl", "-j", "monitors"},
			null,
			SpawnFlags.SEARCH_PATH,
			null,
			out stdout,
			null,
			null
		);
	} catch (SpawnError e) {
		return Result<Monitors, MonitorError>.Err(new MonitorError.SPAWN_ERROR(e.message));
	}

	try {
		var root = JSON.parse_json(stdout);
		var arr = root.get_array();

		var monitors = new Monitor[arr.length];

		for (int i = 0; i < arr.length; i++) {
			Monitor mon = new Monitor.from_json(arr[i]);
			monitors[i] = mon;
		}

		return Result<Monitors, MonitorError>.Ok(new Monitors(monitors));
	} catch (Error e) {
		print(@"Error: $(e.message)\n");
		return Result<Monitors, MonitorError>.Err(new MonitorError.DESERILIZE_ERROR(e.message));
	}
}
}
