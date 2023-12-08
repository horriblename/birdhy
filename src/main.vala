using Birdhy.Data;
using Gee;

const int WORKSPACE_COLS = 3;
const int WORKSPACE_ROWS = 2;

const float MAX_WIDTH = 0.8f;
const float MAX_HEIGHT = 0.8f;

const int GAPS_IN = 4;
const int GAPS_OUT = 10;

struct Workspace {
	int id;
	ArrayList<Client> clients;

	Workspace(int id, owned ArrayList<Client>? clients = null) {
		this.id = id;
		this.clients = clients ?? new ArrayList<Client>();
	}
}

void execute_command(string[] command) {
	try {
		GLib.Process.spawn_sync(
			null,
			command,
			null,
			GLib.SpawnFlags.SEARCH_PATH,
			null,
			null,
			null,
			null
		);
	} catch (Error e) {
		print("Error executing a command: %s", e.message);
	}
}

Gtk.Widget view_workspace(
	IconLookup icon_lookup,
	Gtk.Window window,
	Workspace ws,
	Vector2D ws_size,
	float scale
) {
	var container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
	var btn = new Gtk.Button();
	var canvas = new Gtk.Fixed();
	var drop_controller = new Gtk.DropTarget(typeof(string), Gdk.DragAction.COPY);
	drop_controller.drop.connect((address) => {
		var arg = @"$(ws.id),address:$(address.get_string())";
		print(@"sending movetoworkspace with arg $arg\n");
		execute_command({
			"hyprctl",
			"dispatch",
			"movetoworkspacesilent",
			// TODO: idk if GLib.Value.get_string() can fail
			@"$(ws.id),address:$(address.get_string())"
		});
		return true;
	});
	container.add_controller(drop_controller);
	container.append(btn);
	container.add_css_class("workspace");
	container.add_css_class("flat");
	container.set_hexpand(true);
	container.set_vexpand(true);
	btn.set_child(canvas);
	btn.set_hexpand(true);
	btn.set_vexpand(true);
	canvas.set_hexpand(true);
	canvas.set_vexpand(true);

	btn.clicked.connect(() => {
		try {
			print(@"switching to workspace $(ws.id): ");
			GLib.Process.spawn_sync(
				null,
				{"hyprctl",
				"dispatch",
				"workspace",
				@"$(ws.id)"},
				null,
				GLib.SpawnFlags.SEARCH_PATH,
				null,
				null,
				null,
				null
			);
		} catch (Error e) {
			print("Error switching workspace: %s", e.message);
		}
		window.close();
	});

	foreach (Client client in ws.clients) {
		var c = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var b = new Gtk.Button();
		var drag_controller = new Gtk.DragSource();
		c.add_css_class("window");
		c.add_css_class("frame");

		// doesn't work, click events go to parent button
		b.clicked.connect(() => {
			try {
				GLib.Process.spawn_sync(
					null,
					{"hyprctl", "dispatch", "focuswindow", @"address:$(client.address)"},
					null,
					GLib.SpawnFlags.SEARCH_PATH,
					null,
					null,
					null,
					null
				);
			} catch (Error e) {
				print("Error switching workspace: %s", e.message);
			}
			window.close();
		});

		GLib.Value addr_value = new GLib.Value(typeof(string));
		addr_value.set_string(client.address);
		drag_controller.set_content(new Gdk.ContentProvider.for_value(addr_value));
		b.add_controller(drag_controller);
		
		b.set_child(new Gtk.Image.from_gicon(icon_lookup.find_icon(client.class_)));
		b.set_vexpand(true);
		b.set_hexpand(true);
		b.set_focusable(false);
		c.append(b);
		c.set_size_request((int) (client.size[0] * scale), (int)(client.size[1] * scale));
		canvas.put(c, client.at[0] * scale, client.at[1] * scale);
	}

	return container;
}

struct Vector2D {
	public int x;
	public int y;

	public Vector2D(int x, int y) {
		this.x = x;
		this.y = y;
	}
}

