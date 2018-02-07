// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/charge/license.volt (BOOST ver. 1.0).
module vrt.vacuum.aa;

import core.compiler.llvm: __llvm_memcpy;
import core.rt.gc: allocDg;
import core.rt.misc: vrt_memcmp;
import core.typeinfo;


struct HashMapInteger!(K, V, SB, F: f64)
{
public:
	alias Key = K;
	alias Value = V;
	alias HashType = u64;
	alias Distance = u8;
	alias SizeBehaviour = SB;
	enum Factor : f64 = F;


private:
	static assert(typeid(Key).size <= typeid(HashType).size);

	mKeys: Key[];
	mValues: Value[];
	mDistances: Distance[];
	mNumEntries: size_t;
	mGrowAt: size_t;
	mSize: SizeBehaviour;
	mTries: i32;


public:
	/*!
	 * Copy from given hash map.
	 */
	fn dup(old: HashMapInteger)
	{
		mKeys = new old.mKeys[..];
		mValues = new old.mValues[..];
		mDistances = new old.mDistances[..];
		mNumEntries = old.mNumEntries;
		mGrowAt = old.mGrowAt;
		mSize = old.mSize;
		mTries = old.mTries;
	}

	/*!
	 * Optionally initialise the hash map with a minimum number of elements.
	 */
	fn setup(size: size_t)
	{
		size = cast(size_t)(size / Factor);
		entries := mSize.setStarting(size);

		allocArrays(entries);
	}

	/*!
	 * Simpler helper for getting values,
	 * returns `Value.init` if the key was not found.
	 */
	fn getOrInit(key: Key) Value
	{
		def: Value;
		find(key, out def);
		return def;
	}

	//! Get the keys from this AA.
	fn keys(ti: TypeInfo) void[]
	{
		arr := allocDg(ti, mNumEntries)[0 .. mNumEntries * ti.size];
		currentIndex: size_t;
		foreach (i, distance; mDistances) {
			if (distance == 0) {
				continue;
			}
			__llvm_memcpy(&arr[currentIndex], cast(void*)&mKeys[i], ti.size, 0, false);
			currentIndex += ti.size;
		}
		return arr;
	}

	//! Get the values from this AA.
	fn values(aa: AA*) void[]
	{
		ti := aa.valuetid;
		arr := allocDg(ti, mNumEntries)[0 .. mNumEntries * ti.size];
		currentIndex: size_t;
		foreach (i, distance; mDistances) {
			if (distance == 0) {
				continue;
			}
			aa.writeToPtr(&arr[currentIndex], mValues[i]);
			currentIndex += ti.size;
		}
		return arr;
	}

	/*!
	 * Find the given key in this hashmap, return a pointer to the value if
	 * found, null otherwise.
	 *
	 * @Param[in] key  The key to look for.
	 * @Return A pointer to the value or null if not found.
	 */
	fn findPtr(key: Key) Value*
	{
		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			if (distanceForIndex == 0) {
				return null;
			}

			if (distanceForIndex == distance &&
			    mKeys.ptr[index] == key) {
				return &mValues.ptr[index];
			}
		}

		return null;
	}

	/*!
	 * Find the given key in this hashmap, return true if found and sets
	 * ret to the value at the key.
	 *
	 * @Param[in] key  The key to look for.
	 * @Param[out] ret The value at key or default value for Value.
	 * @Return True if found false otherwise.
	 */
	fn find(key: Key, out ret: Value) bool
	{
		ptr := findPtr(key);
		if (ptr is null) {
			return false;
		}
		ret = *ptr;
		return true;
	}

	/*!
	 * Adds the given key value pair to the hashmap, replacing any value
	 * with the same key if it was in the map.
	 *
	 * @Param[in] key   The key for the value.
	 * @Param[in] value The value to add.
	 */
	fn add(key: Key, value: Value)
	{
		// They both start at zero, make sure we grow the hashmap then.
		if (mNumEntries >= mGrowAt) {
			grow();
		}

		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			// If we found a empty slot 
			if (distanceForIndex == 0) {
				mDistances.ptr[index] = cast(Distance)distance;
				mValues.ptr[index] = value;
				mKeys.ptr[index] = key;
				mNumEntries++;
				return;
			}

			// If the distances match compare keys.
			if (distanceForIndex == distance &&
			    mKeys.ptr[index] == key) {
				mValues.ptr[index] = value;
				return;
			}

			// This element doesn't match, and is poorer then us.
			if (distanceForIndex >= distance) {
				continue;
			}

			// This entry is richer then us, replace it.
			tmpKey := mKeys.ptr[index];
			tmpValue := mValues.ptr[index];

			mDistances.ptr[index] = cast(Distance)distance;
			mValues.ptr[index] = value;
			mKeys.ptr[index] = key;

			return add(tmpKey, tmpValue);
		}

		grow();

		add(key, value);
	}

	/*!
	 * Remove the given key and value associated with that key from the map.
	 *
	 * @Param[in] key The key to remove.
	 * @Returns True if the key was removed.
	 */
	fn remove(key: Key) bool
	{
		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			if (distanceForIndex == distance &&
			    mKeys.ptr[index] == key) {
				removeAt(index);
				mNumEntries--;
				return true;
			}
		}

		return false;
	}


