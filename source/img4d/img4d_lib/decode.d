module img4d.img4d_lib.decode;

import img4d, img4d.img4d_lib.filter;
import std.file : read;
import std.digest.crc : CRC32, crc32Of;
import std.stdio, std.array, std.bitmanip, std.zlib, std.conv, std.algorithm,
	   std.range, img4d.img4d_lib.encode;
import std.parallelism : parallel;

class Decode: Img4d{
	mixin bitOperator;
	Header header;
	this(ref Header header){
		this.header = header;
	}

	@property{
		ref auto Header hdr(){
			return this.header;
		}
	}

	ref auto Header readIHDR(ubyte[] header){
		if (header.length != 21)
			throw new Exception("invalid header format");
		ubyte[] chunk = header[0 .. 17]; // Chunk Type + Chunk Data 
		this.header = Header(read32bitInt(header[4 .. 8]), // width
				read32bitInt(header[8 .. 12]), // height
				header[12], // bitDepth
				header[13], // colorType
				header[14], // compressionMethod
				header[15], // filterMethod
				header[16], // interlaceMethod
				header[17 .. 21] // crc
				);
		crcCheck(this.header.crc, chunk);
		return this.header;
	}

	/**
	 *  Cast array to string
	 */
	string byteToString(in ubyte[] data){
		return cast(string) data;
	}

	ref auto ubyte[] readIDAT(ubyte[] data){
		ubyte[] dataCrc = data[0 .. $ - 4];
		ubyte[] crc = data[$ - 4 .. $];
		crcCheck(crc, dataCrc);

		return data[4 .. $ - 4];
	}

	bool crcCheck(ref ubyte[] crc, ref ubyte[] chunk){
		reverse(crc[]);
		if (crc != chunk.crc32Of){
			throw new Exception("invalid");
		}
		return true;
	}

	void inverseFiltering(ref ubyte[][] data, ubyte[] filters, int i=0){
		if(filters.length == 0) return;
		ubyte filter = filters.front;
		filters.popFront;
		switch (filter) with (filterTypes){
			case None:
				break;

			case Sub:
				data[i] = [data[i]].array.inverseSub.transposed.join.to!(ubyte[]);
				break;

			case Up:
				data[i] = (data[i][] += data[i-1][])
					.map!(a => a.normalizePixelValue)
					.array
					.to!(ubyte[]);
				break;

			case Average:
				data[i] = data[i-1 .. i+1].ave!("+", "output").back;
				break;

			case Paeth:
				data[i] =  data[i-1 .. i+1].paeth!("+", "output").back;
				break;

			default:
				break;
		}
		inverseFiltering(data, filters, ++i);
	}

	auto parse(string filename){
		ubyte[] data_ = cast(ubyte[]) filename.read;
		int idx = 0;
		int sigSize = 8;

		if (data_.take(sigSize) != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
			throw new Exception("Invalid PNG format.");

		int chunkLengthSize = 4;
		int chunkTypeSize = 4;
		int chunkCrcSize = 4;
		int chunkDataSize;
		string chunkType;
		ubyte[] uncIDAT;
		const string[] ancillaryChunks = [
			"tRNS", "gAMA", "cHRM", "sRGB", "iCCP", "tEXt", "zTXt", "iTXt",
			"bKGD", "pHYs", "vpAg", "sBIT", "sPLT", "hIST", "tIME", "fRAc",
			"gIFg", "gIFt", "gIFx", "oFFs", "pCAL", "sCAL"
		];

		idx += sigSize;
		UnCompress uc = new UnCompress(HeaderFormat.deflate);
		while (idx >= 0){
			uint back_idx = idx + chunkLengthSize;
			chunkDataSize = read32bitInt(data_[idx .. back_idx]);
			idx += chunkLengthSize;
			chunkType = this.byteToString(data_[idx .. idx + chunkTypeSize]);

			switch (chunkType){
				case "IHDR":
					int endIdx = chunkTypeSize + chunkDataSize + chunkCrcSize;
					this.header = this.readIHDR(data_[idx .. idx + endIdx]);
					idx += endIdx;
					break;

				case "IDAT":
					int endIdx = chunkDataSize + chunkCrcSize;
					ubyte[] idat = this.readIDAT(data_[idx .. idx + chunkTypeSize + endIdx]);
					idx += chunkLengthSize + endIdx;
					uncIDAT ~= cast(ubyte[]) uc.uncompress(idat.dup);
					break;

				case "IEND":
					idx = -1; // To end while() loop
					break;

				default: // except for IHDR, IDAT, IEND
					if (!ancillaryChunks.canFind(chunkType))
						throw new Exception("Invalid png format");
					//chunkType.writeln;
					idx += chunkTypeSize + chunkDataSize + chunkCrcSize;
			}
		}
		uint numScanline = (uncIDAT.length / this.header.height).to!uint;
		auto data = uncIDAT.chunks(numScanline).array;
		ubyte[] filters = data.map!(sc => sc.front).array;
		data = data.map!((a)=> a.remove(0)).array;

		Appender!(ubyte[])[] R, G, B, A, gray;
		R.length = data.length;
		G.length = data.length;
		B.length = data.length;
		A.length = data.length;
		gray.length = data.length;

		bool isAlpha = false;
		bool isGray = false;
		with (colorTypes) with (this.header){
			if((colorType == grayscaleA) || (colorType == trueColorA))
				isAlpha = true;
			if((colorType == grayscale) || (colorType == grayscaleA))
				isGray = true;
		}
		for(int i = 0; i < data.length; i++){
			ulong len = data[i].length;
			while (data[i].length > 0){
				if(isGray){
					gray[][i].put(data[i][0]);
					data[i] = data[i][1 .. $];
					if(isAlpha){
						A[][i].put(data[i][0]);
						data[i] = data[i][1 .. $];
					}
				}else{ // true color
					R[][i].put(data[i][0]);
					G[][i].put(data[i][1]);
					B[][i].put(data[i][2]);
					data[i] = data[i][3 .. $];
					if (isAlpha){
						A[][i].put(data[i][0]);
						data[i] = data[i][1 .. $];
					}
				}
			}
		}
		auto channels = isGray 
			? [gray.map!(a=> a[]).array, A.map!(a=> a[]).array] 
			: [R.map!(a=> a[]).array, G.map!(a=> a[]).array, 
				B.map!(a=> a[]).array, A.map!(a=> a[]).array];
		foreach(i, ref channel; channels.parallel){
			if(channel.empty) continue;
			this.inverseFiltering(channel, filters);
		}
		return setEachChannelsToPixel(channels, isGray, isAlpha);
	}
}

