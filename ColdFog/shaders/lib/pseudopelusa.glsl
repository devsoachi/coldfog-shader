// dust motes library
#ifndef PSEUDOMOTES
#define PSEUDOMOTES

#define CF_MOTE_LAYERS 3
const float CF_MOTE_NEAR = 0.8;
const float CF_MOTE_FAR = 4.5;
const float CF_MOTE_ANGLE = 0.0019;
const float CF_MOTE_SPACE = 16.0;
const float CF_MOTE_MIN = 0.2;
const float CF_MOTE_LOW = 0.03;
const float CF_MOTE_HIGH = 0.25;
const float CF_MOTE_GAIN = 0.55;

vec3 cfMoteHash(vec3 p) {
  vec3 q = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
  return fract(sin(q) * 43758.5453);
}

float cfMotes(vec3 dir, float surf, float lightK) {
  float density = mix(CF_MOTE_MIN, 1.0, lightK);
  float sum = 0.0;
  for (int i = 0; i < CF_MOTE_LAYERS; i++) {
    float t = CF_MOTE_NEAR * pow(CF_MOTE_FAR / CF_MOTE_NEAR, float(i) / float(CF_MOTE_LAYERS - 1));
    float inFront = 1.0 - smoothstep(surf - 0.6, surf, t);
    if (inFront <= 0.0) continue;
    float r = t * CF_MOTE_ANGLE;
    float s = r * CF_MOTE_SPACE;
    vec3 p = uEye + dir * t;
    vec3 cell = floor(p / s);
    vec3 h = cfMoteHash(mod(cell, 61.0));
    float keep = 1.0 - step(density, h.x);
    if (keep <= 0.0) continue;
    vec3 sway = vec3(sin(uTime * 0.40 + h.x * 6.2832), sin(uTime * 0.33 + h.y * 6.2832), sin(uTime * 0.27 + h.z * 6.2832));
    vec3 c = (cell + 0.5 + (h - 0.5) * 0.3 + 0.08 * sway) * s;
    float m = 1.0 - smoothstep(0.3, 1.0, length(p - c) / r);
    float twinkle = 0.55 + 0.45 * sin(uTime * (1.5 + 2.0 * h.y) + h.z * 40.0);
    float weight = 0.4 + 0.6 * fract(h.x * 13.7);
    sum += m * twinkle * weight * inFront * (1.0 - 0.6 * (t - CF_MOTE_NEAR) / (CF_MOTE_FAR - CF_MOTE_NEAR));
  }
  return clamp(sum, 0.0, 1.0);
}

// light to add on the pixel
vec3 cfMoteGlow(vec3 lt, vec2 uv, float depth) {
  float l = dot(lt, LUMA) * uExposure * float(OPTION_EXPOSURE);
  float lightK = smoothstep(CF_MOTE_LOW, CF_MOTE_HIGH, l);
  if (lightK <= 0.0) return vec3(0.0);
  vec3 dir = normalize(scenePos(uv, 0.999) - uEye);
  float surf = depth < 1.0 ? distance(scenePos(uv, depth), uEye) : 1.0e3;
  float m = cfMotes(dir, surf, lightK);
  vec3 hue = lt / max(dot(lt, LUMA), 1.0e-6);
  return hue * (m * lightK * CF_MOTE_GAIN / max(uExposure * float(OPTION_EXPOSURE), 1.0e-3));
}

#endif