public:
	/*!
	 * Grows the internal arrays.
	 */
	fn grow()
	{
		oldNumEntries := mNumEntries;
		oldDistances := mDistances;
		oldValues := mValues;
		oldKeys := mKeys;

		entries := mSize.getNextSize();
		allocArrays(entries);

		foreach (index, distanceForIndex; oldDistances) {
			if (distanceForIndex == 0) {
				continue;
			}

			add(oldKeys[index], oldValues[index]);
		}
	}

	/*!
	 * Allocate new set of arrays, reset all fields that
	 * tracks the contents of the said arrays.
	 */
	fn allocArrays(entries: size_t)
	{
		// Arrays are complete
		mNumEntries = 0;
		mTries = cast(Distance)log2(cast(u32)entries);

		numElements := entries + cast(u32)mTries + 2;

		mGrowAt = cast(size_t)(entries * Factor);
		mKeys = new Key[](numElements);
		mValues = new Value[](numElements);
		mDistances = new Distance[](numElements);
	}


	/*
	 *
	 * Functions for doing operations at indicies.
	 *
	 */

	/*!
	 * Remove the entry at the given index, and move
	 * entries that are poor into the now free slot.
	 */
	fn removeAt(index: size_t)
	{
		next := index + 1;
		while (wantsToGetRicher(next)) {
			mDistances.ptr[index] = cast(Distance)(mDistances.ptr[next] - 1u);
			mValues.ptr[index] = mValues.ptr[next];
			mKeys.ptr[index] = mKeys.ptr[next];
			next++;
			index++;
		}

		/* If we don't enter the loop above `index` points at the
		 * original index that was supplied.
		 * If we have entered the loop, it points to `next`.
		 */
		clearAt(index);
	}

	/*!
	 * This function clears a single entry and does not do any moving.
	 */
	fn clearAt(index: size_t)
	{
		mDistances.ptr[index] = 0;
		mValues.ptr[index] = Value.init;
		mKeys.ptr[index] = Key.init;
	}


	/*
	 * Helper functions.
	 */

	/*!
	 * Returns `true` if the entry at `index` can be moved
	 * closer to where it wants to reside.
	 */
	fn wantsToGetRicher(index: size_t) bool
	{
		distanceForIndex := mDistances.ptr[index];

		// 0 == empty, so no.
		// 1 == prefered location.
		// 2 >= wants to get richer.
		return distanceForIndex > 1;
	}

	/*!
	 * Helper function to go from a key to a hash value.
	 */
	global fn makeHash(key: Key) u64
	{
		// This is the fastest but only works if key is integer.
		return cast(u64)key;
	}
}

struct HashMapArray!(KE, V, SB, F: f64)
{
public:
	alias KeyElement = KE;
	alias Key = scope const(KeyElement)[];
	alias Value = V;
	alias Distance = u8;
	alias SizeBehaviour = SB;
	enum Factor : f64 = F;


private:
	mKeys: Key[];
	mValues: Value[];
	mDistances: Distance[];
	mNumEntries: size_t;
	mGrowAt: size_t;
	mSize: SizeBehaviour;
	mTries: i32;


public:
	/*!
	 * Copy from old hash map.
	 */
	fn dup(old: HashMapArray)
	{
		mKeys = new old.mKeys[..];
		mValues = new old.mValues[..];
		mDistances = new old.mDistances[..];
		mNumEntries = old.mNumEntries;
		mGrowAt = old.mGrowAt;
		mSize = old.mSize;
		mTries = old.mTries;
	}

	/*!
	 * Optionally initialise the hash map with a minimum number of elements.
	 */
	fn setup(size: size_t)
	{
		size = cast(size_t)(size / Factor);
		entries := mSize.setStarting(size);

		allocArrays(entries);
	}

	/*!
	 * Simpler helper for getting values,
	 * returns `Value.init` if the key was not found.
	 */
	fn getOrInit(key: Key) Value
	{
		def: Value;
		find(key, out def);
		return def;
	}

	//! Get the keys for this AA, given the key is ptr typed.
	fn ptrKeys(ti: TypeInfo) void[]
	{
		arr := allocDg(ti, mNumEntries)[0 .. mNumEntries * ti.size];
		currentIndex: size_t;
		foreach (i, distance; mDistances) {
			if (distance == 0) {
				continue;
			}
			__llvm_memcpy(&arr[currentIndex], cast(void*)mKeys[i].ptr, ti.size, 0, false);
			currentIndex += ti.size;
		}
		return arr;
	}

