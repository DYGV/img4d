import img4d;
import img4d.img4d_lib.decode, img4d.img4d_lib.encode, img4d.img4d_lib.filter,
	   img4d.img4d_lib.color_space, img4d.img4d_lib.edge;

import std.stdio, std.array, std.bitmanip, std.conv, std.algorithm, std.range,
	   std.math, std.string, std.range.primitives, std.algorithm.mutation,
	   std.file, std.algorithm.iteration;

unittest{  // decode.d{
	Header hdr;
	Decode decode = new Decode(hdr);
	ubyte[21] headers = ['I', 'H', 'D', 'R', // chunk type
		0, 0, 0, 5, // height
		0, 0, 0, 5, // width
		8, // bitDepth
		2, // colorType
		0, // compressionMethod
		0, // filterMethod
		0, // interlaceMethod
		2, 13, 177, 178]; // calculated crc

	// byteToString
	ubyte[] hello = ['H', 'E', 'L', 'L', 'O'];
	assert(decode.byteToString(hello) == "HELLO");

	// readIHDR
	hdr = decode.readIHDR(headers);

	// crcCheck
	ubyte[] crc = [2, 13, 177, 178];
	ubyte[] data = [0x49, 0x48, 0x44, 0x52, 0x0, 0x0, 0x0, 0x5, 0x0, 0x0, 0x0, 0x5, 0x8, 0x2, 0x0, 0x0, 0x0];
	assert(decode.crcCheck(crc, data));
}

unittest{  // encode.d{
	Header hdr;
	Decode decode = new Decode(hdr);
	ubyte[21] headers = ['I', 'H', 'D', 'R', // chunk type
		0, 0, 0, 5, // height
		0, 0, 0, 5, // width
		8, // bitDepth
		0, // colorType
		0, // compressionMethod
		0, // filterMethod
		0, // interlaceMethod
		168, 4, 121, 57]; // calculated crc

	hdr = decode.readIHDR(headers);

	// sumScanline
	ubyte[][] sample_pix_data = [[1, 2, 3]];
	ubyte[][] src = [[1, 2, 3], [4, 5, 6]]; // [1+2+3. 4+5+6] == [6, 15]
	ubyte[] sum = [6, 15];
	Pixel pix = Pixel(sample_pix_data);
	Encode encode = new Encode(hdr, pix);
	assert(encode.sumScanline(src).equal(sum));

	// chooseFilterType grayscale
	ubyte[][] data = [[0, 0, 0, 0, 0], [1, 2, 3, 4, 5], [
		0, 100, 0, 100, 0
	], [0, 100, 0, 100, 0], [1, 0, 1, 0, 1]];
	pix = Pixel(data);
	encode = new Encode(hdr, pix);
	assert(encode.chooseFilterType == [[0, 0, 0, 0, 0, 0], [1, 1, 1, 1, 1, 1],
			[0, 0, 100, 0, 100, 0], [2, 0, 0, 0, 0, 0], [0, 1, 0, 1, 0, 1]]);

	// chooseFilterType color
	hdr.colorType = colorTypes.trueColor;
	data = [[0, 0, 0, 0, 0, 0], [1, 2, 3, 4, 5, 6], [0, 100, 0, 100, 0, 100],
		 [0, 100, 0, 100, 0, 100], [1, 0, 1, 0, 1, 0]];
	pix = Pixel(data, data, data);
	encode = new Encode(hdr, pix);
	assert(encode.chooseFilterType == [[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
			[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], [0, 0,
			0, 0, 100, 100, 100, 0, 0, 0, 100, 100, 100, 0, 0, 0, 100, 100, 100],
			[2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], [0, 1,
			1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0]]);

	// makeIEND
	hdr.colorType = colorTypes.grayscale;
	sample_pix_data = [[1, 2, 3]];
	pix = Pixel(sample_pix_data);
	encode = new Encode(hdr, pix);
	assert(encode.makeIEND == [0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130]);

	// makeCrc
	ubyte[] crc = [73, 69, 78, 68];
	assert(encode.makeCrc(crc) == [174, 66, 96, 130]);
}

// joinVertical
unittest{
	ubyte[][] horizontal = [[1, 2, 3], [4, 5, 6], [7, 8, 9]];
	ubyte[][] vertical = [[1, 4, 7], [2, 5, 8], [3, 6, 9]];
	assert(horizontal.joinVertical.equal(vertical));
}

// sub
unittest{
	ubyte[][] beforeCalculateSub = [[1, 2, 3], [9, 3, 0]];
	ubyte[][] subFiltered = [[1, 1, 1], [9, 250, 253]];
	assert(beforeCalculateSub.sub.equal(subFiltered));
}

// up
unittest{
	ubyte[][] beforeCalculateUp = [[1, 2, 3], [1, 5, 2]]; // joinVertical => [[1, 1],[2, 5],[3, 2]]
	// neighborDifference
	// =>
	// front - back < 0 => abs(front - back)
	// front - back > 0 => 256 - (front - back)

	ubyte[][] upFiltered = [[1, 2, 3], [0, 3, 255]];
	assert(beforeCalculateUp.up.equal(upFiltered));
}
