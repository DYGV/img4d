module img4d.img4d;

import img4d.img4d_lib.decode,
	   img4d.img4d_lib.encode,
	   img4d.img4d_lib.filter,
	   img4d.img4d_lib.edge,
	   img4d.img4d_lib.template_matching,
	   img4d.img4d_lib.quality_evaluation,
	   img4d.img4d_lib.threshold,
	   img4d.img4d_lib.fourier;

import std.stdio,
	   std.array,
	   std.bitmanip,
	   std.conv,
	   std.algorithm,
	   std.range,
	   std.complex,
	   std.math,
	   std.file : exists;

enum{
	R,
	G,
	B,
	A
}

enum filterTypes{
	None,
	Sub,
	Up,
	Average,
	Paeth
}

enum colorTypes{
	grayscale,
	trueColor = 2,
	indexColor,
	grayscaleA,
	trueColorA = 6,
}

struct Header{
	this(in int width, in int height, in int bitDepth, in int colorType,
			in int compressionMethod, in int filterMethod, in int interlaceMethod, ubyte[] crc){

		_width = width;
		_height = height;
		_bitDepth = bitDepth;
		_colorType = colorType;
		_compressionMethod = compressionMethod;
		_filterMethod = filterMethod;
		_interlaceMethod = interlaceMethod;
		_crc = crc;
	}

	@property{
		pure void width(ref int width){
			_width = width;
		}

		pure void height(ref int height){
			_height = height;
		}

		pure void bitDepth(ref int bitDepth){
			_bitDepth = bitDepth;
		}

		pure void colorType(int colorType){
			_colorType = colorType;
		}

		pure void compressionMethod(ref int compressionMethod){
			_compressionMethod = compressionMethod;
		}

		pure void filterMethod(ref int filterMethod){
			_filterMethod = filterMethod;
		}

		pure void interlaceMethod(ref int interlaceMethod){
			_interlaceMethod = interlaceMethod;
		}

		pure void crc(ref ubyte[] crc){
			_crc = crc;
		}

		pure ref int width(){
			return _width;
		}

		pure ref int height(){
			return _height;
		}

		pure ref int bitDepth(){
			return _bitDepth;
		}

		pure ref int colorType(){
			return _colorType;
		}

		pure ref int compressionMethod(){
			return _compressionMethod;
		}

		pure ref int filterMethod(){
			return _filterMethod;
		}

		pure ref int interlaceMethod(){
			return _interlaceMethod;
		}

		pure ref ubyte[] crc(){
			return _crc;
		}
	}

	private:
	int _width, _height, _bitDepth, _colorType, _compressionMethod,
		_filterMethod, _interlaceMethod;
	ubyte[] _crc;
}

struct Pixel{

	this(ref ubyte[][] R, ref ubyte[][] G, ref ubyte[][] B){
		_R = R;
		_G = G;
		_B = B;
		type = colorTypes.trueColor;
	}

	this(ref ubyte[][] R, ref ubyte[][] G, ref ubyte[][] B, ref ubyte[][] A){
		_R = R;
		_G = G;
		_B = B;
		_A = A;
		type = colorTypes.trueColorA;
		isAlpha = true;
	}

	this(ref ubyte[][] grayscale){
		_grayscale = grayscale;
		type = colorTypes.grayscale;
		isGray = true;
	}

	this(ref ubyte[][] grayscale, ref ubyte[][] A){
		_grayscale = grayscale;
		_A = A;
		type = colorTypes.grayscaleA;
		isGray = true;
		isAlpha = true;
	}

	@property{
		pure void R(ref ubyte[][] R) @nogc {
			_R = R;
		}

		pure void G(ref ubyte[][] G) @nogc {
			_G = G;
		}

		pure void B(ref ubyte[][] B) @nogc {
			_B = B;
		}

		pure void A(ref ubyte[][] A) @nogc {
			_A = A;
		}

		pure void grayscale(ref ubyte[][] grayscale) @nogc {
			_grayscale = grayscale;
		}

		pure ref ubyte[][] R() @nogc {
			return _R;
		}

		pure ref ubyte[][] G() @nogc {
			return _G;
		}

		pure ref ubyte[][] B() @nogc {
			return _B;
		}

		pure ref ubyte[][] A() @nogc {
			return _A;
		}

		pure ref ubyte[][] grayscale() @nogc {
			return _grayscale;
		}

		ref ubyte[][] Pixel(){
			switch(type) with(colorTypes){
				case trueColor:
					_RGB = combine(_R, _G, _B);
					break;
				case trueColorA:
					_RGB = combine(_R, _G, _B, _A);
					break;
				case grayscale:
					_RGB = combine(_grayscale);
					break;
				case grayscaleA:
					_RGB = combine(_grayscale, _A);
					break;
				default:
					break;
			}
			return _RGB;
		}
	}

