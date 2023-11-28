namespace Birdhy {

public delegate U MapFunc<T, U>(T input);

public struct Result<T, E> {
	bool ok;
	E? err;
	T? val;

	public Result.Ok(T val) {
		this.ok = true;
		this.val = val;
	}

	public Result.Err(E err) {
		this.ok = false;
		this.err = err;
	}

	public T? maybe_ok() {
		return this.val;
	}

	public U map_both<U>(MapFunc<E, U> default, MapFunc<T, U> map) {
		if (this.ok) {
			return map(this.val);
		} else {
			return default(this.err);
		}
	}
}
}
