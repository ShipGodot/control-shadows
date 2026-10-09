// More on the magic behind this code: https://madebyevan.com/shaders/fast-rounded-rectangle-shadows/
// Original code by: https://www.shadertoy.com/view/lXlcW7
shader_type canvas_item;
uniform float blur_sigma = 10.0;
uniform vec4 shadow_color : source_color = vec4(vec3(0.0), 1.0);
uniform float corner_radius = 2.0;
uniform bool inset = false;
uniform vec2 target_size = vec2(64, 64);
uniform vec2 shadow_box_size = vec2(128, 128);
uniform vec2 offset = vec2(0, 0);


// approximates the error function, needed for the gaussian integral
vec2 erf(vec2 x) {
	vec2 s = sign(x), a = abs(x);
	x = 1.0 + (0.278393 + (0.230389 + 0.078108 * (a * a)) * a) * a;
	x *= x;
	return s - s / (x * x);
}


float gaussian(float x, float sigma) {
	const float pi = 3.141592653589793;
	return exp(-(x * x) / (2.0 * sigma * sigma)) / (sqrt(2.0 * pi) * sigma);
}


// return the blurred mask along the x dimension
float roundedBoxShadowX(float x, float y, float sigma, float corner, vec2 half_size) {
	float delta = min(half_size.y - corner - abs(y), 0.0);
	float curved = half_size.x - corner + sqrt(max(0.0, corner * corner - delta * delta));
	vec2 integral = 0.5 + 0.5 * erf((x + vec2(-curved, curved)) * (sqrt(0.5) / sigma));
	return integral.y - integral.x;
}


// return the mask for the shadow of a box from lower to upper
float roundedBoxShadow(vec2 lower, vec2 upper, vec2 point, float sigma, float radius) {
	// Center everything to make the math easier
	vec2 center = (lower + upper) * 0.5;
	vec2 half_size = (upper - lower) * 0.5;
	point -= center;

	// The signal is only non-zero in a limited range, so don't waste samples
	float low = point.y - half_size.y;
	float high = point.y + half_size.y;
	float start = clamp(-3.0 * sigma, low, high);
	float end = clamp(3.0 * sigma, low, high);

	// Accumulate samples (we can get away with surprisingly few samples)
	float step = (end - start) / 4.0;
	float y = start + step * 0.5;
	float value = 0.0;
	for (int i = 0; i < 4; i++) {
		value += roundedBoxShadowX(point.x, point.y - y, sigma, radius, half_size) * gaussian(y, sigma) * step;
		y += step;
	}

	return value;
}


// per-pixel "random" number between 0 and 1
float random(vec2 uv) {
	return fract(sin(dot(vec2(12.9898, 78.233), uv.xy)) * 43758.5453);
}


// blend two colors by alpha
vec4 blend(vec4 src, vec4 append) {
	return vec4(src.rgb * (1.0 - append.a) + append.rgb * append.a, 1.0 - (1.0 - src.a) * (1.0 - append.a));
}


bool clip_rect(vec2 pos, vec2 upper_left_corner, vec2 bottom_right_corner, float radius) {
	vec2 size = bottom_right_corner - upper_left_corner;
	vec2 center = upper_left_corner + size * 0.5;
	vec2 half_size = size * 0.5;
	vec2 q = abs(pos - center) - half_size + radius;
	float dist = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - radius;
	return dist <= 0.0;
}


void fragment() {
	vec2 upper_left_corner = floor(shadow_box_size / 2.0 - target_size / 2.0);
	vec2 bottom_right_corner = upper_left_corner + target_size;
	vec2 position = vec2(UV.x * shadow_box_size.x, UV.y * shadow_box_size.y);
		
    float frag_alpha = roundedBoxShadow(
		upper_left_corner,
		bottom_right_corner,
		position + offset,
		blur_sigma,
		corner_radius
    );

	frag_alpha = mix(frag_alpha, mix(0.0, 1.0 - frag_alpha, float(clip_rect(position, upper_left_corner, bottom_right_corner, corner_radius))), float(inset));
	// dither the alpha to break up color bands
	frag_alpha += (random(UV) - 0.5) / 128.0;

	COLOR = blend(vec4(shadow_color.rgb, 0.0), vec4(shadow_color.rgb, shadow_color.a * frag_alpha));
}