	auto combine(ubyte[][] type_1, ubyte[][] type_2=[], 
			ubyte[][] type_3=[], ubyte[][] type_4=[]){
		auto combined = [appender!(ubyte[])];
		combined.length = type_1.length;
		for(int i; i<type_1.length; i++){
			for(int j=0; j<type_1.front.length; j++){
				combined[][i].put(type_1[i][j]);
				if(!type_2.empty) combined[][i].put(type_2[i][j]);
				if(!type_3.empty) combined[][i].put(type_3[i][j]);
				if(!type_4.empty) combined[][i].put(type_4[i][j]);
			}
		}
		return combined.map!(a=> a[]).array;
	}

	private:
		ubyte[][] _R, _G, _B, _A, _RGB, _grayscale;
		ubyte[] _tmp;
		ubyte type;
		bool isGray = false, 
			 isAlpha = false;
}

class Img4d{
	Header header;

	bool isAlpha(int colorType){
		alias type = colorType;
		with (colorTypes){
			return (type == trueColor || type == indexColor) ? false : true;
		}
	}

	@property bool isGrayscale(int colorType){
		alias type = colorType;
		with (colorTypes){
			return (type == grayscale || type == grayscaleA) ? true : false;
		}
	}

	Pixel setEachChannelsToPixel(ubyte[][][] channels, bool isGray, bool isAlpha){
		if(isGray){
			return isAlpha
				? Pixel(channels[0], channels[1]) // gray, alpha
				: Pixel(channels[0]); // gray
		}else{
			return isAlpha
				? Pixel(channels[0], channels[1], channels[2], channels[3]) // RGBA
				: Pixel(channels[0], channels[1], channels[2]); // RGB
		}
	}

	auto getChannels(Pixel pixel){
		if(pixel.isGray){
			return pixel.isAlpha ? [pixel.grayscale, pixel.A] : [pixel.grayscale];
		}else{
			return pixel.isAlpha
				? [pixel.R, pixel.G, pixel.B, pixel.A]
				: [pixel.R, pixel.G, pixel.B];
		}
	}

	ref auto load(string filename){
		if(!exists(filename))
			throw new Exception("Not found the file.");
		Decode decode = new Decode(this.header);
		auto data = decode.parse(filename);
		this.header = decode.header;
		return data;
	}

	bool save(ref Pixel pix, in string filename){
		this.header.colorType = pix.type;
		Encode encode = new Encode(this.header, pix);
		ubyte[] data = encode.makeIHDR ~ encode.makeIDAT ~ encode.makeIEND;
		auto file = File(filename, "w");
		file.rawWrite(data);
		file.flush();
		return true;
	}

	bool save(ref Pixel pix, in string filename, in ubyte[] ancillary_chunks){
		this.header.colorType = pix.type;
		Encode encode = new Encode(this.header, pix);
		ubyte[] data = encode.makeIHDR ~ ancillary_chunks ~ encode.makeIDAT ~ encode.makeIEND;
		auto file = File(filename, "w");
		file.rawWrite(data);
		file.flush();
		return true;
	}

