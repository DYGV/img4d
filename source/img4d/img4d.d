module img4d.img4d;

import img4d_lib.decode, img4d_lib.encode, img4d_lib.filter,
    img4d_lib.color_space, img4d_lib.edge;

import std.stdio, std.array, std.bitmanip, std.conv, std.algorithm, std.range, std.file : exists;

int lengthPerPixel;

enum
{
    R,
    G,
    B,
    A
}

enum filterTypes
{
    None,
    Sub,
    Up,
    Average,
    Paeth
}

enum colorTypes
{
    grayscale,
    trueColor = 2,
    indexColor,
    grayscaleA,
    trueColorA = 6,
}

struct Header
{
    this(in int width, in int height, in int bitDepth, in int colorType,
            in int compressionMethod, in int filterMethod, in int interlaceMethod, ubyte[] crc)
    {

        _width = width;
        _height = height;
        _bitDepth = bitDepth;
        _colorType = colorType;
        _compressionMethod = compressionMethod;
        _filterMethod = filterMethod;
        _interlaceMethod = interlaceMethod;
        _crc = crc;
    }

    @property
    {
        pure void width(ref int width)
        {
            _width = width;
        }

        pure void height(ref int height)
        {
            _height = height;
        }

        pure void bitDepth(ref int bitDepth)
        {
            _bitDepth = bitDepth;
        }

        pure void colorType(int colorType)
        {
            _colorType = colorType;
        }

        pure void compressionMethod(ref int compressionMethod)
        {
            _compressionMethod = compressionMethod;
        }

        pure void filterMethod(ref int filterMethod)
        {
            _filterMethod = filterMethod;
        }

        pure void interlaceMethod(ref int interlaceMethod)
        {
            _interlaceMethod = interlaceMethod;
        }

        pure void crc(ref ubyte[] crc)
        {
            _crc = crc;
        }

        pure ref int width()
        {
            return _width;
        }

        pure ref int height()
        {
            return _height;
        }

        pure ref int bitDepth()
        {
            return _bitDepth;
        }

        pure ref int colorType()
        {
            return _colorType;
        }

        pure ref int compressionMethod()
        {
            return _compressionMethod;
        }

        pure ref int filterMethod()
        {
            return _filterMethod;
        }

        pure ref int interlaceMethod()
        {
            return _interlaceMethod;
        }

        pure ref ubyte[] crc()
        {
            return _crc;
        }
    }

private:
    int _width, _height, _bitDepth, _colorType, _compressionMethod,
        _filterMethod, _interlaceMethod;
    ubyte[] _crc;
}

struct Pixel
{

    this(ref ubyte[][] R, ref ubyte[][] G, ref ubyte[][] B)
    {
        _R = R;
        _G = G;
        _B = B;
    }

    this(ref ubyte[][] R, ref ubyte[][] G, ref ubyte[][] B, ref ubyte[][] A)
    {
        _R = R;
        _G = G;
        _B = B;
        _A = A;
    }

    this(ref ubyte[][] grayscale)
    {
        _grayscale = grayscale;
    }

    @property
    {
        pure void R(ref ubyte[][] R)
        {
            _R = R;
        }

        pure void G(ref ubyte[][] G)
        {
            _G = G;
        }

        pure void B(ref ubyte[][] B)
        {
            _B = B;
        }

        pure void A(ref ubyte[][] A)
        {
            _A = A;
        }

        pure void grayscale(ref ubyte[][] grayscale)
        {
            _grayscale = grayscale;
        }

        pure ref ubyte[][] R()
        {
            return _R;
        }

        pure ref ubyte[][] G()
        {
            return _G;
        }

        pure ref ubyte[][] B()
        {
            return _B;
        }

        pure ref ubyte[][] A()
        {
            return _A;
        }

        pure ref ubyte[][] Pixel()
        {
            if (!_RGB.empty)
                return _RGB;

            _RGB = (A.empty) ? [_R.join, _G.join, _B.join].transposed.join.chunks(_R[0].length * 3)
                .array : [_R.join, _G.join, _B.join, _A.join].transposed.join.chunks(_R[0].length * 4)
                .array;

            return _RGB;
        }

        pure ref ubyte[][] grayscale()
        {
            return _grayscale;
        }
    }

private:
    ubyte[][] _R, _G, _B, _A, _RGB, _grayscale;
    ubyte[] _tmp;
}

bool isColorNoneAlpha(int colorType)
{
    alias type = colorType;
    with (colorTypes)
    {
        return (type == trueColor || type == indexColor) ? true : false;
    }
}

bool isGrayscale(int colorType)
{
    alias type = colorType;
    with (colorTypes)
    {
        return (type == grayscale || type == grayscaleA) ? true : false;
    }
}

