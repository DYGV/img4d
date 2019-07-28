module img4d_lib.decode;

import img4d, img4d_lib.filter;
import std.file : read;
import std.digest.crc : CRC32, crc32Of;
import std.stdio, std.array, std.bitmanip, std.zlib, std.conv, std.algorithm,
    std.range, img4d_lib.encode;

class Decode
{
    mixin bitOperator;
    Header header;
    this(ref Header header)
    {
        this.header = header;
    }

    @property
    {
        ref auto Header hdr()
        {
            return this.header;
        }
    }

    ref auto Header readIHDR(ubyte[] header)
    {
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

        switch (this.header.colorType) with (colorTypes)
        {
        case grayscale:
            lengthPerPixel = this.header.width;
            break;
        case trueColor:
            lengthPerPixel = 3;
            break;
        case indexColor:
            lengthPerPixel = 3;
            break;
        case grayscaleA:
            lengthPerPixel = this.header.width * 2;
            break;
        case trueColorA:
            lengthPerPixel = 4;
            break;
        default:
            break;
        }

        crcCheck(this.header.crc, chunk);
        return this.header;
    }

    /**
   *  Cast array to string
   */
    string byteToString(ubyte[] data)
    {
        return cast(string) data;
    }

    ref auto ubyte[] readIDAT(ubyte[] data)
    {
        ubyte[] dataCrc = data[0 .. $ - 4];
        ubyte[] crc = data[$ - 4 .. $];
        crcCheck(crc, dataCrc);

        return data[4 .. $ - 4];
    }

    bool crcCheck(ref ubyte[] crc, ref ubyte[] chunk)
    {
        reverse(crc[]);
        if (crc != chunk.crc32Of)
        {
            throw new Exception("invalid");
        }
        return true;
    }

    int normalizePixelValue(in int value)
    {
        return value < 256 ? value : value - 256;
    }

    ref auto ubyte[][] inverseFiltering(ref ubyte[][] data, bool gray = false)
    {
        ubyte[][] actualData;

        ubyte[] filters = data.map!(sc => sc.front).array;
        ubyte[][][] rgb = data.map!(a => a.remove(0).chunks(lengthPerPixel).array).array;

        actualData.length = filters.length;
        mixin paethPredictor;
        foreach (idx, scanline; rgb)
        {
            ubyte[] temp;

            switch (filters[idx]) with (filterTypes)
            {
            case None:
                actualData[idx] = scanline.join;
                break;

            case Sub:
                actualData[idx] = (gray) ? scanline.inverseSub(true)
                    .join.to!(ubyte[]) : scanline.inverseSub.join.to!(ubyte[]);

                break;

            case Up:
                uint upIdx = (idx - 1).to!uint;
                temp = scanline.join;
                actualData[idx] = (temp[] += actualData[upIdx][]).map!(
                        a => this.normalizePixelValue(a))
                    .array
                    .to!(ubyte[]);

                break;

            case Average:
                uint upIdx = (idx - 1).to!uint;
                ubyte[][] up = actualData[upIdx].chunks(lengthPerPixel).array;
                ubyte[][][] current = scanline.chunks(lengthPerPixel).array;
                if (gray)
                {
                    scanline.front.popFront;
                    auto sc = scanline.join;
                    temp ~= up.front.front / 2;
                    up.front[1 .. $].each!((o,
                            n) => temp ~= [this.normalizePixelValue((temp[o] + n) / 2 + sc[o])].to!(
                            ubyte[]));
                }
                else
                {
                    scanline.popFront;
                    ubyte[] sc = scanline.join;

                    up.front.each!((idx,
                            n) => temp ~= [this.normalizePixelValue((n / 2) + current.front[0][idx])].to!(
                            ubyte[]));
                    up.join[lengthPerPixel .. $].each!((o,
                            n) => temp ~= [this.normalizePixelValue(((temp[o] + n) / 2) + sc[o])].to!(
                            ubyte[]));
                }
                actualData[idx] = temp;
                break;

            case Paeth:
                uint upIdx = (idx - 1).to!uint;
                ubyte[] joined;
                scanline.each!(a => joined ~= a);

                actualData[upIdx][0 .. lengthPerPixel].each!((idx,
                        a) => temp ~= [this.normalizePixelValue(a + joined[idx])].to!(ubyte[]));

                actualData[upIdx][lengthPerPixel .. $].each!((i,
                        a) => temp ~= [this.normalizePixelValue(paethPredictor(a,
                        temp[i], actualData[upIdx][i]) + joined[i + lengthPerPixel])].to!(ubyte[]));

                actualData[idx] = temp;
                break;

            default:
                break;
            }
        }
        return actualData;
    }

    ref auto ubyte[][] parse(string filename)
    {
        ubyte[] data = cast(ubyte[]) filename.read;
        int idx = 0;
        int sigSize = 8;

        if (data.take(sigSize) != [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
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
        while (idx >= 0)
        {
            uint back_idx = idx + chunkLengthSize;
            chunkDataSize = read32bitInt(data[idx .. back_idx]);
            idx += chunkLengthSize;
            chunkType = this.byteToString(data[idx .. idx + chunkTypeSize]);

            switch (chunkType)
            {
            case "IHDR":
                int endIdx = chunkTypeSize + chunkDataSize + chunkCrcSize;
                this.header = this.readIHDR(data[idx .. idx + endIdx]);
                idx += endIdx;
                break;

            case "IDAT":
                int endIdx = chunkDataSize + chunkCrcSize;
                ubyte[] idat = this.readIDAT(data[idx .. idx + chunkTypeSize + endIdx]);
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
        auto uncChunks = uncIDAT.chunks(numScanline).array;

        with (colorTypes) with (this.header)
        {
            return ((colorType != grayscale) && (colorType != grayscaleA)) ? this.inverseFiltering(uncChunks)
                : this.inverseFiltering(uncChunks, true);

        }
    }
}
