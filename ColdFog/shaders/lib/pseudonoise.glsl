// pseudonoise library for coldFog, made by soachi | own simplex noise and the lumpy field, needs pseudofog_light first
#ifndef PSEUDONOISE
#define PSEUDONOISE

vec2 cfGrad(vec2 i) {
  return vec2(cfHash21(i), cfHash21(i + vec2(17.3, -9.1))) * 2.0 - 1.0;
}

// 2D simplex noise, about -0.9 to 0.9
float cfSimplex(vec2 p) {
  const float F2 = 0.3660254;   // (sqrt(3) - 1) / 2
  const float G2 = 0.2113249;   // (3 - sqrt(3)) / 6
  vec2 i = floor(p + (p.x + p.y) * F2);
  vec2 x0 = p - i + (i.x + i.y) * G2;
  vec2 o = x0.x > x0.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec2 x1 = x0 - o + G2;
  vec2 x2 = x0 - 1.0 + 2.0 * G2;
  vec3 t = max(0.5 - vec3(dot(x0, x0), dot(x1, x1), dot(x2, x2)), 0.0);
  t *= t;
  t *= t;
  return 70.0 * (t.x * dot(cfGrad(i), x0) + t.y * dot(cfGrad(i + o), x1) + t.z * dot(cfGrad(i + 1.0), x2));
}

// lumpy 0 to 1 field, mean about 0.5
float cfLumps(vec2 p, float t) {
  float a = abs(cfSimplex(p + vec2(t * 0.05, t * 0.03)));
  float b = abs(cfSimplex(p * 2.3 + vec2(31.7 - t * 0.04, 31.7 + t * 0.06)));
  return clamp(2.0 * (0.65 * a + 0.35 * b), 0.0, 1.0);
}

#endif
