#version 330

// ColdFog shaderpack made for viewpoint, it gives blue-green tinted dense fog, heavy fog depending on setting (using wisps, low fog and bayer calculations)
// also uses film grain, dithering, chromatic aberration and optional reduced color depth

in vec2 vUv;
uniform sampler2D uColor;
uniform sampler2D uVolume;
uniform sampler2D uBloom;
uniform int uDebugView;
uniform float uVolumeOn;
uniform float uBloomStrength;
uniform float uExposure;
uniform vec3 uFogColor;
uniform vec2 uFogRange;
uniform vec2 uHaze;
uniform float uTime;
uniform int uFrame;
uniform float uMist;
#if PIPELINE_SUN_SHAFTS
uniform sampler2D uSunShafts;
uniform float uShaftStrength;
#endif
out vec4 fragColor;
#ifndef OPTION_EXPOSURE // it needs to be up here because is a fallback
#define OPTION_EXPOSURE 1.0
#endif
#include "lib/pseudofog_light.glsl"
#include "lib/camera.glsl"
#include "lib/common.glsl"
#include "lib/fog.glsl"
#include "lib/fog_amount.glsl"
#include "lib/eye_meter.glsl"
#include "lib/purkinje.glsl"
#include "lib/tone.glsl"

#ifndef OPTION_BLUE
#define OPTION_BLUE 1.0
#endif
#ifndef OPTION_BLUESATURATION
#define OPTION_BLUESATURATION 0.35
#endif
#ifndef OPTION_BLUENESS
#define OPTION_BLUENESS 0.7
#endif
#ifndef OPTION_WARMDOWN
#define OPTION_WARMDOWN 0.6
#endif
#ifndef OPTION_BLUECONTRAST
#define OPTION_BLUECONTRAST 1.15
#endif
#ifndef OPTION_BLUEVIGNETTE
#define OPTION_BLUEVIGNETTE 0.35
#endif
#ifndef OPTION_FOG_BOOST
#define OPTION_FOG_BOOST 1.2
#endif
#ifndef OPTION_BLUEFOG
#define OPTION_BLUEFOG 0.85
#endif
#ifndef OPTION_GREENFOG
#define OPTION_GREENFOG 0.45
#endif
#ifndef OPTION_LOW_FOG
#define OPTION_LOW_FOG 0.5
#endif
#ifndef OPTION_FOG_WISPS
#define OPTION_FOG_WISPS 0.35
#endif
#ifndef OPTION_MIST
#define OPTION_MIST 0.0
#endif
#ifndef OPTION_GRAIN
#define OPTION_GRAIN 0.3
#endif
#ifndef OPTION_CHROMA
#define OPTION_CHROMA 0.25
#endif
#ifndef OPTION_GLOW
#define OPTION_GLOW 1.0
#endif
#ifndef OPTION_PIXEL
#define OPTION_PIXEL 1.0
#endif
#ifndef OPTION_COLORBITS
#define OPTION_COLORBITS 8.0
#endif
#ifndef OPTION_DITHERING
#define OPTION_DITHERING 0.6
#endif
#ifndef OPTION_WOBBLE
#define OPTION_WOBBLE 0.0
#endif
#ifndef OPTION_SKY_FOG
#define OPTION_SKY_FOG 1.0
#endif
#ifndef OPTION_SKY_FOG_DISTANCE
#define OPTION_SKY_FOG_DISTANCE 120.0
#endif
#ifndef OPTION_LIGHTCUT
#define OPTION_LIGHTCUT 0.3
#endif
#ifndef OPTION_PENETRATION
#define OPTION_PENETRATION 0.6
#endif
#ifndef OPTION_HALO
#define OPTION_HALO 1.0
#endif
#ifndef OPTION_DARKVISION
#define OPTION_DARKVISION 0.4
#endif
// viewpoint doesnt give another style than to put "OPTION_X"


const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

const float COLDFOG_MIST_SIGMA = 0.075;    // made calculation for mist - lib/pseudofog_light.glsl for more info
const float COLDFOG_MIST_HEIGHT = 12.0;

float fogDensity(vec3 pos, float dist, float linDepth, float boostExp) {
  float fog = max(fogAt(linDepth, uFogRange), hazeAt(dist, uHaze));
  // it only starts a few squares away so rooms are not fogged inside
  float mu = (pos.y - uEye.y) / max(dist, 1.0e-4);
  float tau = cfMistDepth(uMist * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), mu, dist);
  float weather = (1.0 - exp(-tau)) * smoothstep(8.0, 40.0, dist);
  fog = 1.0 - (1.0 - fog) * (1.0 - weather);
  fog = pow(clamp(fog, 0.0, 1.0), boostExp);
  float mist = 1.0 - exp(-dist * float(OPTION_MIST));
  return 1.0 - (1.0 - fog) * (1.0 - mist);
}

