module img4d.img4d_lib.filter;

import std.stdio, std.array, std.conv, std.algorithm, std.range;
import std.parallelism : parallel;

pure ref auto inverseSub(ubyte[][] scanline){
	return [scanline.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))]
		.join.transposed;
}

auto sub(R)(R input){
	return input.map!(a => a.slide(2))
		.map!(b => b.front.front ~ b.map!(c => c.front - c.back)
				.map!(d => d > 0 ? 256 - d : d.abs).array).array.to!(ubyte[][]);
}

auto up(R)(R input){
	if(input.length == 0) return input;
	return input.front.walkLength.iota
		.map!(i => transversal(input, i).array)
		.sub.transpose;
}

auto transpose(R)(R input){
	R output = new R(input.front.length);
	for(int i=0; i<input.length; i++){
		for(int j=0; j<input.front.length; j++){
			output[j] ~= input[i][j];
		}
	}
	return output;
}

/**
 *  Average(x) = Raw(x) - floor((Raw(x-bpp)+Prior(x))/2)
 */
ubyte[][] ave(string op, string variable)(ubyte[][] src){
	if (src.length == 0)
		return src;
	ubyte[][] output = new ubyte[][](src.length);
	output.front = src.front;

	enum string former_stmt = "a" ~ op ~ "(" ~ variable ~ "[idx].front / 2)";
	enum string latter_stmt = "a" ~ op ~ "(" 
		~ variable ~ "[idx][edx] + " ~ variable ~ "[idx + 1][edx - 1]) / 2";

	foreach (idx, scanline; src[1 .. $].parallel){
		scanline.each!((edx, a) => 
				output[idx + 1] ~= 
				(edx == 0
				 ? mixin(former_stmt)
				 : mixin(latter_stmt)
				).normalizePixelValue
		);
	}
	return output;
}

//  Paeth(x) = Raw(x) - PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
ubyte[][] paeth(string op, string variable)(ubyte[][] src){
	if (src.length == 0)
		return src;
	ubyte[][] output = new ubyte[][](src.length);
	output.front = src.front;

	enum string former_stmt = "a" ~ op ~ variable ~ "[idx][edx]";
	enum string latter_stmt = "a" ~ op ~ "predictor("
		~ variable ~ "[idx][edx]," 
		~ variable ~ "[idx + 1][edx - 1]," 
		~ variable ~ "[idx][edx - 1])";
	foreach(idx, ubyte[] scanline; src[1 .. $].parallel){
        scanline.each!((edx, a) => 
				output[idx + 1] ~= 
				(edx == 0 
				 ? mixin(former_stmt)
				 : mixin(latter_stmt)
				).normalizePixelValue
		);
	}
	return output;
}

int predictor(int upper, int left = 0, int upperLeft = 0) @nogc {
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

ubyte normalizePixelValue(int value) @nogc {
	if (value < 0){
		value += 256;
	}
	else if (value >= 256){
		value -= 256;
	}
	return cast(ubyte)value;
}

/**
 * calculate absolute value by using bitshift
 */
int abs(int num) @nogc {
	return (num ^ (num >> 31)) - (num >> 31);
}
