using GLib;
using Birdhy;
using Birdhy.JSON;

namespace Birdhy.Data {
public struct Workspace {
	int id;
	string name;
}

public class Client : Object {
	public bool mapped;
	public bool hidden;
	public int at[2];
	public int size[2];
	public Workspace workspace {get; private set;}
	public bool floating;
	public string class_;
	public string title;

	public Client.from_json(JSON.Value obj) throws JSON.TypeError {
		var dict = obj.get_dict();
		this.mapped = dict.get("mapped").get_bool();
		this.hidden = dict.get("hidden").get_bool();
		this.at[0] = dict.get("at").get_array()[0].get_int();
		this.at[1] = dict.get("at").get_array()[1].get_int();
		this.size[0] = dict.get("size").get_array()[0].get_int();
		this.size[1] = dict.get("size").get_array()[1].get_int();
		this.workspace.id = dict.get("workspace").get_dict().get("id").get_int();
		this.workspace.name = dict.get("workspace").get_dict().get("name").get_string();
		this.floating = dict.get("floating").get_bool();
		this.class_ = dict.get("class").get_string();
		this.title = dict.get("title").get_string();
	}

	public string to_string() {
		return string.join(
			"\n",
			@"class: $class_",
			@"    mapped: $mapped",
			@"    hidden: $hidden",
			@"    at: [$(at[0]), $(at[1])]",
			@"    size: [$(size[0]), $(size[1])]",
			@"    workspace: $(workspace.id)",
			@"    floating: $floating",
			@"    title: $title\n"
		);
	}
}

/// Needed cuz "Arrays are not supported as generic parameter"
public class Clients {
	public Client[] clients;

	public Clients(Client[] cs) {
		this.clients = cs;
	}
}

public enum ClientError {
	SPAWN_ERROR,
	DESERILIZE_ERROR,
	EXPECTED_ARRAY,
	EMPTY_INPUT_STRING;
}


// deserializing to gobject is so fucking painful that I gave up
public Result<Clients, ClientError> get_clients() {
	string stdout;
	try {
		Process.spawn_sync (
			null,
			{"hyprctl", "-j", "clients"},
			null,
			SpawnFlags.SEARCH_PATH,
			null,
			out stdout,
			null,
			null
		);
	} catch (SpawnError e) {
		return Result<Clients, ClientError>.Err(ClientError.SPAWN_ERROR);
	}

	try {
		var root = JSON.parse_json(stdout);
		var arr = root.get_array();

		var clients = new Client[arr.length];

		for (int i = 0; i < arr.length; i++) {
			Client client = new Client.from_json(arr[i]);
			clients[i] = client;
		}

		return Result<Clients, ClientError>.Ok(new Clients(clients));
	} catch (Error e) {
		print(@"Error: $(e.message)\n");
		return Result<Clients, ClientError>.Err(ClientError.DESERILIZE_ERROR);
	}
}
}