vec3 coldFogColor(vec3 viewDir) {
  vec3 fc = fogColor(uFogColor, viewDir);
  float fl = dot(fc, LUMA);
  vec3 tint = mix(vec3(0.90, 0.98, 1.08), vec3(0.97, 1.03, 0.86), clamp(float(OPTION_GREENFOG), 0.0, 1.0));
  return mix(fc, vec3(fl) * tint, float(OPTION_BLUEFOG));
}

float lightMask(vec3 c) {
  float b = dot(c, LUMA) * uExposure * float(OPTION_EXPOSURE);
  float cut = max(float(OPTION_LIGHTCUT), 0.01);
  return smoothstep(cut, cut * 4.0, b);
}

vec3 lightHalo(vec2 uv, vec2 res) { // halo effect on lights to power when in darkness
  vec3 acc = vec3(0.0);
  float aspect = res.x / res.y;
  for (int i = 0; i < 12; i++) {
    float a = 6.2831853 * float(i) / 12.0 + 0.7;
    float r = 0.035 * (0.35 + 0.65 * float((i * 5) % 12) / 12.0);
    vec3 smp = texture(uColor, uv + vec2(cos(a) / aspect, sin(a)) * r).rgb;
    acc += smp * lightMask(smp);
  }
  return acc / 12.0;
}

vec3 coldGrade(vec3 c, vec2 uv, float fogK) {
  float protect = clamp(fogK * float(OPTION_GREENFOG) * 1.2, 0.0, 1.0);
  float sat = mix(float(OPTION_BLUESATURATION), 0.95, protect);
  float cool = float(OPTION_BLUENESS) * (1.0 - protect * 0.85);

  float l = dot(c, LUMA);
  c = mix(vec3(l), c, sat);

  // take off warm residual and take it to the blue tone
  float warm = max(c.r - max(c.g, c.b), 0.0) * float(OPTION_WARMDOWN);
  c.r -= warm;
  c.g += warm * 0.12;
  c.b += warm * 0.80;

  l = dot(c, LUMA);
  vec3 tint = mix(vec3(0.70, 0.88, 1.05), vec3(0.92, 0.98, 1.02), smoothstep(0.0, 0.7, l));
  c *= mix(vec3(1.0), tint, cool);

   vec3 contrasted = (c - 0.45) * float(OPTION_BLUECONTRAST) + 0.45;
  c = mix(c, contrasted, smoothstep(0.0, 0.3, dot(c, LUMA)));

  float r = length((uv - 0.5) * vec2(1.15, 0.95));
  c *= 1.0 - smoothstep(0.35, 0.95, r) * float(OPTION_BLUEVIGNETTE);

  return clamp(c, 0.0, 1.0);
}

