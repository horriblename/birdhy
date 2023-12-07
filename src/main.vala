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

Gtk.Widget view_workspace(Workspace ws, Vector2D ws_size, float scale) {
	var container = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
	var btn = new Gtk.Button();
	var canvas = new Gtk.Fixed();
	container.append(btn);
	container.add_css_class("workspace");
	container.set_hexpand(true);
	container.set_vexpand(true);
	// container.set_size_request(ws_size.x, ws_size.y);
	btn.set_child(canvas);
	btn.set_hexpand(true);
	btn.set_vexpand(true);
	canvas.set_hexpand(true);
	canvas.set_vexpand(true);

	btn.clicked.connect(() => {
		try {
			print(@"switching to workspace $(ws.id): ");
			GLib.Process.spawn_sync (null, {"hyprctl", "dispatch", "workspace", @"$(ws.id)"}, null, GLib.SpawnFlags.SEARCH_PATH, null, null, null, null);
		} catch (Error e) {
			print("Error switching workspace: %s", e.message);
		}
	});

	foreach (Client client in ws.clients) {
		var c = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		c.add_css_class("window");
		c.set_size_request(client.size[0], client.size[1]);
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

	var win_size = fit_to_box(
		active_mon.width * WORKSPACE_COLS / active_mon.height * WORKSPACE_ROWS,
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

	app.activate.connect(() => {
		var window = new Gtk.ApplicationWindow(app);

		GtkLayerShell.init_for_window(window);
		var margin_x = active_mon.width - win_size.x;
		var margin_y = active_mon.height - win_size.y;
		GtkLayerShell.set_namespace(window, "birdhy");
		GtkLayerShell.set_layer(window, GtkLayerShell.Layer.BOTTOM);
		window.set_size_request(win_size.x, win_size.y);
		window.set_default_size(win_size.x, win_size.y);
		

		var grid = new Gtk.Grid();
		grid.set_hexpand(true);
		grid.set_vexpand(true);
		grid.set_row_homogeneous(true);
		grid.set_column_homogeneous(true);

		// float client_scale = ((float) win_size.x - GAPS_IN * (WORKSPACE_COLS - 1) - 2 * GAPS_OUT) / WORKSPACE_COLS / active_mon.width;  
		float client_scale = ((float) win_size.x) / (float) WORKSPACE_COLS / (float) active_mon.width;  
		print(@"client scale: $client_scale\n");
		Vector2D ws_size = Vector2D((int)(win_size.x * client_scale), (int)(win_size.y * client_scale));
		// float ws_scale_y = (win_size.y - GAPS_IN * (WORKSPACE_ROWS - 1) - 2 * GAPS_OUT) / WORKSPACE_ROWS; 

		for (int row = 0; row < WORKSPACE_ROWS; row++) {
			for (int col = 0; col < WORKSPACE_COLS; col++) {
				var ws = view_workspace(workspaces[row, col], ws_size, client_scale);
				grid.attach(ws, col, row, 1, 1);
			}
		}

		window.set_child(grid);
		window.present();
	});

	app.run(null);
}