// fit window to a width and height limit, aspect_ratio = width / height
// returns the final window size
Vector2D fit_to_box(float aspect_ratio, int width_limit, int height_limit) {
	var width = aspect_ratio * height_limit;
	if (width > width_limit) {
		return Vector2D(width_limit, (int)(width_limit / aspect_ratio));
	} else {
		return Vector2D((int) width, height_limit);
	}
}

void main() {
	var app = new Gtk.Application("com.github.horriblename.birdhy", GLib.ApplicationFlags.FLAGS_NONE);

	Monitor active_mon;
	{
		Monitor? active_mon0 = null;
		var monitors = get_monitors().maybe_ok().take();
		foreach (Monitor monitor in monitors) {
			if (monitor.focused) {
				active_mon0 = monitor;
				break;
			}
		}
		active_mon = active_mon0 ?? monitors[0];
	}

	var window_aspect_ratio = (float) active_mon.width * WORKSPACE_COLS / ((float) active_mon.height * WORKSPACE_ROWS);
	var win_size = fit_to_box(
		window_aspect_ratio,
		(int) (active_mon.width * MAX_WIDTH),
		(int) (active_mon.height * MAX_HEIGHT)
	);

	Workspace[,] workspaces = new Workspace[WORKSPACE_ROWS, WORKSPACE_COLS];

	for (int i = 0; i < WORKSPACE_COLS * WORKSPACE_ROWS; i++) {
		workspaces[i/WORKSPACE_COLS, i % WORKSPACE_COLS] = Workspace(i+1);
	}

	var clients = get_clients().maybe_ok();

	// add clients to their respective workspace
	foreach (Client client in clients.clients) {
		var ws_id = client.workspace.id - 1;
		if (ws_id < 0 || !client.mapped || client.hidden) {
			continue;
		}
		var i = ws_id / WORKSPACE_COLS;
		var j = ws_id % WORKSPACE_COLS;
		if (i < WORKSPACE_ROWS) {
			workspaces[i, j].clients.add(client);
		}
	}

	var icon_lookup = new IconLookup();

	app.activate.connect(() => {
		var window = new Gtk.ApplicationWindow(app);

		GtkLayerShell.init_for_window(window);
		GtkLayerShell.set_namespace(window, "birdhy");
		GtkLayerShell.set_layer(window, GtkLayerShell.Layer.TOP);
		GtkLayerShell.set_keyboard_mode(window, GtkLayerShell.KeyboardMode.EXCLUSIVE);
		window.set_size_request(win_size.x, win_size.y);
		window.set_default_size(win_size.x, win_size.y);
		
		var key_controller = new Gtk.EventControllerKey();
		key_controller.key_pressed.connect((key) => {
			if (key == Gdk.Key.Escape) {
				print("escape pressed\n");
				window.close();
				return true;
			}
			return false;
		});

		var grid = new Gtk.Grid();
		grid.set_hexpand(true);
		grid.set_vexpand(true);
		grid.set_row_spacing(16);
		grid.set_column_spacing(16);
		grid.set_margin_start(16);
		grid.set_margin_end(16);
		grid.set_margin_top(16);
		grid.set_margin_bottom(16);
		grid.set_row_homogeneous(true);
		grid.set_column_homogeneous(true);
		grid.add_controller(key_controller);

		// float client_scale = ((float) win_size.x - GAPS_IN * (WORKSPACE_COLS - 1) - 2 * GAPS_OUT) / WORKSPACE_COLS / active_mon.width;  
		float client_scale = ((float) win_size.x) / (float) WORKSPACE_COLS / (float) active_mon.width;  
		Vector2D ws_size = Vector2D((int)(win_size.x * client_scale), (int)(win_size.y * client_scale));
		// float ws_scale_y = (win_size.y - GAPS_IN * (WORKSPACE_ROWS - 1) - 2 * GAPS_OUT) / WORKSPACE_ROWS; 

		for (int row = 0; row < WORKSPACE_ROWS; row++) {
			for (int col = 0; col < WORKSPACE_COLS; col++) {
				var ws = view_workspace(
					icon_lookup,
					window,
					workspaces[row, col],
					ws_size,
					client_scale
				);
				grid.attach(ws, col, row, 1, 1);
			}
		}

		window.set_child(grid);
		window.present();
	});

	app.run(null);
}