void main() {
  // pixel effect and wobble
  vec2 res = vec2(textureSize(uColor, 0));
  float px = max(1.0, floor(float(OPTION_PIXEL) + 0.5));
  vec2 uv = vUv;
  if (px > 1.0) uv = (floor(vUv * res / px) + 0.5) * px / res;
  float wob = clamp(float(OPTION_WOBBLE), 0.0, 1.0);
  if (wob > 0.0) {
    float d0 = texture(uDepth, uv).r;
    if (d0 < 1.0) {
      // world cells size 1/4 it changes depending on movement
      vec3 cell = floor(scenePos(uv, d0) * 4.0);
      vec2 j = cfHash22(cell.xz + cell.yy * vec2(17.0, 31.0)) - 0.5;
      uv += j * 4.0 * wob * px / res;                  // up to +-2 pixels
    }
    uv = clamp(uv, 0.5 / res, 1.0 - 0.5 / res);
  }

  vec3 color = texture(uColor, uv).rgb;

  // chromatic aberration
  float ca = clamp(float(OPTION_CHROMA), 0.0, 1.0);
  if (ca > 0.0) {
    vec2 off = (uv - 0.5) * ca * 0.012;
    color.r = texture(uColor, uv + off).r;
    color.b = texture(uColor, uv - off).b;
  }

  if (uDebugView != 0) { fragColor = vec4(color, 1.0); return; }
  if (any(isnan(color)) || any(isinf(color))) color = vec3(0.0);

  float depth = texture(uDepth, uv).r;

  vec4 volume = mix(vec4(0.0, 0.0, 0.0, 1.0), texture(uVolume, uv), uVolumeOn);
  if (any(isnan(volume)) || any(isinf(volume))) volume = vec4(0.0, 0.0, 0.0, 1.0);
  color = color * volume.a + volume.rgb;

  float fogBoostExp = 1.0 / (1.0 + float(OPTION_FOG_BOOST));
  float fogK = 0.0;
  if (depth < 1.0) {
    vec3 pos = scenePos(uv, depth);
    float dist = distance(pos, uEye);
    float k = fogDensity(pos, dist, linearDepth(depth), fogBoostExp);

    // aprox 1.7 for low fog
    float above = max(pos.y - (uEye.y - 1.7), 0.0);
    float low = 1.0 - exp(-dist * 0.06 * float(OPTION_LOW_FOG) * exp(-above * 0.45));
    k = 1.0 - (1.0 - k) * (1.0 - low);

    // wisps for lower fog
    float w = cfNoise(pos.xz * 0.07 + vec2(uTime * 0.03, uTime * 0.017));
    k = clamp(k * (1.0 + (w - 0.5) * 0.9 * float(OPTION_FOG_WISPS)), 0.0, 1.0);

    float lit = lightMask(color); // the lights go into the fog
    k *= 1.0 - clamp(float(OPTION_PENETRATION), 0.0, 1.0) * lit;
    fogK = k;
    color = mix(color, coldFogColor(normalize(pos - uEye)), k);
  } else if (float(OPTION_SKY_FOG) > 0.0) {
    vec3 dir = normalize(scenePos(uv, 0.5) - uEye);
    float ref = float(OPTION_SKY_FOG_DISTANCE);
    float tauSky = cfMistDepth(uMist * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), max(dir.y, 1.0e-3), 1.0e6);
    float weather = 1.0 - exp(-tauSky);
    weather = pow(clamp(weather, 0.0, 1.0), fogBoostExp);
    float km = 1.0 - exp(-ref * float(OPTION_MIST));
    float shape = 1.0 - smoothstep(0.0, mix(0.12, 1.3, km), max(dir.y, 0.0));
    float skyK = (1.0 - (1.0 - weather) * (1.0 - km * shape)) * clamp(float(OPTION_SKY_FOG), 0.0, 1.0);
    fogK = skyK;
    color = mix(color, coldFogColor(dir), skyK);
  }

#if PIPELINE_SUN_SHAFTS
  color += texture(uSunShafts, uv).rgb * uShaftStrength;
#endif
  if (uBloomStrength > 0.0) color += texture(uBloom, uv).rgb * uBloomStrength * float(OPTION_GLOW);

// soft glow around bright lights, stronger within dense fog
  if (float(OPTION_HALO) > 0.0 && fogK > 0.02) color += lightHalo(uv, res) * float(OPTION_HALO) * fogK * 0.6;

  if (uMeter != 0) { fragColor = meterValue(color, depth, vUv); return; }

  float toneLuma;
  color = tone(purkinje(max(color * uExposure * float(OPTION_EXPOSURE), vec3(0.0))), toneLuma);

  // cold grading for more saturated blues
  color = mix(color, coldGrade(color, vUv, fogK), clamp(float(OPTION_BLUE), 0.0, 1.0));

  float dv = clamp(float(OPTION_DARKVISION), 0.0, 1.0);
  if (dv > 0.0) color += dv * 0.07 * (1.0 - smoothstep(0.0, 0.25, dot(color, LUMA))) * vec3(0.80, 0.95, 1.10);

  float grain = clamp(float(OPTION_GRAIN), 0.0, 1.0);
  if (grain > 0.0) {
    float g = cfHash21(gl_FragCoord.xy + 5.588 * float(uFrame & 63)) - 0.5;
    color += g * grain * 0.09 * (1.0 - 0.6 * dot(color, LUMA));
  }

  float bits = floor(float(OPTION_COLORBITS) + 0.5);   // reduce color depth by using ordered dithering
  if (bits < 8.0) {
    float levels = exp2(bits) - 1.0;
    float b = cfBayer4(ivec2(floor(gl_FragCoord.xy / px)));
    color = floor(color * levels + mix(0.5, b, clamp(float(OPTION_DITHERING), 0.0, 1.0))) / levels;
  } else {
    color += (cfHash21(gl_FragCoord.xy + 17.0) - 0.5) / 255.0;
  }
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