	// Canny Edge Detection (Defective)
	auto canny(T)(T[][] actualData, int tMin, int tMax){
		double[][] gaussian = [
			[0.0625, 0.125, 0.0625
			], [0.125, 0.25, 0.125], [0.0625, 0.125, 0.0625]];
		double[][] sobelX = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
		double[][] sobelY = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]];

		auto G = actualData.differential(gaussian);
		auto Gx = G.differential(sobelX);
		auto Gy = G.differential(sobelY);
		double[][] Gr = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);
		double[][] Gth = minimallyInitializedArray!(double[][])(Gx.length, Gx[0].length);

		foreach (idx; 0 .. Gx.length){
			foreach (edx; 0 .. Gx[0].length){
				Gr[idx][edx] = sqrt(Gx[idx][edx].pow(2) + Gy[idx][edx].pow(2));
				Gth[idx][edx] = ((atan2(Gy[idx][edx], Gx[idx][edx]) * 180) / PI);
			}
		}

		auto approximateG = Gr.gradient(Gth);
		auto edge = approximateG.hysteresis(tMin, tMax);
		return edge;
	}

	Pixel rgbToGrayscale(Pixel pix){
		with (this.header) with (colorTypes){
			if (colorType != trueColor && colorType != trueColorA)
				throw new Exception("The color type must be true color.");
		}
		ubyte[][] gray = new ubyte[][](this.header.height);
		for(int i=0; i<this.header.height;i++){
			for(int j=0; j<this.header.width; j++){
				gray[i] ~= (pix.R[i][j] + pix.G[i][j] + pix.B[i][j]) / 3;
			}
		}
		if(pix.A.empty){
			this.header.colorType = colorTypes.grayscale;
			return Pixel(gray);
		}else{
			this.header.colorType = colorTypes.grayscaleA;
			return Pixel(gray, pix.A);
		}	
	}

	Complex!(double)[][] dft(T)(T[][] data, bool isDFT = true){
		Complex!(double)[][] dft_matrix;
		dft_matrix.length = this.header.height;
		Fourier fourier = new Fourier(this.header);
		for (int i = 0; i < this.header.height; i++){
			dft_matrix[i] = fourier.dft(data[i].to!(Complex!(double)[]), isDFT);
		}
		dft_matrix = fourier.transpose(dft_matrix);

		for (int i = 0; i < this.header.height; i++){
			dft_matrix[i] = fourier.dft(dft_matrix[i], isDFT);
		}
		dft_matrix = fourier.transpose(dft_matrix);
		return dft_matrix;
	}

	Complex!(double)[][] lpf(Complex!(double)[][] dft_matrix, int radius = 50){
		Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(
				this.header.height, this.header.width);
		int center = this.header.height / 2;
		for (int i = 0; i < this.header.height; i++){
			for (int j = 0; j < this.header.width; j++){
				if ((i - center) * (i - center) + (j - center) * (j - center) < radius * radius){
					dest[i][j] = dft_matrix[i][j];
				}else{
					dest[i][j] = complex(0, 0);
				}
			}
		}
		return dest;
	}

	Complex!(double)[][] hpf(Complex!(double)[][] dft_matrix, int radius = 50){
		Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(
				this.header.height, this.header.width);
		int center = this.header.height / 2;
		for (int i = 0; i < this.header.height; i++){
			for (int j = 0; j < this.header.width; j++){
				if ((i - center) * (i - center) + (j - center) * (j - center) < radius * radius){
					dest[i][j] = complex(0, 0);
				}
				else{
					dest[i][j] = dft_matrix[i][j];
				}
			}
		}
		return dest;
	}

	Complex!(double)[][] bpf(Complex!(double)[][] dft_matrix, int radius_low = 20,
			int radius_high = 50){
		Complex!(double)[][] dest = uninitializedArray!(Complex!(double)[][])(
				this.header.height, this.header.width);

		int center = this.header.height / 2;
		for (int i = 0; i < this.header.height; i++){
			for (int j = 0; j < this.header.width; j++){
				auto r_circle = (i - center) * (i - center) + (j - center) * (j - center);
				if ((r_circle < radius_high * radius_high) & (r_circle > radius_low * radius_low)){
					dest[i][j] = dft_matrix[i][j];
				}else{
					dest[i][j] = complex(0, 0);
				}
			}
		}
		return dest;

	}

	// deprecated (take a lot of time because of using dft)
	ubyte[][] psd(Complex!(double)[][] dft_matrix){
		ubyte[][] dest = uninitializedArray!(ubyte[][])(this.header.height, this.header.width);
		for (int i = 0; i < this.header.height; ++i){
			for (int j = 0; j < this.header.width; ++j){
				double _power_spectrum = (10 * floor(log(dft_matrix[i][j].abs)));
				ubyte power_spectrum;
				if (_power_spectrum < 0){
					power_spectrum = 0;
				}else if (_power_spectrum > 255){
					power_spectrum = 255;
				}else{
					power_spectrum = _power_spectrum.to!ubyte;
				}
				dest[i][j] = power_spectrum;
			}
		}
		Fourier fourier = new Fourier(this.header);
		return fourier.shift(dest);
	}

	enum ThresholdType{
		simple,
		// adaptive,
	}

	auto threshold(ubyte[][] grayscale, ThresholdType type, int thresholdValue = 127){
		Threshold t = new Threshold(this.header, grayscale);
		ubyte[][] result_threshold;
		with (ThresholdType) switch (type){
			case simple:
				result_threshold = t.simple(thresholdValue);
				break;
			default:
				break;
		}
		return result_threshold;
	}

	pure auto differ(T)(ref T[][] origin, ref T[][] target){
		T[][] diff;
		origin.each!((idx, a) => diff ~= (target[idx][] -= a[]).map!(b => abs(b)).array);
		return diff;
	}

	pure auto mask(T)(ref T[][][] colorTarget, ref T[][] gray){
		T[][] masked;
		masked.length = gray.length;
		gray.each!((idx, a) => a.each!((edx, b) => masked[idx] ~= b == 255
					? colorTarget[idx][edx] : [0, 0, 0]));
		return masked;
	}

	int[] pixelHistgram(ubyte[][] data){
		ubyte[] joined_data = data.join;
		int[] hist;
		hist.length = ubyte.max + 1;
		for (int i = 0; i < joined_data.length; i++){
			int pix = joined_data[i];
			hist[pix] += 1;
		}
		return hist;
	}

	void gammaCorrection(ref ubyte[][] data, in double gamma){
		double pixel_max = data.join.maxElement.to!double;

		for (int i = 0; i < this.header.height; i++){
			for (int j = 0; j < this.header.width; j++){
				data[i][j] = floor(pixel_max * pow(data[i][j].to!double / pixel_max, 1 / gamma))
					.to!ubyte;
			}
		}
	}

	void rectangle(ref ubyte[][] src, int[] pos, int[] size){
		for (int i = pos[0]; i < pos[0] + size[0]; i++){
			for (int j = pos[1]; j < pos[1] + size[1]; j++){
				src[pos[0]][j] = 255;
				src[pos[0] + size[1]][j] = 255;
				src[i][pos[1]] = 255;
				src[i][pos[1] + size[1]] = 255;
			}
		}
	}

	enum MatchingType{
		SSD,
		SAD,
		NCC,
		ZNCC,
	}

	auto templateMatching(Header templateHeader, Header inputHeader,
			ubyte[][] templateImage, ubyte[][] inputImage, MatchingType type){
		TemplateMatching template_matching = new TemplateMatching(templateHeader,
				inputHeader, templateImage, inputImage);
		int[] pos;
		switch (type) with (MatchingType){
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

	enum QualityEvaluationType{
		MSE,
		NMSE,
		SNR,
		PSNR,
		MSSIM,
	}

	auto qualityEvaluation(ubyte[][] img_reference, ubyte[][] img_evaluation,
			QualityEvaluationType type){
		QualityEvaluation quality_evaluation = new QualityEvaluation(this.header,
				img_reference, img_evaluation);
		double score;
		switch (type) with (QualityEvaluationType){
			case MSE:
				score = quality_evaluation.MSE;
				break;
			case NMSE:
				score = quality_evaluation.NMSE;
				break;
			case SNR:
				score = quality_evaluation.SNR;
				break;
			case PSNR:
				score = quality_evaluation.PSNR;
				break;
			case MSSIM:
				score = quality_evaluation.MSSIM;
				break;
			default:
				break;
		}
		return score;
	}

	Pixel rotate(Pixel pixel, int degrees){
		int h = this.header.height;
		int w = this.header.width;
		int half_h = h / 2;
		int half_w = w / 2;
		double sin_theta = sin(degrees * (PI / 180));
		double cos_theta = cos(degrees * (PI / 180));

		auto channels = getChannels(pixel);
		ubyte[][][] transformed = new ubyte[][][]
			(channels.length, this.header.height, this.header.width);
		for(int c=0; c<channels.length; c++){
			ubyte[][] img = channels[c];
			for(int i=0; i<h; i++){
				int center_h = i - half_h;
				double center_h_sin_theta = center_h * sin_theta;
				double center_h_cos_theta = center_h * cos_theta;
				for(int j=0; j<w; j++){
					int center_w = j - half_w;
					int x_ = round((center_w * cos_theta) - center_h_sin_theta + half_w).to!int;
					int y_ = round((center_w * sin_theta) + center_h_cos_theta + half_h).to!int;
					if((x_ >= 0) && (y_ >= 0) && (x_ < w) && (y_ < h)){
						transformed[c][i][j] = img[y_][x_];
					}else{
						transformed[c][i][j] = 0;
					}
				}
			}
		}
		return setEachChannelsToPixel(transformed, pixel.isGray, pixel.isAlpha);
	}

	Pixel translate(Pixel pixel, int transition_x, int transition_y){
		int h = this.header.height;
		int w = this.header.width;
		auto channels = getChannels(pixel);
		ubyte[][][] transformed = new ubyte[][][]
			(channels.length, this.header.height, this.header.width);
		for(int c=0; c<channels.length; c++){
			ubyte[][] img = channels[c];
			for(int i=0; i<h; i++){
				int y_ = h - i - transition_y;
				for(int j=0; j<w; j++){
					int x_ = w - j + transition_x;
					if((x_ > 0) && (y_ > 0) && (x_ < h) && (y_ < w)){
						transformed[c][i][j] = img[w-y_][h-x_];
					}else{
						transformed[c][i][j] = 0;
					}
				}
			}
		}
		return setEachChannelsToPixel(transformed, pixel.isGray, pixel.isAlpha);
	}
}

