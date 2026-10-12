// pseudofog-light library for coldFog, made by soachi | it generate random numbers and noise for pseudo-lighting effects
#ifndef PSEUDOFOG_LIGHT
#define PSEUDOFOG_LIGHT

float cfHash21(vec2 p) {
  float a = fract(dot(p, vec2(0.3183099, 0.3678794)));
  float b = fract(dot(p, vec2(0.6180340, -0.7071068)));
  float h = fract((a + 0.5) * (b + 1.5) * 97.531);
  return fract(h * 53.713 + a * 11.17 + b * 7.31);
}

vec2 cfHash22(vec2 p) {
  return vec2(cfHash21(p), cfHash21(vec2(p.y + 37.17, p.x - 19.43)));
}

// smooth value noise
float cfNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = cfHash21(i);
  float b = cfHash21(i + vec2(1.0, 0.0));
  float c = cfHash21(i + vec2(0.0, 1.0));
  float d = cfHash21(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// bayer 4x4 ordered dithering matrix, returns a float in [0, 1)
float cfBayer4(ivec2 p) {
  const float M[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
  return (M[(p.y & 3) * 4 + (p.x & 3)] + 0.5) / 16.0;
}

// own custom mist as of engine failing to include his own whose density falls off exponentially with height
float cfMistDepth(float sigma, float H, float h0, float mu, float d) {
  float x = d * mu / H;
  float k = abs(x) < 1.0e-3 ? d * (1.0 - 0.5 * x) : H / mu * (1.0 - exp(-x));   // = d * (1 - e^-x) / x, stable near 0
  return sigma * exp(-h0 / H) * k;
}

#endif