	//! Get the (array) keys for this AA.
	fn keys(ti: TypeInfo) void[]
	{
		arr := allocDg(ti, mNumEntries)[0 .. mNumEntries * ti.size];
		currentIndex: size_t;
		foreach (i, distance; mDistances) {
			if (distance == 0) {
				continue;
			}
			__llvm_memcpy(&arr[currentIndex], cast(void*)&mKeys[i], ti.size, 0, false);
			currentIndex += ti.size;
		}
		return arr;
	}

	//! Get the value keys for this AA.
	fn values(aa: AA*) void[]
	{
		ti := aa.valuetid;
		arr := allocDg(ti, mNumEntries)[0 .. mNumEntries * ti.size];
		currentIndex: size_t;
		foreach (i, distance; mDistances) {
			if (distance == 0) {
				continue;
			}
			aa.writeToPtr(&arr[currentIndex], mValues[i]);
			currentIndex += ti.size;
		}
		return arr;
	}

	/*!
	 * Find the given key in this hashmap, return a pointer to the value if
	 * found, null otherwise.
	 *
	 * @Param[in] key  The key to look for.
	 * @Return A pointer to the value or null if not found.
	 */
	fn findPtr(key: Key) Value*
	{
		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			if (distanceForIndex == 0) {
				return null;
			}

			if (distanceForIndex == distance &&
				mKeys.ptr[index].length == key.length &&
				vrt_memcmp(cast(void*)mKeys.ptr[index].ptr, cast(void*)key.ptr, key.length) == 0) {
				return &mValues.ptr[index];
			}
		}

		return null;
	}

	/*!
	 * Find the given key in this hashmap, return true if found and sets
	 * ret to the value at the key.
	 *
	 * @Param[in] key  The key to look for.
	 * @Param[out] ret The value at key or default value for Value.
	 * @Return True if found false otherwise.
	 */
	fn find(key: Key, out ret: Value) bool
	{
		ptr := findPtr(key);
		if (ptr is null) {
			return false;
		}
		ret = *ptr;
		return true;
	}

	/*!
	 * Adds the given key value pair to the hashmap, replacing any value
	 * with the same key if it was in the map.
	 *
	 * @Param[in] key   The key for the value.
	 * @Param[in] value The value to add.
	 */
	fn add(key: Key, value: Value)
	{
		// They both start at zero, make sure we grow the hashmap then.
		if (mNumEntries >= mGrowAt) {
			grow();
		}

		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			// If we found a empty slot 
			if (distanceForIndex == 0) {
				mDistances.ptr[index] = cast(Distance)distance;
				mValues.ptr[index] = value;
				mKeys.ptr[index] = new key[..];
				mNumEntries++;
				return;
			}

			// If the distances match compare keys.
			if (distanceForIndex == distance &&
				mKeys.ptr[index].length == key.length &&
				vrt_memcmp(cast(void*)mKeys.ptr[index].ptr, cast(void*)key.ptr, key.length) == 0) {
				mValues.ptr[index] = value;
				return;
			}

			// This element doesn't match, and is poorer then us.
			if (distanceForIndex >= distance) {
				continue;
			}

			// This entry is richer then us, replace it.
			tmpKey := mKeys.ptr[index];
			tmpValue := mValues.ptr[index];

			mDistances.ptr[index] = cast(Distance)distance;
			mValues.ptr[index] = value;
			mKeys.ptr[index] = new key[..];

			return add(tmpKey, tmpValue);
		}

		grow();

		add(key, value);
	}

	/*!
	 * Remove the given key and value associated with that key from the map.
	 *
	 * @Param[in] key The key to remove.
	 * @Returns True if the key was removed.
	 */
	fn remove(key: Key) bool
	{
		hash := makeHash(key);
		index := mSize.getIndex(hash);

		for (distance: i32 = 1; distance < mTries; distance++, index++) {
			distanceForIndex := mDistances.ptr[index];

			if (distanceForIndex == distance &&
			    mKeys.ptr[index] == key) {
				removeAt(index);
				mNumEntries--;
				return true;
			}
		}

		return false;
	}


