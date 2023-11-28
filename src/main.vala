using Birdhy.Data;
// using Birdhy.Json;

void main() {
	var app = new Gtk.Application("com.github.horriblename.birdhy", GLib.ApplicationFlags.FLAGS_NONE);

	app.activate.connect(() => {
		var window = new Gtk.ApplicationWindow(app);

		window.present();
	});

	var clients = get_clients().maybe_ok();

	foreach (var client in clients.clients) {
		print(@"client: $client");
	}

	app.run(null);
}


