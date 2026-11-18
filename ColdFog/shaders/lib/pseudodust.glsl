// dust blown by the wind library
#ifndef PSEUDODUST
#define PSEUDODUST

#define CF_DUST_LAYERS 4
const float CF_DUST_NEAR = 2.0;
const float CF_DUST_FAR = 26.0;
const float CF_DUST_ANGLE = 0.0016;
const float CF_DUST_SPACE = 14.0;
const float CF_DUST_DENSITY = 0.35;
const float CF_DUST_LEN = 3.0;
const float CF_DUST_RATE = 0.12;
const float CF_DUST_FADE = 0.05;
const float CF_DUST_CALM = 0.2;
const float CF_DUST_WIND_LOW = 0.5;
const float CF_DUST_WIND_HIGH = 6.0;
const float CF_DUST_TOP = 6.0;
const vec3 CF_DUST_TINT = vec3(0.55, 0.45, 0.33);

// how hard the wind blows from 0 to 1
float cfDustWind() {
  return smoothstep(CF_DUST_WIND_LOW, CF_DUST_WIND_HIGH, length(uWind));
}

// where a grain is along its path at the phase f, the path is a J lying down, a straight run with the wind and a hook that curls up at the end
vec3 cfDustJ(float f, vec2 dir, float len) {
  const float STEM = 0.62;
  float s = min(f / STEM, 1.0);
  float a = clamp((f - STEM) / (1.0 - STEM), 0.0, 1.0);
  float R = 0.2 * len;
  float ang = a * 2.6;
  float fwd = len * s + R * sin(ang);
  float up = R * (1.0 - cos(ang));
  return vec3(dir.x * fwd, up, dir.y * fwd);
}

// how much of the pixel is covered by grains of dust
float cfDust(vec3 dir, float surf) {
  float wind = cfDustWind();
  float amt = mix(CF_DUST_CALM, 1.0, wind);
  vec2 wd = cfWaveDir();
  vec2 side = vec2(-wd.y, wd.x);
  float len = CF_DUST_LEN * (0.5 + 0.5 * wind);
  float ground = uEye.y - 1.7;
  float sum = 0.0;
  for (int i = 0; i < CF_DUST_LAYERS; i++) {
    float t = CF_DUST_NEAR * pow(CF_DUST_FAR / CF_DUST_NEAR, float(i) / float(CF_DUST_LAYERS - 1));
    float inFront = 1.0 - smoothstep(surf - 0.8, surf, t);
    if (inFront <= 0.0) continue;
    vec3 p = uEye + dir * t;
    float height = p.y - ground;
    float band = smoothstep(-0.3, 0.2, height) * (1.0 - smoothstep(0.5 * CF_DUST_TOP, CF_DUST_TOP, height));
    if (band <= 0.0) continue;
    // the gusts come in long bands and each band has its own phase
    float f = fract(uTime * CF_DUST_RATE + cfNoise(vec2(dot(p.xz, wd) * 0.035, dot(p.xz, side) * 0.06)) * 1.5);
    float life = smoothstep(0.0, 0.12, f) * (1.0 - smoothstep(0.78, 1.0, f));
    if (life <= 0.0) continue;
    vec3 q = p - cfDustJ(f, wd, len);
    float r = t * CF_DUST_ANGLE;
    float s = r * CF_DUST_SPACE;
    vec3 cell = floor(q / s);
    vec3 h = cfMoteHash(mod(cell, 61.0) + float(i) * 7.0);
    if (h.x > CF_DUST_DENSITY * amt) continue;
    vec3 c = (cell + 0.5 + (h - 0.5) * 0.5) * s;
    float m = 1.0 - smoothstep(0.3, 1.0, length(q - c) / r);
    sum += m * life * band * inFront * exp(-t * CF_DUST_FADE) * (0.5 + 0.5 * h.y);
  }
  return clamp(sum, 0.0, 1.0);
}

#endif
