module img4d.img4d_lib.encode;

import img4d, img4d.img4d_lib.decode, img4d.img4d_lib.filter;
import std.stdio, std.array, std.bitmanip, std.conv, std.zlib, std.digest,
	   std.digest.crc, std.range, std.algorithm, std.functional;
import std.parallelism : parallel;

mixin template bitOperator(){
	void set32bitInt(ref ubyte[4] buf, uint data){
		buf = [(data >> 24) & 0xff, (data >> 16) & 0xff, (data >> 8) & 0xff, (data >> 0) & 0xff];
	}
	void set32bitInt(ref ubyte[2] buf, uint data){
		buf = [(data >> 8) & 0xff, (data >> 0) & 0xff];
	}

	uint read32bitInt(in ubyte[] buf){
		return ((buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | (buf[3] << 0));
	}
}

mixin template makeChunk(){
	import  std.conv, std.digest.crc, std.range, std.algorithm;

	auto makeChunk(ubyte[] chunk_type, ubyte[] chunk_data){
		mixin bitOperator;
		ubyte[4] length;
		set32bitInt(length, chunk_data.length.to!int);
		ubyte[] to_crc_data = chunk_type ~ chunk_data;
		return length ~ to_crc_data ~ makeCrc(to_crc_data);
	}

	/**
	 *  Calculate from chunk data. 
	 */
	auto makeCrc(ubyte[] data){
		ubyte[4] crc;
		data.crc32Of.each!((idx, a) => crc[3 - idx] = a);
		return crc;
	}
}

class Encode{
	Header header;
	Pixel pixel;
	mixin bitOperator;
	mixin makeChunk;

	this(ref Header header, ref Pixel pixel){
		this.header = header;
		this.pixel = pixel;
	}

	ref auto ubyte[] makeIHDR(){
		ubyte depth, colorSpaceType, compress, filterType, adam7;

		with (this.header){
			depth = bitDepth.to!ubyte;
			colorSpaceType = colorType.to!ubyte;
			compress = compressionMethod.to!ubyte;
			filterType = filterMethod.to!ubyte;
			adam7 = interlaceMethod.to!ubyte;
		}

		const ubyte[] sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
		const ubyte[] bodyLenIHDR = [0x0, 0x0, 0x0, 0x0D];
		ubyte[] chunkIHDR = [
			0x49, 0x48, 0x44, 0x52, // "IHDR"
			0x0, 0x0, 0x0, 0x00, // width
			0x0, 0x0, 0x0, 0x00, // height
			depth, colorSpaceType, compress, filterType, adam7
		];
		set32bitInt(chunkIHDR[4 .. 8], this.header.width);
		set32bitInt(chunkIHDR[8 .. 12], this.header.height);
		ubyte[] IHDR = bodyLenIHDR ~ chunkIHDR ~ makeCrc(chunkIHDR);
		return sig ~ IHDR;
	}

	ref auto ubyte[] makeIDAT(){
		Compress cmps = new Compress(HeaderFormat.deflate);
		ubyte[] beforeCmpsData, idatData, chunkData, IDAT;
		uint chunkSize;
		ubyte[][] byteData;
		const ubyte[] chunkType = [0x49, 0x44, 0x41, 0x54];
		ubyte[] bodyLenIDAT = [0x0, 0x0, 0x0, 0x0];

		beforeCmpsData = this.chooseFilterType.join;
		idatData ~= cast(ubyte[]) cmps.compress(beforeCmpsData);
		idatData ~= cast(ubyte[]) cmps.flush();
		chunkSize = idatData.length.to!uint;

		set32bitInt(bodyLenIDAT[0 .. 4], chunkSize);
		chunkData = chunkType ~ idatData;
		IDAT = bodyLenIDAT ~ chunkData ~ makeCrc(chunkData);

		return IDAT;
	}

	auto makeAncillary(int chunk_length, ubyte[] chunk_type, ubyte[] chunk_data){
		ubyte[4] length;
		set32bitInt(length, chunk_length);
		ubyte[] to_crc_data = chunk_type ~ chunk_data;
		return length ~ to_crc_data ~ makeCrc(to_crc_data);
	}

	ubyte[] makeIEND(){
		const ubyte[] chunkIEND = [0x0, 0x0, 0x0, 0x0];
		ubyte[] chunkType = [0x49, 0x45, 0x4E, 0x44];
		ubyte[] IEND = chunkIEND ~ chunkType ~ makeCrc(chunkType);

		return IEND;
	}

	/**
	 *  Cast to int[]
	 *  and Calculate sum every horizontal line.
	 */
	pure ref auto int[] sumScanline(ref ubyte[][] src){
		return cast(int[])(src.map!(a => a.sum).array);
	}

	/**
	 * Choose optimal filter
	 * and Return filtered pixel.
	 */
	ref auto ubyte[][] chooseFilterType(){
		int[] sumNone, sumSub, sumUp, sumAve, sumPaeth;

		ubyte[][] R, G, B, A, filteredNone, filteredSub,
			filteredUp, filteredAve, filteredPaeth;

		/* begin comparison with none, sub, up, ave and paeth*/
		ubyte[][] tmpR = this.pixel.R;
		ubyte[][] tmpG = this.pixel.G;
		ubyte[][] tmpB = this.pixel.B;
		ubyte[][] tmpA = this.pixel.A;
		with (this.header){
			with (colorTypes){
				if (colorType == grayscale || colorType == grayscaleA){
					filteredNone = Pixel(this.pixel.grayscale, tmpA).Pixel;

					auto f = [this.pixel.grayscale, tmpA]
						.map!(a =>
							a.adjoin!(sub, up, ave!("-", "src"), paeth!("-", "src")).array)
						.array;

					// f = [[gray(sub), A(sub)],
					//		[gray(up), A(up)], ...]
					filteredSub = Pixel(f[0][0], f[1][0]).Pixel;
					filteredUp = Pixel(f[0][1], f[1][1]).Pixel;
					filteredAve = Pixel(f[0][2], f[1][2]).Pixel;
					filteredPaeth = Pixel(f[0][3], f[1][3]).Pixel;
				}else{
					filteredNone = this.pixel.Pixel;
					auto f = [tmpR, tmpG, tmpB, tmpA]
						.map!(a =>
							a.adjoin!(sub, up, ave!("-", "src"), paeth!("-", "src")).array)
						.array;

					// f = [[R(sub), G(sub), B(sub), A(sub)],
					//		[R(up), G(up), B(up), A(up)], ...]
					filteredSub = Pixel(f[0][0], f[1][0], f[2][0], f[3][0]).Pixel;
					filteredUp = Pixel(f[0][1], f[1][1], f[2][1], f[3][1]).Pixel;
					filteredAve = Pixel(f[0][2], f[1][2], f[2][2], f[3][2]).Pixel;
					filteredPaeth = Pixel(f[0][3], f[1][3], f[2][3], f[3][3]).Pixel;
				}
			}
		}
		sumNone = this.sumScanline(filteredNone);
		sumSub = this.sumScanline(filteredSub);
		sumUp = this.sumScanline(filteredUp);
		sumAve = this.sumScanline(filteredAve);
		sumPaeth = this.sumScanline(filteredPaeth);

		int[][] sums = [sumNone, sumSub, sumUp, sumAve, sumPaeth];
		ubyte[] minIndex = sums.front.walkLength
			.iota.map!(i => transversal(sums, i))
			.map!(minIndex)
			.array
			.to!(ubyte[]);

		ubyte[][] actualData = new ubyte[][](filteredNone.length);

		with (filterTypes){
			foreach (idx, min; minIndex.parallel){
				actualData[idx] ~= min;
				switch (min){
					case None:
						actualData[idx] ~= filteredNone[idx];
						break;
					case Sub:
						actualData[idx] ~= filteredSub[idx];
						break;
					case Up:
						actualData[idx] ~= filteredUp[idx];
						break;
					case Average:
						actualData[idx] ~= filteredAve[idx];
						break;
					case Paeth:
						actualData[idx] ~= filteredPaeth[idx];
						break;
					default:
						break;
				}
			}
		}
		/* end comparison with none, sub, up, ave and paeth*/
		return actualData;
	}

}
