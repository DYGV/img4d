module img4d.img4d_lib.filter;

import std.stdio, std.array, std.conv, std.algorithm, std.range;
import std.parallelism : parallel;

pure ref auto inverseSub(ubyte[][] scanline){
	return [scanline
		.map!(.cumulativeFold!((a, b) => a + b < 256 ? a + b : a + b - 256))].join;
}

auto ref sub(ubyte[][] input){
	auto output = [appender!(ubyte[])];
	output.length = input.length;
	foreach(i, elm; input.parallel){
		for(int j=0; j<input.front.length; j++){
			output[][i].put(
				(j==0
					? elm[j]
					: elm[j] - elm[j-1]
				).normalizePixelValue);
		}
	}
	return output.map!(a=> a[]).array;
}

auto ref up(ubyte[][] input){
	if(input.length == 0) return input;
	auto output = [appender!(ubyte[])(input.front)];
	output.length = input.length;

	foreach(i, elm; input.parallel){
		if(i == 0) continue;
		for(int j=0; j<input.front.length; j++){
			output[][i].put((elm[j]- input[i-1][j]).normalizePixelValue);
		}
	}
	return output.map!(a=> a[]).array;
}


/**
 *	Average(x) = Raw(x) - floor((Raw(x-bpp)+Prior(x))/2)
 */
ubyte[][] ave(string op, string variable)(ubyte[][] src){
	if (src.length == 0)
		return src;
	auto output = [appender!(ubyte[])(src.front)];
	output.length = src.length;

	enum string former_stmt = "a" ~ op ~ "((" ~ variable ~ "[][idx])[].front / 2)";
	enum string latter_stmt = "a" ~ op ~ "(("
		~ variable ~ "[][idx])[][edx] + (" ~ variable ~ "[][idx + 1])[][edx - 1]) / 2";

	foreach (idx, scanline; src[1 .. $].parallel){
		scanline.each!((edx, a) =>
				output[][idx + 1].put(
					(edx == 0
					 ? mixin(former_stmt)
					 : mixin(latter_stmt)
					).normalizePixelValue)
		);
	}
	return output.map!(a=> a[]).array;
}

//	Paeth(x) = Raw(x) - PaethPredictor(Raw(x-bpp), Prior(x), Prior(x-bpp))
ubyte[][] paeth(string op, string variable)(ubyte[][] src){
	if (src.length == 0)
		return src;
	auto output = [appender!(ubyte[])(src.front)];
	output.length = src.length;

	enum string former_stmt = "a" ~ op ~ variable ~ "[][idx][][edx]";
	enum string latter_stmt = "a" ~ op ~ "predictor("
		~ variable ~ "[][idx][][edx]," 
		~ variable ~ "[][idx + 1][][edx - 1]," 
		~ variable ~ "[][idx][][edx - 1])";
	foreach(idx, ubyte[] scanline; src[1 .. $].parallel){
		scanline.each!((edx, a) => 
				output[][idx + 1].put(
				(edx == 0 
				 ? mixin(former_stmt)
				 : mixin(latter_stmt)
				).normalizePixelValue)
		);
	}
	return output.map!(a=> a[]).array;
}

int predictor(int upper=0, int left = 0, int upperLeft = 0) @nogc {
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

auto transpose(int[][] input){
	auto output = [appender!(int[])];
	output.length = input.front.length;
	for(int i=0; i<input.length; i++){
		for(int j=0; j<input.front.length; j++){
			output[][j].put(input[i][j]);
		}
	}
	return output.map!(a=> a[]).array;
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
