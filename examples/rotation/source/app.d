import img4d;

int main(){
	Img4d img = new Img4d();
	Pixel original_pix = img.load("../../png_img/lena.png");
	Pixel transformed = img.rotate(original_pix, 45);
	img.save(transformed, "../../png_img/affine_rotation.png");
	return 0;
}

