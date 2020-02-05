module img4d.img4d_lib.encode;

import img4d, img4d.img4d_lib.decode, img4d.img4d_lib.filter;
import std.stdio, std.array, std.bitmanip, std.conv, std.zlib, std.digest,
    std.digest.crc, std.range, std.algorithm;
import std.parallelism : parallel;

mixin template bitOperator()
{
    void set32bitInt(ref ubyte[4] buf, uint data)
    {
        buf = [(data >> 24) & 0xff, (data >> 16) & 0xff, (data >> 8) & 0xff, (data >> 0) & 0xff];
    }
    void set32bitInt(ref ubyte[2] buf, uint data)
    {
        buf = [(data >> 8) & 0xff, (data >> 0) & 0xff];
    }

    uint read32bitInt(in ubyte[] buf)
    {
        return ((buf[0] << 24) | (buf[1] << 16) | (buf[2] << 8) | (buf[3] << 0));
    }
}

mixin template makeChunk(){
  import  std.conv, std.digest.crc, std.range, std.algorithm;

  auto makeChunk(ubyte[] chunk_type, ubyte[] chunk_data)
    {
      mixin bitOperator;
      ubyte[4] length;
      set32bitInt(length, chunk_data.length.to!int);
      ubyte[] to_crc_data = chunk_type ~ chunk_data;
      return length ~ to_crc_data ~ makeCrc(to_crc_data);
    }
  
  /**
   *  Calculate from chunk data. 
   */
  auto makeCrc(ubyte[] data)
    {
        ubyte[4] crc;
        data.crc32Of.each!((idx, a) => crc[3 - idx] = a);
        return crc;
    }
}

class Encode
{
    Header header;
    Pixel pixel;
    mixin bitOperator;
    mixin makeChunk;

    this(ref Header header, ref Pixel pixel)
    {
        this.header = header;
        this.pixel = pixel;
    }

    ref auto ubyte[] makeIHDR()
    {
        ubyte depth, colorSpaceType, compress, filterType, adam7;

        with (this.header)
        {
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

    ref auto ubyte[] makeIDAT()
    {
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

    auto makeAncillary(int chunk_length, ubyte[] chunk_type, ubyte[] chunk_data)
    {
        ubyte[4] length;
        set32bitInt(length, chunk_length);
        ubyte[] to_crc_data = chunk_type ~ chunk_data;
        return length ~ to_crc_data ~ makeCrc(to_crc_data);
    }

    ubyte[] makeIEND()
    {
        const ubyte[] chunkIEND = [0x0, 0x0, 0x0, 0x0];
        ubyte[] chunkType = [0x49, 0x45, 0x4E, 0x44];
        ubyte[] IEND = chunkIEND ~ chunkType ~ makeCrc(chunkType);

        return IEND;
    }

    /**
   *  Cast to int[]
   *  and Calculate sum every horizontal line.
   */
    pure ref auto int[] sumScanline(ref ubyte[][] src)
    {
        return cast(int[])(src.map!(a => a.sum).array);
    }

    /**
   * Choose optimal filter
   * and Return filtered pixel.
   */
    ref auto ubyte[][] chooseFilterType()
    {
        int[] sumNone, sumSub, sumUp, sumAve, sumPaeth;

        ubyte[][] R, G, B, A, actualData, filteredNone, filteredSub,
            filteredUp, filteredAve, filteredPaeth;

        /* begin comparison with none, sub, up, ave and paeth*/
        ubyte[][] tmpR = this.pixel.R;
        ubyte[][] tmpG = this.pixel.G;
        ubyte[][] tmpB = this.pixel.B;
        ubyte[][] tmpA = this.pixel.A;
        with (this.header)
        {
            with (colorTypes)
            {
                if (colorType == grayscale || colorType == grayscaleA)
                {
                    filteredNone = this.pixel.grayscale;
                    filteredSub = this.pixel.grayscale.sub;
                    filteredUp = this.pixel.grayscale.up;
                    filteredAve = this.pixel.grayscale.ave;
                    filteredPaeth = this.pixel.grayscale.paeth;
                }
                else
                {
                    filteredNone = this.pixel.Pixel;

                    R = tmpR.sub;
                    G = tmpG.sub;
                    B = tmpB.sub;
                    A = tmpA.sub;
                    filteredSub = Pixel(R, G, B, A).Pixel;

                    R = tmpR.up;
                    G = tmpG.up;
                    B = tmpB.up;
                    A = tmpA.up;
                    filteredUp = Pixel(R, G, B, A).Pixel;

                    R = tmpR.ave;
                    G = tmpG.ave;
                    B = tmpB.ave;
                    A = tmpA.ave;
                    filteredAve = Pixel(R, G, B, A).Pixel;

                    R = tmpR.paeth;
                    G = tmpG.paeth;
                    B = tmpB.paeth;
                    A = tmpA.paeth;
                    filteredPaeth = Pixel(R, G, B, A).Pixel;
                }
            }
        }
        sumNone = this.sumScanline(filteredNone);
        sumSub = this.sumScanline(filteredSub);
        sumUp = this.sumScanline(filteredUp);
        sumAve = this.sumScanline(filteredAve);
        sumPaeth = this.sumScanline(filteredPaeth);

        int[][] sums = [sumNone, sumSub, sumUp, sumAve, sumPaeth];
        int[] minIndex = sums.joinVertical
            .map!(minIndex)
            .array
            .to!(int[]);

        actualData.length = filteredNone.length;

        with (filterTypes)
        {
            foreach (idx, min; minIndex.array.to!(ubyte[]).parallel)
            {

                switch (min)
                {
                case None:
                    actualData[idx] = min ~ filteredNone[idx];
                    break;
                case Sub:
                    actualData[idx] = min ~ filteredSub[idx];
                    break;
                case Up:
                    actualData[idx] = min ~ filteredUp[idx];
                    break;
                case Average:
                    actualData[idx] = min ~ filteredAve[idx];
                    break;
                case Paeth:
                    actualData[idx] = min ~ filteredPaeth[idx];
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
