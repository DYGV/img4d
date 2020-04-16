module img4d.img4d_lib.decode;

import img4d, img4d.img4d_lib.filter;
import std.file : read;
import std.digest.crc : CRC32, crc32Of;
import std.stdio, std.array, std.bitmanip, std.zlib, std.conv, std.algorithm,
	   std.range, img4d.img4d_lib.encode;
import std.parallelism : parallel;


mixin template palette(){
	PLTE[] setPLTE(ubyte[] plte_chunk){
		ulong plte_len = plte_chunk.length;
		if(plte_len%3 != 0)
			throw new Exception("The length of PLTE chunks must be divisible by 3");
		ulong plte_size = plte_len / 3;
		PLTE[] plte = new PLTE[](plte_size);
		for(int i=0; i<plte_size; i++){
			plte[i].R = plte_chunk[0];
			plte[i].G = plte_chunk[1];
			plte[i].B = plte_chunk[2];
			plte_chunk.popFrontN(3);
		}
		return plte;
	}

	ubyte[][] getCoresspondingPLTE(PLTE[] plte, ubyte[][] idat, ref Header header){
		auto output = new Appender!(ubyte[])[](idat.length);
		header.colorType = colorTypes.trueColor;
		for(int i=0; i<idat.length; i++){
			for(int j=0; j<idat.front.length; j++){
				PLTE p = plte[idat[i][j]];
				output[][i].put(p.R);
				output[][i].put(p.G);
				output[][i].put(p.B);
			}
		}
		return output.map!(a => a[]).array;
	}
}



mixin template transparency(){
	void insertAlpha(ubyte[] trns, ref Header header,
			ref ubyte[][] img, ubyte[][] idat){
		with(colorTypes)
			if(header.colorType == indexColor || header.colorType == trueColor){
				header.colorType = trueColorA;
			}
		ubyte opacity = 255;
		auto chunked_img = img.map!(a => a.chunks(3).array).array;

		for(int i=0; i<chunked_img.length; i++){
			for(int j=0; j<chunked_img.front.length; j++){
					if(idat[i][j] < trns.length){
						chunked_img[i][j] ~= trns[idat[i][j]];
					}else{
						chunked_img[i][j] ~= opacity;
					}
			}
		}
		img = chunked_img.map!join.array;
	}
}

class Decode: Img4d{
	mixin bitOperator;
	mixin palette;
	mixin transparency;
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
		PLTE[] plte;
		ubyte[] trns;
		const string[] ancillaryChunks = [
			"gAMA", "cHRM", "sRGB", "iCCP", "tEXt", "zTXt", "iTXt",
			"bKGD", "pHYs", "vpAg", "sBIT", "sPLT", "hIST", "tIME",
			"gIFg", "gIFt", "gIFx", "oFFs", "pCAL", "sCAL", "fRAc"
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

				case "PLTE":
					int endIdx = chunkDataSize;
					idx += chunkTypeSize;
					ubyte[] plte_chunk = data_[idx ..endIdx+idx];
					plte = setPLTE(plte_chunk);
					idx += chunkCrcSize + endIdx;
					break;

				case "tRNS":
					int endIdx = chunkDataSize;
					idx += chunkTypeSize;
					trns = data_[idx ..endIdx+idx];
					idx += chunkCrcSize + endIdx;
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
		bool isAlpha = false;
		bool isGray = false;
		with(colorTypes) with(this.header){
			if((colorType == grayscaleA) || (colorType == trueColorA) || !trns.empty)
				isAlpha = true;
			if((colorType == grayscale) || (colorType == grayscaleA))
				isGray = true;

			if(colorType != indexColor){
				auto channels = disassembleEachChannel(data, isGray, isAlpha);
				foreach(i, ref channel; channels.parallel){
					if(channel.empty) continue;
					this.inverseFiltering(channel, filters);
				}
				return setEachChannelsToPixel(channels, isGray, isAlpha);
			}
			// index color
			this.inverseFiltering(data, filters);
			ubyte[][] data_temp = data;
			data = this.getCoresspondingPLTE(plte, data, this.header);
			if(isAlpha){
				insertAlpha(trns, this.header, data, data_temp);
			}
			auto channels = disassembleEachChannel(data, isGray, isAlpha);
			return setEachChannelsToPixel(channels, isGray, isAlpha);
		}
	}
}

