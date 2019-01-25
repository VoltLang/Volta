module vec;

struct Vec!(N: size_t, T) {
	values: T[N];

	local fn create(x: T, y: T, z: T)  Vec {
		v: Vec;
		v.x = x;
		v.y = y;
		v.z = z;
		return v;
	}

	@property fn x() T { return values[0]; }
	@property fn x(v: T) { values[0] = v; }
	@property fn r() T { return values[0]; }
	@property fn r(v: T) { values[0] = v; }
	@property fn y() T { return values[1]; }
	@property fn y(v: T) { values[1] = v; }
	@property fn g() T { return values[1]; }
	@property fn g(v: T) { values[1] = v; }
	@property fn z() T { return values[2]; }
	@property fn z(v: T) { values[2] = v; }
	@property fn b() T { return values[2]; }
	@property fn b(v: T) { values[2] = v; }
	@property fn w() T { return values[3]; }
	@property fn w(v: T) { values[3] = v; }
	@property fn a() T { return values[3]; }
	@property fn a(v: T) { values[3] = v; }

	fn opMul(scalar: T) Vec {
		newVec: Vec;
		for (size_t i = 0; i < N; ++i) {
			newVec.values[i] = values[i] * scalar;
		}
		return newVec;
	}

	fn opMul(ref in vector: Vec) Vec {
		newVec: Vec;
		for (i: size_t = 0; i < N; ++i) {
			newVec.values[i] = values[i] * vector.values[i];
		}
		return newVec;
	}

	fn opNeg() Vec {
		newVec: Vec;
		for (size_t i = 0; i < N; ++i) {
			newVec.values[i] = -values[i];
		}
		return newVec;
	}
}

struct Vec3 = mixin Vec!(3, f64);