ref auto load(ref Header header, string filename)
{
    if (!exists(filename))
        throw new Exception("Not found the file.");
    ubyte[][][] rgb, joinRGB;

    Decode decode = new Decode(header);
    auto data = decode.parse(filename);
    header = decode.hdr;
    if (header.colorType.isGrayscale)
    {
        alias grayscale = data;
        return Pixel(grayscale);
    }

    data.each!(a => rgb ~= [a.chunks(lengthPerPixel).array]);
    rgb.each!(a => joinRGB ~= a.joinVertical);
    auto pix = joinRGB.transposed;
    ubyte[][] R = pix[R].array.to!(ubyte[][]);
    ubyte[][] G = pix[B].array.to!(ubyte[][]);
    ubyte[][] B = pix[B].array.to!(ubyte[][]);
    ubyte[][] A = pix[A].array.to!(ubyte[][]);

    return (header.colorType.isColorNoneAlpha) ? Pixel(R, G, B) : Pixel(R, G, B, A);
}

bool save(ref Header header, ref Pixel pix, string filename)
{
    Encode encode = new Encode(header, pix);
    ubyte[] data = encode.makeIHDR ~ encode.makeIDAT ~ encode.makeIEND;
    auto file = File(filename, "w");
    file.rawWrite(data);
    file.flush();

    return true;
}

// Canny Edge Detection (Defective)
auto canny(T)(T[][] actualData, int tMin, int tMax)
{
    double[][] gaussian = [[0.0625, 0.125, 0.0625], [0.125, 0.25, 0.125], [0.0625, 0.125, 0.0625]];
    double[][] sobelX = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
    double[][] sobelY = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]];

    auto G = actualData.differential(gaussian);
    auto Gx = G.differential(sobelX);
    auto Gy = G.differential(sobelY);
    double[][] Gr = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);
    double[][] Gth = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);

    foreach (idx; 0 .. Gx.length)
    {
        foreach (edx; 0 .. Gx[0].length)
        {
            Gr[idx][edx] = sqrt(Gx[idx][edx].pow(2) + Gy[idx][edx].pow(2));
            Gth[idx][edx] = ((atan2(Gy[idx][edx], Gx[idx][edx]) * 180) / PI);
        }
    }

    auto approximateG = Gr.gradient(Gth);
    auto edge = approximateG.hysteresis(tMin, tMax);

    return edge;
}

ref auto rgbToGrayscale(ref Header header, ref Pixel pix, bool fastMode = false)
{
    ubyte[][][] color;
    with (header) with (colorTypes)
    {
        if (colorType != trueColor && colorType != trueColorA)
            throw new Exception("invalid format.");
        pix.Pixel.each!(n => color ~= n.chunks(lengthPerPixel).array);
        if (colorType == trueColorA)
            color.each!((idx, a) => a.each!((edx, b) => color[idx][edx] = b.remove(3)));
    }

    return (fastMode == true) ? color.toGrayscale(fastMode) : color.toGrayscale;
}

pure auto toBinary(T)(ref T[][] gray, T threshold = 127)
{
    // Simple thresholding 

    T[][] bin;
    gray.each!(a => bin ~= a.map!(b => b < threshold ? 0 : 255).array);
    return bin;
}

pure auto toBinary(T)(T[][] array)
{
    uint imageH = array.length;
    uint imageW = array[0].length;
    int vicinityH = 3;
    int vicinityW = 3;
    int h = vicinityH / 2;
    int w = vicinityW / 2;

    auto output = minimallyInitializedArray!(typeof(array))(imageH, imageW);
    output.each!(a => fill(a, 0));

    foreach (i; h .. imageH - h)
    {
        foreach (j; w .. imageW - w)
        {
            int t = 0;
            foreach (m; 0 .. vicinityH)
            {
                foreach (n; 0 .. vicinityW)
                {
                    t += array[i - h + m][j - w + n];
                }
            }
            if ((t / (vicinityH * vicinityW)) < array[i][j])
                output[i][j] = 255;
        }
    }
    return output;
}

pure auto differ(T)(ref T[][] origin, ref T[][] target)
{
    T[][] diff;
    origin.each!((idx, a) => diff ~= (target[idx][] -= a[]).map!(b => abs(b)).array);

    return diff;
}

pure auto mask(T)(ref T[][][] colorTarget, ref T[][] gray)
{
    T[][] masked;
    masked.length = gray.length;
    gray.each!((idx, a) => a.each!((edx, b) => masked[idx] ~= b == 255
            ? colorTarget[idx][edx] : [0, 0, 0]));

    return masked;
}
