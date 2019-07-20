module img4d_lib.encode;

import img4d, img4d_lib.decode, img4d_lib.filter;
import std.stdio, std.array, std.bitmanip, std.conv, std.zlib, std.digest,
    std.digest.crc, std.range, std.algorithm;
import std.parallelism : parallel;

class Encode
{
    Header header;
    Pixel pixel;

    this(ref Header header, ref Pixel pixel)
    {
        this.header = header;
        this.pixel = pixel;
    }

    pure ref auto ubyte[] makeIHDR()
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
        chunkIHDR[4 .. 8].append!uint(this.header.width);
        chunkIHDR[8 .. 12].append!uint(this.header.height);

        ubyte[] IHDR = bodyLenIHDR ~ chunkIHDR ~ this.makeCrc(chunkIHDR);
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

        with (this.header) with (colorTypes)
        {
            byteData.length = (colorType.isGrayscale)
                ? this.pixel.grayscale.length : this.pixel.R.length;
        }

        beforeCmpsData = this.chooseFilterType.join;
        idatData ~= cast(ubyte[]) cmps.compress(beforeCmpsData);
        idatData ~= cast(ubyte[]) cmps.flush();
        chunkSize = idatData.length.to!uint;

        bodyLenIDAT[0 .. 4].append!uint(chunkSize);
        chunkData = chunkType ~ idatData;
        IDAT = bodyLenIDAT ~ chunkData ~ this.makeCrc(chunkData);

        return IDAT;
    }

    pure ubyte[] makeAncillary()
    {
        throw new Exception("Not implemented.");
    }

    pure ubyte[] makeIEND()
    {
        const ubyte[] chunkIEND = [0x0, 0x0, 0x0, 0x0];
        const ubyte[] chunkType = [0x49, 0x45, 0x4E, 0x44];
        ubyte[] IEND = chunkIEND ~ chunkType ~ this.makeCrc(chunkType);

        return IEND;
    }

    /**
   *  Calculate from chunk data. 
   */
    pure ref auto makeCrc(in ubyte[] data)
    {
        ubyte[4] crc;
        data.crc32Of.each!((idx, a) => crc[3 - idx] = a);
        return crc;
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
                    filteredAve = this.pixel.grayscale.to!(immutable ubyte[][]).ave;
                    filteredPaeth = this.pixel.grayscale.to!(immutable ubyte[][]).paeth;
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

                    R = tmpR.to!(immutable ubyte[][]).ave;
                    G = tmpG.to!(immutable ubyte[][]).ave;
                    B = tmpB.to!(immutable ubyte[][]).ave;
                    A = tmpA.to!(immutable ubyte[][]).ave;
                    filteredAve = Pixel(R, G, B, A).Pixel;

                    R = tmpR.to!(immutable ubyte[][]).paeth;
                    G = tmpG.to!(immutable ubyte[][]).paeth;
                    B = tmpB.to!(immutable ubyte[][]).paeth;
                    A = tmpA.to!(immutable ubyte[][]).paeth;
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
            foreach (idx, min; minIndex.array.to!(ubyte[]).parallel())
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
