module img4d.img4d_lib.filter;

import std.stdio, std.array, std.conv, std.algorithm, std.range;
import std.parallelism : parallel;

pure ref auto inverseSub(ref ubyte[][] scanline){
	return [scanline.joinVertical.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))]
		.join.transposed;
}

pure ref auto inverseSub(ref ubyte[][] scanline, bool gray){
	return [scanline.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))]
		.join.transposed;
}

auto sub(R)(R input){
	return input.map!(a => a.slide(2))
		.map!(b => b.front.front ~ b.map!(c => c.front - c.back)
				.map!(d => d > 0 ? 256 - d : d.abs).array).array.to!(ubyte[][]);
}

auto up(R)(R input){
	return input.front.walkLength.iota
		.map!(i => transversal(input, i).array)
		.sub.transpose;
}

auto transpose(R)(R input){
	R output;
	output.length = input.front.length;
	for(int i=0; i<input.length; i++){
		for(int j=0; j<input.front.length; j++){
			output[j] ~= input[i][j];
		}
	}
	return output;
}

/**
 *  To vertical array 
 */
pure ref auto T[][] joinVertical(T)(ref T[][] src){
	return src.front.walkLength.iota.map!(i => transversal(src, i).array).array;
}

/**
 *  Average(x) = Raw(x) - floor((Raw(x-bpp)+Prior(x))/2)
 */
ubyte[][] ave(ref ubyte[][] src){
	if (src.length == 0){
		return src;
	}

	ubyte[][] output;
	output.length = src.length;
	output.front = src.front;

	foreach (idx, scanline; src[1 .. $].parallel){
		scanline.each!((edx, a) => output[idx + 1] ~= edx == 0 ? (a - (src[idx].front / 2)).normalizePixelValue
				: (a - (src[idx][edx] + src[idx + 1][edx - 1]) / 2).normalizePixelValue);
	}
	return output;
}

ubyte normalizePixelValue(int value){
	if (value < 0){
		value += 256;
	}
	else if (value >= 256){
		value -= 256;
	}
	return value.to!ubyte;
}

//  Paeth(x) = Raw(x) - PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
ref auto ubyte[][] paeth(ref ubyte[][] src){
	if (src.length == 0)
		return src;
	ubyte[][] output;
	output.length = src.length;
	output.front = src.front;

	foreach (idx, scanline; src[1 .. $].parallel){
		scanline.each!((edx, a) => output[idx + 1] ~= edx == 0 ? (a - paethPredictor(src[idx].front)).normalizePixelValue
				: (a - paethPredictor(src[idx][edx], src[idx + 1][edx - 1], src[idx][edx - 1]))
				.normalizePixelValue);
	}
	return output;
}

template paethPredictor(){
	int paethPredictor(int upper, int left = 0, int upperLeft = 0){
		int paeth = left + upper - upperLeft;
		int paethLeft = (paeth - left).abs;
		int paethUpper = (paeth - upper).abs;
		int paethUpperLeft = (paeth - upperLeft).abs;
		if (paethLeft <= paethUpper && paethLeft <= paethUpperLeft)
			return left;
		if (paethUpper <= paethUpperLeft)
			return upper;
		return upperLeft;
	}
}

/**
 * calculate absolute value by using bitshift
 */
int abs(int num){
	return (num ^ (num >> 31)) - (num >> 31);
}
