module img4d.img4d;

import img4d_lib.decode, img4d_lib.encode, img4d_lib.filter,
    img4d_lib.color_space, img4d_lib.edge, img4d_lib.template_matching;

import std.stdio, std.array, std.bitmanip, std.conv, std.algorithm, std.range, std.file : exists;
import img4d_lib.fourier;
import std.complex;
import std.math;

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

        ref ubyte[][] Pixel()
        {
            if (!_RGB.empty)
                return _RGB;
            _RGB.length = R.length;
            if (A.empty)
            {
                foreach (idx; 0 .. R.length)
                {
                    foreach (edx; 0 .. R.front.length)
                    {
                        _RGB[idx] ~= [R[idx][edx]] ~ [G[idx][edx]] ~ [B[idx][edx]];
                    }
                }
            }
            else
            {
                foreach (idx; 0 .. R.length)
                {
                    foreach (edx; 0 .. R.front.length)
                    {
                        _RGB[idx] ~= [R[idx][edx]] ~ [G[idx][edx]] ~ [B[idx][edx]] ~ [A[idx][edx]];
                    }
                }

            }
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
    ubyte[][] G = pix[G].array.to!(ubyte[][]);
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

bool save(ref Header header, ref Pixel pix, string filename, ubyte[] ancillary_chunks)
{
    Encode encode = new Encode(header, pix);
    ubyte[] data = encode.makeIHDR ~ ancillary_chunks ~ encode.makeIDAT ~ encode.makeIEND;
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

Complex!(double)[][] dft(T)(T[][] data, Header hdr, bool isDFT = true)
{
    Complex!(double)[][] dft_matrix;
    dft_matrix.length = hdr.height;

    for (int i = 0; i < hdr.height; i++)
    {
        dft_matrix[i] = _dft(data[i].to!(Complex!(double)[]), hdr.width, isDFT);
    }
    dft_matrix = transpose(dft_matrix, hdr.height, hdr.width);

    for (int i = 0; i < hdr.height; i++)
    {
        dft_matrix[i] = _dft(dft_matrix[i], hdr.width, isDFT);
    }
    dft_matrix = transpose(dft_matrix, hdr.height, hdr.width);
    return dft_matrix;
}

Complex!(double)[][] lpf(Complex!(double)[][] dft_matrix, Header hdr, int radius = 50)
{
    Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(hdr.height, hdr.width);
    int center = hdr.height / 2;
    for (int i = 0; i < hdr.height; i++)
    {
        for (int j = 0; j < hdr.width; j++)
        {
            if ((i - center) * (i - center) + (j - center) * (j - center) < radius * radius)
            {
                dest[i][j] = dft_matrix[i][j];
            }
            else
            {
                dest[i][j] = complex(0, 0);
            }
        }
    }
    return dest;
}

Complex!(double)[][] hpf(Complex!(double)[][] dft_matrix, Header hdr, int radius = 50)
{
    Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(hdr.height, hdr.width);
    int center = hdr.height / 2;
    for (int i = 0; i < hdr.height; i++)
    {
        for (int j = 0; j < hdr.width; j++)
        {
            if ((i - center) * (i - center) + (j - center) * (j - center) < radius * radius)
            {
                dest[i][j] = complex(0, 0);
            }
            else
            {
                dest[i][j] = dft_matrix[i][j];
            }
        }
    }
    return dest;
}

Complex!(double)[][] bpf(Complex!(double)[][] dft_matrix, Header hdr,
        int radius_low = 20, int radius_high = 50)
{
    Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(hdr.height, hdr.width);

    int center = hdr.height / 2;
    for (int i = 0; i < hdr.height; i++)
    {
        for (int j = 0; j < hdr.width; j++)
        {
            auto r_circle = (i - center) * (i - center) + (j - center) * (j - center);
            if ((r_circle < radius_high * radius_high) & (r_circle > radius_low * radius_low))
            {
                dest[i][j] = dft_matrix[i][j];
            }
            else
            {
                dest[i][j] = complex(0, 0);
            }
        }
    }
    return dest;

}

// deprecated (take a lot of time because of using dft)
ubyte[][] psd(Complex!(double)[][] dft_matrix, ref Header hdr)
{
    ubyte[][] dest = uninitializedArray!(ubyte[][])(hdr.height, hdr.width);
    for (int i = 0; i < hdr.height; ++i)
    {
        for (int j = 0; j < hdr.width; ++j)
        {
            double _power_spectrum = (10 * floor(log(dft_matrix[i][j].abs)));
            ubyte power_spectrum;
            if (_power_spectrum < 0)
            {
                power_spectrum = 0;
            }
            else if (_power_spectrum > 255)
            {
                power_spectrum = 255;
            }
            else
            {
                power_spectrum = _power_spectrum.to!ubyte;
            }
            dest[i][j] = power_spectrum;
        }
    }
    return dest.shift(hdr.height, hdr.width);
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

int[ubyte] pixelHistgram(ubyte[][] data)
{
    ubyte[] joined_data = data.join;
    int[ubyte] hist;
    foreach (idx, h; joined_data)
    {
        hist[h]++;
    }
    return hist;
}

ubyte[][] gammaCorrection(Header hdr, ubyte[][] data, double gamma)
{
    double pixel_max = data.join.maxElement.to!double;

    for (int i = 0; i < hdr.height; i++)
    {
        for (int j = 0; j < hdr.width; j++)
        {
            data[i][j] = floor(pixel_max * pow(data[i][j].to!double / pixel_max, 1 / gamma))
                .to!ubyte;
        }
    }
    return data;
}

auto rectangle(ref ubyte[][] src, int[] pos, int[] size)
{
    for (int i = pos[0]; i < pos[0] + size[0]; i++)
    {
        for (int j = pos[1]; j < pos[1] + size[1]; j++)
        {
            src[pos[0]][j] = 255;
            src[pos[0] + size[1]][j] = 255;
            src[i][pos[1]] = 255;
            src[i][pos[1] + size[1]] = 255;
        }
    }
}

enum MatchingType
{
    SSD,
    SAD,
    NCC,
    ZNCC,
}

auto templateMatching(Header templateHeader, Header inputHeader,
        ubyte[][] templateImage, ubyte[][] inputImage, int type)
{
    TemplateMatching template_matching = new TemplateMatching(templateHeader,
            inputHeader, templateImage, inputImage);
    int[] pos;
    switch (type) with (MatchingType)
    {
    case SSD:
        pos = template_matching.SSD();
        break;
    case SAD:
        pos = template_matching.SAD();
        break;
    case NCC:
        pos = template_matching.NCC();
        break;
    case ZNCC:
        pos = template_matching.ZNCC();
        break;
    default:
        break;
    }
    return pos;
}
