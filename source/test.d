import img4d;	
import img4d.img4d_lib.decode,
	   img4d.img4d_lib.encode,
	   img4d.img4d_lib.filter,
	   img4d.img4d_lib.edge;	

import std.stdio,
	   std.array,
	   std.bitmanip,
	   std.conv,
	   std.algorithm,
	   std.range,	
	   std.range.primitives,
	   std.algorithm.mutation,
	   std.algorithm.iteration;	

// filter
unittest{
	ubyte[][] original = [[0, 1, 2, 3, 4], [10, 2, 212, 3, 9], [49, 12, 0, 7, 5]];
	ubyte[][] filtered = original.sub;
	assert(filtered.inverseSub.map!(a=> a.array.to!(ubyte[])).array
			.equal(original)
	);

	filtered = original.ave!("-", "src");
	assert(filtered.ave!("+", "output").equal(original));

	filtered = original.paeth!("-", "src");
	assert(filtered.paeth!("+", "output").equal(original));
}

unittest{}