public:
	/*!
	 * Grows the internal arrays.
	 */
	fn grow()
	{
		oldDistances := mDistances;
		oldValues := mValues;
		oldKeys := mKeys;

		entries := mSize.getNextSize();
		allocArrays(entries);

		foreach (index, distanceForIndex; oldDistances) {
			if (distanceForIndex == 0) {
				continue;
			}

			add(oldKeys[index], oldValues[index]);
		}
	}

	/*!
	 * Allocate new set of arrays, reset all fields that
	 * tracks the contents of the said arrays.
	 */
	fn allocArrays(entries: size_t)
	{
		mNumEntries = 0;
		mTries = cast(Distance)log2(cast(u32)entries);

		numElements := entries + cast(u32)mTries + 2;

		mGrowAt = cast(size_t)(entries * Factor);
		mKeys = new Key[](numElements);
		mValues = new Value[](numElements);
		mDistances = new Distance[](numElements);
	}


	/*
	 *
	 * Functions for doing operations at indicies.
	 *
	 */

	/*!
	 * Remove the entry at the given index, and move
	 * entries that are poor into the now free slot.
	 */
	fn removeAt(index: size_t)
	{
		next := index + 1;
		while (wantsToGetRicher(next)) {
			mDistances.ptr[index] = cast(Distance)(mDistances.ptr[next] - 1u);
			mValues.ptr[index] = mValues.ptr[next];
			// This is okay, we already own mKeys.ptr[next].
			mKeys.ptr[index] = mKeys.ptr[next];
			next++;
			index++;
		}

		// If we don't enter the loop aboce index points at the
		// original index that was supplied to the function, if
		// we have entered the loop above index points to next.
		clearAt(index);
	}

	/*!
	 * This function clears a single entry, does not do any moving.
	 */
	fn clearAt(index: size_t)
	{
		mDistances.ptr[index] = 0;
		mValues.ptr[index] = Value.init;
		mKeys.ptr[index] = null; // @todo Key.init;
	}


	/*
	 *
	 * Helper functions.
	 *
	 */

	/*!
	 * Returns true if the entry at index can be moved
	 * closer to where it wants to reside.
	 */
	fn wantsToGetRicher(index: size_t) bool
	{
		distanceForIndex := mDistances.ptr[index];

		// 0 == empty, so no.
		// 1 == prefered location.
		// 2 >= wants to get richer.
		return distanceForIndex > 1;
	}

	/*!
	 * Helper function to go from a key to a hash value.
	 */
	global fn makeHash(key: Key) u64
	{
		return hashFNV1A_64(cast(scope const(void)[])key);
	}
}

struct SizeBehaviourPrime
{
private:
	mIndex: u8;


public:
	fn setStarting(min: size_t) size_t
	{
		min = min > 16 ? min : cast(size_t)16;
		while (getPrimeSize(mIndex) < min) {
			mIndex++;
		}
		return cast(size_t)getPrimeSize(mIndex);
	}

	fn getNextSize() size_t
	{
		return cast(size_t)getPrimeSize(++mIndex);
	}

	fn getIndex(hash: u64) size_t
	{
		return cast(size_t)fastPrimeHashToIndex(mIndex, hash);
	}
}

