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
		print("Error executing command: %s\nerror: %s",
			string.joinv(" ", command),
			e.message
		);
	}
}

Gtk.Widget view_workspace(
	IconLookup icon_lookup,
	Gtk.Window window,
	Workspace ws,
	Vector2D ws_size,
	float scale
) {
	var btn = new Gtk.Button();
	var canvas = new Gtk.Fixed();
	var drop_controller = new Gtk.DropTarget(typeof(string), Gdk.DragAction.COPY);
	drop_controller.drop.connect((address) => {
		execute_command({
			"hyprctl",
			"dispatch",
			"movetoworkspacesilent",
			// TODO: idk if GLib.Value.get_string() can fail
			@"$(ws.id),address:$(address.get_string())"
		});
		return true;
	});
	btn.add_controller(drop_controller);
	btn.add_css_class("workspace");
	btn.add_css_class("flat");
	btn.set_child(canvas);
	btn.set_hexpand(true);
	btn.set_vexpand(true);
	canvas.set_hexpand(true);
	canvas.set_vexpand(true);

	btn.clicked.connect(() => {
		execute_command({"hyprctl", "dispatch", "workspace", @"$(ws.id)"});
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
			execute_command({"hyprctl", "dispatch", "focuswindow", @"address:$(client.address)"});
			window.close();
		});

		GLib.Value addr_value = GLib.Value(typeof(string));
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

	return btn;
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

class BirdhyApp : Gtk.Window {
	Workspace[,] workspaces = new Workspace[WORKSPACE_ROWS, WORKSPACE_COLS];
	IconLookup icon_lookup = new IconLookup();
	GLib.Array<weak Gtk.Button> ws_widgets;

	public BirdhyApp() {
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

		for (int i = 0; i < WORKSPACE_COLS * WORKSPACE_ROWS; i++) {
			workspaces[i/WORKSPACE_COLS, i % WORKSPACE_COLS] = Workspace(i+1);
		}

		this.update_clients_data();

		var window = (!) (this as Gtk.Window);

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

		this.ws_widgets = new GLib.Array<weak Gtk.Button>();
		for (int row = 0; row < WORKSPACE_ROWS; row++) {
			for (int col = 0; col < WORKSPACE_COLS; col++) {
				var ws = this.build_workspace_view(
					row*3 + col,
					ws_size,
					client_scale
				);
				this.ws_widgets.append_val(ws);
				grid.attach(ws, col, row, 1, 1);
			}
		}

		window.set_child(grid);
		window.present();
	}

	// fetches clients and update this.workspace
	// ws_mask marks which workspace(s) should be updated, e.g. {false, true, true} means the workspaces 3 and 4 
	// should be updated. null (default) means all workspaces are updated
	void update_clients_data(bool[]? ws_mask = null) {
		var clients = get_clients().maybe_ok();

		// add clients to their respective workspace
		foreach (Client client in clients.clients) {
			var ws_index = client.workspace.id - 1;
			if (ws_index < 0 || !client.mapped || client.hidden) {
				continue;
			}
			// will list[out_of_range_index] crash?
			if (ws_mask != null && ((!)ws_mask)[ws_index] == false) {
				continue;
			}
			var i = ws_index / WORKSPACE_COLS;
			var j = ws_index % WORKSPACE_COLS;
			if (i < WORKSPACE_ROWS) {
				this.workspaces[i, j].clients.add(client);
			}
		}
	}

	Gtk.Button build_workspace_view(int ws_index, Vector2D ws_size, float scale) {
		var ws = this.workspaces[ws_index / WORKSPACE_COLS, ws_index % WORKSPACE_COLS];
		var btn = new Gtk.Button();
		var drop_controller = new Gtk.DropTarget(typeof(string), Gdk.DragAction.COPY);
		drop_controller.drop.connect((address) => {
			execute_command({
				"hyprctl",
				"dispatch",
				"movetoworkspacesilent",
				// TODO: idk if GLib.Value.get_string() can fail
				@"$(ws.id),address:$(address.get_string())"
			});
			return true;
		});
		btn.add_controller(drop_controller);
		btn.add_css_class("workspace");
		btn.add_css_class("flat");
		btn.set_hexpand(true);
		btn.set_vexpand(true);
		btn.clicked.connect(() => {
			execute_command({"hyprctl", "dispatch", "workspace", @"$(ws.id)"});
			this.close();
		});

		this.update_workspace_view(btn, ws, scale);
		return btn;
	}

	void update_workspace_view(Gtk.Button btn, Workspace ws, float scale) {
		var canvas = new Gtk.Fixed();
		btn.set_child(canvas);
		canvas.set_hexpand(true);
		canvas.set_vexpand(true);

		foreach (Client client in ws.clients) {
			var c = build_client_view(client, scale);
			canvas.put(c, client.at[0] * scale, client.at[1] * scale);
		}
	}

	Gtk.Widget build_client_view(Client client, float scale) {
		var c = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 0);
		var b = new Gtk.Button();
		var drag_controller = new Gtk.DragSource();
		c.add_css_class("window");
		c.add_css_class("frame");

		// doesn't work, click events go to parent button
		b.clicked.connect(() => {
			execute_command({"hyprctl", "dispatch", "focuswindow", @"address:$(client.address)"});
			this.close();
		});

		GLib.Value addr_value = GLib.Value(typeof(string));
		addr_value.set_string(client.address);
		drag_controller.set_content(new Gdk.ContentProvider.for_value(addr_value));
		b.add_controller(drag_controller);

		b.set_child(new Gtk.Image.from_gicon(icon_lookup.find_icon(client.class_)));
		b.set_vexpand(true);
		b.set_hexpand(true);
		b.set_focusable(false);
		c.append(b);
		c.set_size_request((int) (client.size[0] * scale), (int)(client.size[1] * scale));
		
		return c;
	}
}

void main() {
	var app = new Gtk.Application("com.github.horriblename.birdhy", GLib.ApplicationFlags.FLAGS_NONE);

	app.activate.connect(() => {
		app.add_window(new BirdhyApp());
	});

	app.run(null);
}