fn getPrimeSize(index: u32) u64
{
	switch (index) {
	case   0: return 4UL;
	case   1: return 11UL;
	case   2: return 23UL;
	case   3: return 47UL;
	case   4: return 97UL;
	case   5: return 197UL;
	case   6: return 499UL;
	case   7: return 1009UL;
	case   8: return 1259UL;
	case   9: return 1597UL;
	case  10: return 2011UL;
	case  11: return 2539UL;
	case  12: return 3203UL;
	case  13: return 4027UL;
	case  14: return 5087UL;
	case  15: return 6421UL;
	case  16: return 8089UL;
	case  17: return 10193UL;
	case  18: return 12853UL;
	case  19: return 16193UL;
	case  20: return 20399UL;
	case  21: return 25717UL;
	case  22: return 32401UL;
	case  23: return 40823UL;
	case  24: return 51437UL;
	case  25: return 64811UL;
	case  26: return 81649UL;
	case  27: return 102877UL;
	case  28: return 129607UL;
	case  29: return 163307UL;
	case  30: return 205759UL;
	case  31: return 259229UL;
	case  32: return 326617UL;
	case  33: return 411527UL;
	case  34: return 518509UL;
	case  35: return 653267UL;
	case  36: return 823117UL;
	case  37: return 1037059UL;
	case  38: return 1306601UL;
	case  39: return 1646237UL;
	case  40: return 2074129UL;
	case  41: return 2613229UL;
	case  42: return 3292489UL;
	case  43: return 4148279UL;
	case  44: return 5226491UL;
	case  45: return 6584983UL;
	case  46: return 8296553UL;
	case  47: return 10453007UL;
	case  48: return 13169977UL;
	case  49: return 16593127UL;
	case  50: return 20906033UL;
	case  51: return 26339969UL;
	case  52: return 33186281UL;
	case  53: return 41812097UL;
	case  54: return 52679969UL;
	case  55: return 66372617UL;
	case  56: return 83624237UL;
	case  57: return 105359939UL;
	case  58: return 132745199UL;
	case  59: return 167248483UL;
	case  60: return 210719881UL;
	case  61: return 265490441UL;
	case  62: return 334496971UL;
	case  63: return 421439783UL;
	case  64: return 530980861UL;
	case  65: return 668993977UL;
	case  66: return 842879579UL;
	case  67: return 1061961721UL;
	case  68: return 1337987929UL;
	case  69: return 1685759167UL;
	case  70: return 2123923447UL;
	case  71: return 2675975881UL;
	case  72: return 3371518343UL;
	case  73: return 4247846927UL;
	case  74: return 5351951779UL;
	case  75: return 6743036717UL;
	case  76: return 8495693897UL;
	case  77: return 10703903591UL;
	case  78: return 13486073473UL;
	case  79: return 16991387857UL;
	case  80: return 21407807219UL;
	case  81: return 26972146961UL;
	case  82: return 33982775741UL;
	case  83: return 42815614441UL;
	case  84: return 53944293929UL;
	case  85: return 67965551447UL;
	case  86: return 85631228929UL;
	case  87: return 107888587883UL;
	case  88: return 135931102921UL;
	case  89: return 171262457903UL;
	case  90: return 215777175787UL;
	case  91: return 271862205833UL;
	case  92: return 342524915839UL;
	case  93: return 431554351609UL;
	case  94: return 543724411781UL;
	case  95: return 685049831731UL;
	case  96: return 863108703229UL;
	case  97: return 1087448823553UL;
	case  98: return 1370099663459UL;
	case  99: return 1726217406467UL;
	case 100: return 2174897647073UL;
	case 101: return 2740199326961UL;
	case 102: return 3452434812973UL;
	case 103: return 4349795294267UL;
	case 104: return 5480398654009UL;
	case 105: return 6904869625999UL;
	case 106: return 8699590588571UL;
	case 107: return 10960797308051UL;
	case 108: return 13809739252051UL;
	case 109: return 17399181177241UL;
	case 110: return 21921594616111UL;
	case 111: return 27619478504183UL;
	case 112: return 34798362354533UL;
	case 113: return 43843189232363UL;
	case 114: return 55238957008387UL;
	case 115: return 69596724709081UL;
	case 116: return 87686378464759UL;
	case 117: return 110477914016779UL;
	case 118: return 139193449418173UL;
	case 119: return 175372756929481UL;
	case 120: return 220955828033581UL;
	case 121: return 278386898836457UL;
	case 122: return 350745513859007UL;
	case 123: return 441911656067171UL;
	case 124: return 556773797672909UL;
	case 125: return 701491027718027UL;
	case 126: return 883823312134381UL;
	case 127: return 1113547595345903UL;
	case 128: return 1402982055436147UL;
	case 129: return 1767646624268779UL;
	case 130: return 2227095190691797UL;
	case 131: return 2805964110872297UL;
	case 132: return 3535293248537579UL;
	case 133: return 4454190381383713UL;
	case 134: return 5611928221744609UL;
	case 135: return 7070586497075177UL;
	case 136: return 8908380762767489UL;
	case 137: return 11223856443489329UL;
	case 138: return 14141172994150357UL;
	case 139: return 17816761525534927UL;
	case 140: return 22447712886978529UL;
	case 141: return 28282345988300791UL;
	case 142: return 35633523051069991UL;
	case 143: return 44895425773957261UL;
	case 144: return 56564691976601587UL;
	case 145: return 71267046102139967UL;
	case 146: return 89790851547914507UL;
	case 147: return 113129383953203213UL;
	case 148: return 142534092204280003UL;
	case 149: return 179581703095829107UL;
	case 150: return 226258767906406483UL;
	case 151: return 285068184408560057UL;
	case 152: return 359163406191658253UL;
	case 153: return 452517535812813007UL;
	case 154: return 570136368817120201UL;
	case 155: return 718326812383316683UL;
	case 156: return 905035071625626043UL;
	case 157: return 1140272737634240411UL;
	case 158: return 1436653624766633509UL;
	case 159: return 1810070143251252131UL;
	case 160: return 2280545475268481167UL;
	case 161: return 2873307249533267101UL;
	case 162: return 3620140286502504283UL;
	case 163: return 4561090950536962147UL;
	case 164: return 5746614499066534157UL;
	case 165: return 7240280573005008577UL;
	case 166: return 9122181901073924329UL;
	case 167: return 11493228998133068689UL;
	case 168: return 14480561146010017169UL;
	default: assert(false);
	}
}

fn fastPrimeHashToIndex(index: u8, hash: u64) u64
{
	switch (index) {
	case   0: return hash % 4UL;
	case   1: return hash % 11UL;
	case   2: return hash % 23UL;
	case   3: return hash % 47UL;
	case   4: return hash % 97UL;
	case   5: return hash % 197UL;
	case   6: return hash % 499UL;
	case   7: return hash % 1009UL;
	case   8: return hash % 1259UL;
	case   9: return hash % 1597UL;
	case  10: return hash % 2011UL;
	case  11: return hash % 2539UL;
	case  12: return hash % 3203UL;
	case  13: return hash % 4027UL;
	case  14: return hash % 5087UL;
	case  15: return hash % 6421UL;
	case  16: return hash % 8089UL;
	case  17: return hash % 10193UL;
	case  18: return hash % 12853UL;
	case  19: return hash % 16193UL;
	case  20: return hash % 20399UL;
	case  21: return hash % 25717UL;
	case  22: return hash % 32401UL;
	case  23: return hash % 40823UL;
	case  24: return hash % 51437UL;
	case  25: return hash % 64811UL;
	case  26: return hash % 81649UL;
	case  27: return hash % 102877UL;
	case  28: return hash % 129607UL;
	case  29: return hash % 163307UL;
	case  30: return hash % 205759UL;
	case  31: return hash % 259229UL;
	case  32: return hash % 326617UL;
	case  33: return hash % 411527UL;
	case  34: return hash % 518509UL;
	case  35: return hash % 653267UL;
	case  36: return hash % 823117UL;
	case  37: return hash % 1037059UL;
	case  38: return hash % 1306601UL;
	case  39: return hash % 1646237UL;
	case  40: return hash % 2074129UL;
	case  41: return hash % 2613229UL;
	case  42: return hash % 3292489UL;
	case  43: return hash % 4148279UL;
	case  44: return hash % 5226491UL;
	case  45: return hash % 6584983UL;
	case  46: return hash % 8296553UL;
	case  47: return hash % 10453007UL;
	case  48: return hash % 13169977UL;
	case  49: return hash % 16593127UL;
	case  50: return hash % 20906033UL;
	case  51: return hash % 26339969UL;
	case  52: return hash % 33186281UL;
	case  53: return hash % 41812097UL;
	case  54: return hash % 52679969UL;
	case  55: return hash % 66372617UL;
	case  56: return hash % 83624237UL;
	case  57: return hash % 105359939UL;
	case  58: return hash % 132745199UL;
	case  59: return hash % 167248483UL;
	case  60: return hash % 210719881UL;
	case  61: return hash % 265490441UL;
	case  62: return hash % 334496971UL;
	case  63: return hash % 421439783UL;
	case  64: return hash % 530980861UL;
	case  65: return hash % 668993977UL;
	case  66: return hash % 842879579UL;
	case  67: return hash % 1061961721UL;
	case  68: return hash % 1337987929UL;
	case  69: return hash % 1685759167UL;
	case  70: return hash % 2123923447UL;
	case  71: return hash % 2675975881UL;
	case  72: return hash % 3371518343UL;
	case  73: return hash % 4247846927UL;
	case  74: return hash % 5351951779UL;
	case  75: return hash % 6743036717UL;
	case  76: return hash % 8495693897UL;
	case  77: return hash % 10703903591UL;
	case  78: return hash % 13486073473UL;
	case  79: return hash % 16991387857UL;
	case  80: return hash % 21407807219UL;
	case  81: return hash % 26972146961UL;
	case  82: return hash % 33982775741UL;
	case  83: return hash % 42815614441UL;
	case  84: return hash % 53944293929UL;
	case  85: return hash % 67965551447UL;
	case  86: return hash % 85631228929UL;
	case  87: return hash % 107888587883UL;
	case  88: return hash % 135931102921UL;
	case  89: return hash % 171262457903UL;
	case  90: return hash % 215777175787UL;
	case  91: return hash % 271862205833UL;
	case  92: return hash % 342524915839UL;
	case  93: return hash % 431554351609UL;
	case  94: return hash % 543724411781UL;
	case  95: return hash % 685049831731UL;
	case  96: return hash % 863108703229UL;
	case  97: return hash % 1087448823553UL;
	case  98: return hash % 1370099663459UL;
	case  99: return hash % 1726217406467UL;
	case 100: return hash % 2174897647073UL;
	case 101: return hash % 2740199326961UL;
	case 102: return hash % 3452434812973UL;
	case 103: return hash % 4349795294267UL;
	case 104: return hash % 5480398654009UL;
	case 105: return hash % 6904869625999UL;
	case 106: return hash % 8699590588571UL;
	case 107: return hash % 10960797308051UL;
	case 108: return hash % 13809739252051UL;
	case 109: return hash % 17399181177241UL;
	case 110: return hash % 21921594616111UL;
	case 111: return hash % 27619478504183UL;
	case 112: return hash % 34798362354533UL;
	case 113: return hash % 43843189232363UL;
	case 114: return hash % 55238957008387UL;
	case 115: return hash % 69596724709081UL;
	case 116: return hash % 87686378464759UL;
	case 117: return hash % 110477914016779UL;
	case 118: return hash % 139193449418173UL;
	case 119: return hash % 175372756929481UL;
	case 120: return hash % 220955828033581UL;
	case 121: return hash % 278386898836457UL;
	case 122: return hash % 350745513859007UL;
	case 123: return hash % 441911656067171UL;
	case 124: return hash % 556773797672909UL;
	case 125: return hash % 701491027718027UL;
	case 126: return hash % 883823312134381UL;
	case 127: return hash % 1113547595345903UL;
	case 128: return hash % 1402982055436147UL;
	case 129: return hash % 1767646624268779UL;
	case 130: return hash % 2227095190691797UL;
	case 131: return hash % 2805964110872297UL;
	case 132: return hash % 3535293248537579UL;
	case 133: return hash % 4454190381383713UL;
	case 134: return hash % 5611928221744609UL;
	case 135: return hash % 7070586497075177UL;
	case 136: return hash % 8908380762767489UL;
	case 137: return hash % 11223856443489329UL;
	case 138: return hash % 14141172994150357UL;
	case 139: return hash % 17816761525534927UL;
	case 140: return hash % 22447712886978529UL;
	case 141: return hash % 28282345988300791UL;
	case 142: return hash % 35633523051069991UL;
	case 143: return hash % 44895425773957261UL;
	case 144: return hash % 56564691976601587UL;
	case 145: return hash % 71267046102139967UL;
	case 146: return hash % 89790851547914507UL;
	case 147: return hash % 113129383953203213UL;
	case 148: return hash % 142534092204280003UL;
	case 149: return hash % 179581703095829107UL;
	case 150: return hash % 226258767906406483UL;
	case 151: return hash % 285068184408560057UL;
	case 152: return hash % 359163406191658253UL;
	case 153: return hash % 452517535812813007UL;
	case 154: return hash % 570136368817120201UL;
	case 155: return hash % 718326812383316683UL;
	case 156: return hash % 905035071625626043UL;
	case 157: return hash % 1140272737634240411UL;
	case 158: return hash % 1436653624766633509UL;
	case 159: return hash % 1810070143251252131UL;
	case 160: return hash % 2280545475268481167UL;
	case 161: return hash % 2873307249533267101UL;
	case 162: return hash % 3620140286502504283UL;
	case 163: return hash % 4561090950536962147UL;
	case 164: return hash % 5746614499066534157UL;
	case 165: return hash % 7240280573005008577UL;
	case 166: return hash % 9122181901073924329UL;
	case 167: return hash % 11493228998133068689UL;
	case 168: return hash % 14480561146010017169UL;
	default: assert(false);
	}
}

/* These two functions are duplicated from Watt, but moving
 * just them to the RT doesn't seem ideal, and neither does
 * moving all hash/math functions, so just keep local copies.
 */

//! Returns the log2 of the given `u32`, does not throw on 0.
fn log2(x: u32) u32
{
	ans: u32 = 0;
	while (x = x >> 1) {
		ans++;
	}

	return ans;
}

fn hashFNV1A_64(arr: scope const(void)[]) u64
{
	arrU8 := cast(scope const(u8)[])arr;

	h := 0xcbf29ce484222325_u64;
	foreach (v; arrU8) {
		h = (h ^ v) * 0x100000001b3_u64;
	}

	return h;
}

alias HashValue = void*;
struct ArrayHash = mixin HashMapArray!(void, HashValue, SizeBehaviourPrime, 0.5);
struct ValueHash = mixin HashMapInteger!(u64, HashValue, SizeBehaviourPrime, 0.5);

union HashUnion
{
	array: ArrayHash;
	value: ValueHash;
}

struct AA
{
	keytid: TypeInfo;
	valuetid: TypeInfo;
	u: HashUnion;
	arrayKey: bool;
	ptrKey: bool;
}

fn writeToPtr(aa: AA*, ret: void*, value: HashValue)
{
	__llvm_memcpy(ret, value, aa.valuetid.size, 0, false);
}

fn fromHashValuePtr(aa: AA*, ptr: HashValue*) void*
{
	if (ptr is null) {
		return null;
	}

	return *ptr;
}

fn toHashValue(aa: AA*, value: void*) HashValue
{
	hashValue: HashValue = allocDg(aa.valuetid, 1);
	__llvm_memcpy(hashValue, value, aa.valuetid.size, 0, false);
	return hashValue;
}



extern(C):

/*!
 * Creates a new associative array.
 */
fn vrt_aa_new(value: TypeInfo, key: TypeInfo) void*
{
	aa := new AA;
	aa.valuetid = value;
	aa.keytid = key;

	switch (key.type) with (Type) {
	case U8, I8, Char, Bool, U16, I16,
		 Wchar, U32, I32, Dchar, F32,
		 U64, I64, F64:
		aa.arrayKey = false;
		break;
	case Array:
		aa.arrayKey = true;
		break;
	default:
		aa.arrayKey = true;
		aa.ptrKey = true;
		break;
	}

	return cast(void*)aa;
}

/*!
 * Copies an existing associative array.
 */
fn vrt_aa_dup(rbtv: void*) void*
{
	if (rbtv is null) {
		return null;
	}
	oldAA := cast(AA*)rbtv;
	newAA := new AA;
	newAA.valuetid = oldAA.valuetid;
	newAA.keytid = oldAA.valuetid;
	newAA.arrayKey = oldAA.arrayKey;
	newAA.ptrKey = oldAA.ptrKey;
	if (newAA.arrayKey) {
		newAA.u.array.dup(oldAA.u.array);
	} else {
		newAA.u.value.dup(oldAA.u.value);
	}
	return cast(void*)newAA;
}

/*!
 * Check if a key is in an associative array.
 */
fn vrt_aa_in_primitive_template!(K)(rbtv: void*, key: K, ret: void*) bool
{
	if (rbtv is null) {
		return false;
	}
	aa := cast(AA*)rbtv;
	value: HashValue;
	static if (is(K == u64)) {
		retval := aa.u.value.find(key, out value);
		if (!retval) return false;
	} else static if (is(K == void[])) {
		retval := aa.u.array.find(key, out value);
		if (!retval) return false;
	} else {
		keyslice := key[0 .. aa.keytid.size];
		retval := aa.u.array.find(keyslice, out value);
		if (!retval) return false;
	}

	aa.writeToPtr(ret, value);

	return true;
}

fn vrt_aa_in_primitive = mixin vrt_aa_in_primitive_template!(u64);
fn vrt_aa_in_array = mixin vrt_aa_in_primitive_template!(void[]);
fn vrt_aa_in_ptr = mixin vrt_aa_in_primitive_template!(void*);

/*!
 * Insert a value into an associative array.
 */
fn vrt_aa_insert_template!(K)(rbtv: void*, key: K, value: void*)
{
	aa := cast(AA*)rbtv;
	hashValue: HashValue = aa.toHashValue(value);
	static if (is(K == u64)) {
		aa.u.value.add(key, hashValue);
	} else static if (is(K == void[])) {
		aa.u.array.add(key, hashValue);
	} else {
		keyslice := key[0 .. aa.keytid.size];
		aa.u.array.add(keyslice, hashValue);
	}
}

fn vrt_aa_insert_primitive = mixin vrt_aa_insert_template!(u64);
fn vrt_aa_insert_array = mixin vrt_aa_insert_template!(void[]);
fn vrt_aa_insert_ptr = mixin vrt_aa_insert_template!(void*);

/*!
 * Delete a value in an associative array.
 */
fn vrt_aa_delete_template!(K)(rbtv: void*, key: K) bool
{
	if (rbtv is null) {
		return false;
	}
	aa := cast(AA*)rbtv;
	static if (is(K == u64)) {
		return aa.u.value.remove(key);
	} else static if (is(K == void[])) {
		return aa.u.array.remove(key);
	} else {
		keyslice := key[0 .. aa.keytid.size];
		return aa.u.array.remove(keyslice);
	}
}

fn vrt_aa_delete_primitive = mixin vrt_aa_delete_template!(u64);
fn vrt_aa_delete_array = mixin vrt_aa_delete_template!(void[]);
fn vrt_aa_delete_ptr = mixin vrt_aa_delete_template!(void*);

/*!
 * Get the keys array for a given associative array.
 */
fn vrt_aa_get_keys(rbtv: void*) void[]
{
	if (rbtv is null) {
		return null;
	}
	aa := cast(AA*)rbtv;
	if (aa.ptrKey) {
		return aa.u.array.ptrKeys(aa.keytid);
	} else if (aa.arrayKey) {
		return aa.u.array.keys(aa.keytid);
	} else {
		return aa.u.value.keys(aa.keytid);
	}
}

/*!
 * Get the values array for a given associative array.
 */
fn vrt_aa_get_values(rbtv: void*) void[]
{
	if (rbtv is null) {
		return null;
	}
	aa := cast(AA*)rbtv;
	if (aa.arrayKey) {
		return aa.u.array.values(aa);
	} else {
		return aa.u.value.values(aa);
	}
}

/*!
 * Get the number of pairs in a given associative array.
 */
fn vrt_aa_get_length(rbtv: void*) size_t
{
	if (rbtv is null) {
		return 0;
	}
	aa := cast(AA*)rbtv;
	if (aa.arrayKey) {
		return aa.u.array.mNumEntries;
	} else {
		return aa.u.value.mNumEntries;
	}
}

/*!
 * Implements the `in` operator for associative arrays.
 */
fn vrt_aa_in_binop_template!(K)(rbtv: void*, key: K) void*
{
	if (rbtv is null) {
		return null;
	}
	aa := cast(AA*)rbtv;

	static if (is(K == u64)) {
		return aa.fromHashValuePtr(aa.u.value.findPtr(key));
	} else static if (is(K == void[])) {
		return aa.fromHashValuePtr(aa.u.array.findPtr(key));
	} else {
		keyslice := key[0 .. aa.keytid.size];
		return aa.fromHashValuePtr(aa.u.array.findPtr(keyslice));
	}
}

fn vrt_aa_in_binop_primitive = mixin vrt_aa_in_binop_template!(u64);
fn vrt_aa_in_binop_array = mixin vrt_aa_in_binop_template!(void[]);
fn vrt_aa_in_binop_ptr = mixin vrt_aa_in_binop_template!(void*);

/*!
 * Rehash an associative array to optimise performance.
 *
 * This is a no-op in the current implementation.
 */
fn vrt_aa_rehash(rbtv: void*)
{
}
