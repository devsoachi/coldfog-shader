#version 330

// coldFog shaderpack made for viewpoint by soachi, heavy cold fog that follows the weather, with film grain, chromatic aberration and optional reduced colorbits

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
uniform float uRainStrength;
uniform float uSnowStrength;
uniform float uEyeSky;
uniform float uNight;
#if PIPELINE_SUN_SHAFTS
uniform sampler2D uSunShafts;
uniform float uShaftStrength;
#endif
out vec4 fragColor;
#ifndef OPTION_EXPOSURE // it needs to be up here because it is a fallback
#define OPTION_EXPOSURE 0.6
#endif
#include "lib/pseudofog_light.glsl"
#include "lib/camera.glsl"
#include "lib/common.glsl"
#include "lib/fog.glsl"
#include "lib/fog_amount.glsl"
#include "lib/eye_meter.glsl"
#include "lib/purkinje.glsl"
#include "lib/tone.glsl"
#include "lib/pseudoopt.glsl"
#include "lib/pseudonoise.glsl"
#include "lib/pseudoweather.glsl"
#include "lib/pseudoday.glsl"
#include "lib/pseudodome.glsl"
#include "lib/pseudolayer.glsl"
#include "lib/pseudolight.glsl"
#include "lib/pseudograde.glsl"
#include "lib/pseudotest.glsl"

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
      // world cells of a quarter square
      vec3 cell = floor(scenePos(uv, d0) * 4.0);
      vec2 j = cfHash22(cell.xz + cell.yy * vec2(17.0, 31.0)) - 0.5;
      uv += j * 4.0 * wob * px / res;                  // up to 2 pixels each way
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

  vec4 volume = mix(vec4(0.0, 0.0, 0.0, 1.0), texture(uVolume, uv), uVolumeOn);
  if (any(isnan(volume)) || any(isinf(volume))) volume = vec4(0.0, 0.0, 0.0, 1.0);

  float depth = texture(uDepth, uv).r;
  color = color * volume.a + volume.rgb;

  // weather, time of day and the amount of each fog
  float wx = cfWeather();
  CfDay day = cfDayPhase();
  vec3 dayTint = cfDayTint(day, wx);
  float modern = clamp(float(OPTION_MODERN), 0.0, 1.0);
  float classic = clamp(float(OPTION_CLASSIC), 0.0, 1.0);
  float classicAmt = classic * wx;
  float layerAmt = 0.4 * classicAmt + modern * mix(0.05, 0.22, wx);   // clouds on the ground
  float domeAmt = modern * mix(DOME_CLEAR, 1.0, wx);
  float vis = cfVis(wx);
  float visDay = cfVisDay(wx);
  color *= dayTint;

  float fogK = 0.0;
  float veil = 0.0;

  vec3 fogHdr = vec3(0.0);
  float dispK = 0.0;                      // how much of the final is the dome colours
  vec3 dispColor = DOME_FAR;
  float sodiumK = 0.0;                    // how much a lamp is the light of this pixel
  float wallness = 0.0;
  if (domeAmt > 0.0) {
    vec3 sp = scenePos(uv, depth);
    vec3 dpx = dFdx(sp);
    vec3 dpy = dFdy(sp);
    vec3 sn = derivativeNormal(dpx, dpy, vec3(0.0, 1.0, 0.0));
    float trust = 1.0 - smoothstep(0.1, 0.4, (length(dpx) + length(dpy)) / max(distance(sp, uEye), 1.0e-3));   // at the edge of an object the normal is nothing
    wallness = depth < 1.0 ? (1.0 - abs(sn.y)) * trust : 0.0;
  }
  float stainGate = mix(1.0, cfNight(), clamp(float(OPTION_STAINNIGHT), 0.0, 1.0));;  // 1 always on and 0 off

  if (depth < 1.0) {
    vec3 pos = scenePos(uv, depth);
    vec3 off = pos - uEye;
    float dist = length(off);
    vec3 vd = off / max(dist, 1.0e-4);
    float clump = 0.5 * clamp(classicAmt + modern * wx, 0.0, 1.0);
    float k = 1.0;
    if (dist >= vis / (1.0 - 0.5 * clump)) {
      veil = 1.0;   // skip all the fog math past the limit
      dispK = 1.0;
    } else {
      // the lumps push the fog
      float m = 1.0;
      if (clump > 0.0) m = 1.0 + (cfLumps(vec2(pos.x + pos.y * 0.7, pos.z + pos.y * 0.45) / LAYER_LUMP, uTime) - 0.5) * clump;
      float distN = dist * m;
      k = cfFog(pos, distN, linearDepth(depth) * m);

      // only for the classic fog
      float above = max(pos.y - (uEye.y - 1.7), 0.0);
      float low = 1.0 - exp(-dist * 0.05 * classicAmt * exp(-above * 0.45));
      k = 1.0 - (1.0 - k) * (1.0 - low);

      // wisps for lower fog
      float wisp = cfNoise(pos.xz * 0.07 + vec2(uTime * 0.03, uTime * 0.017));
      k = clamp(k * (1.0 + (wisp - 0.5) * 0.09), 0.0, 1.0);

      if (layerAmt > 0.0) k = 1.0 - (1.0 - k) * (1.0 - cfLayer(vd, dist, layerAmt, clump));

            float lit = mix(cfMask(color), cfEmit(color), cfNight());   // the lights go into the fog
      color *= 1.0 - smoothstep(CF_NIGHT_NEAR, CF_NIGHT_FAR, dist) * cfNight() * (1.0 - lit);
      float lampLit = cfLamp(color);   // what a lamp lights is amber
      sodiumK = lampLit;
      k *= 1.0 - clamp(float(OPTION_PENETRATION), 0.0, 1.0) * lit;
      k *= 1.0 - 0.85 * lampLit;
      k *= mix(CF_INDOOR, 1.0, smoothstep(0.5, 0.8, uEyeSky));

      float domeShow = 0.0;
      vec3 domeTint = DOME_FAR;
      if (domeAmt > 0.0) {
        float domeTau;
        float domeWalls;
        cfDomes(vd, dist, wallness, domeAmt, wx, domeTau, domeTint, domeWalls);
        float outside = smoothstep(0.5, 0.8, uEyeSky); // no domes inside a building
        float domeK = (1.0 - exp(-domeTau)) * outside;
        // a light is not hidden like the rest
        domeShow = mix(domeK, (1.0 - pow(DOME_WALL, domeWalls)) * outside, lit * clamp(float(OPTION_PENETRATION), 0.0, 1.0));
        domeShow *= 1.0 - 0.85 * lampLit;
        float farK = smoothstep(1.2 * DOME_CELL, 2.5 * DOME_CELL, dist) * outside * modern * wx;   // the far fog only comes with the weather
        domeTint = mix(domeTint, DOME_FAR, farK);
        domeShow = 1.0 - (1.0 - domeShow) * (1.0 - farK);
      }

      float spots = clamp(float(OPTION_STAINSPOTS), 0.0, 1.0) * stainGate * (1.0 - lit);
      if (spots > 0.0) {   // stains spots
        float g = cfLumps(vec2(pos.x + pos.y * 0.7, pos.z + pos.y * 0.45) / 3.0 + 91.0, 0.0);
        color = mix(color, color * vec3(0.42, 0.30, 0.20), smoothstep(0.35, 0.9, g) * spots);
      }

      veil = smoothstep(vis * 0.35, vis, distN);
      k = max(k, veil);
      dispK = 1.0 - (1.0 - domeShow) * (1.0 - veil);
      dispColor = mix(DOME_FAR, domeTint, domeShow / max(domeShow + veil, 1.0e-4));
    }
    fogK = k;
    float fogPaint = wx * smoothstep(0.5, 0.97, k);   // the fog gives way to the sky colour so far things melt into it
    dispColor = mix(dispColor, DOME_FAR, fogPaint);
    dispK = max(dispK, fogPaint);
    fogHdr = cfFogColor(normalize(vec3(vd.x, vd.y * (1.0 - k), vd.z) + vec3(0.0, 0.0, 1.0e-4))) * dayTint;
    color = mix(color, fogHdr, k);
  } else {
    vec3 dir = normalize(scenePos(uv, 0.999) - scenePos(uv, 0.5)); 
    const float REF = 120.0;   // the distance the sky fog is judged at
    float skyBase = cfSkyFog(dir, REF);
    veil = smoothstep(visDay * 0.55, visDay, REF);
    skyBase = max(skyBase, veil);
    float skyK = max(skyBase, cfHorizon(dir));   // the horizon band covers far scenery
    fogK = skyK;
    fogHdr = cfFogColor(normalize(vec3(dir.x, dir.y * (1.0 - skyK), dir.z) + vec3(0.0, 0.0, 1.0e-4))) * dayTint;
    color = mix(color, fogHdr, skyK);
    color += cfSun(dir, day, wx);
    dispK = skyK;
  }

  if (uMeter != 0) { fragColor = meterValue(color, depth, vUv); return; }

  // fog level, how bright the fog is whatever the sky does
  float fl = max(dot(fogHdr, LUMA) * uExposure * float(OPTION_EXPOSURE), 1.0e-3);
  float want = 0.4 * mix(1.0, 0.1, cfNightAll());
  color += fogHdr * (clamp(want / fl, 0.25, 8.0) - 1.0) * fogK;

  float seen = 1.0 - veil;

  // everything that adds light on top of the image is collected here
  vec3 glow = volume.rgb * fogK * float(OPTION_FOGLIGHT);
#if PIPELINE_SUN_SHAFTS
  glow += texture(uSunShafts, uv).rgb * dayTint * uShaftStrength * cfRays(day) * seen;
#endif
  if (uBloomStrength > 0.0) {
    vec3 hb = texture(uBloom, uv).rgb;
    glow += hb * uBloomStrength * float(OPTION_GLOW) * seen;
    if (float(OPTION_HALO) > 0.0) glow += hb * cfMask(hb * 0.2) * float(OPTION_HALO) * fogK * 0.25 * seen;   // 0.2 because the bloom is the sum of 5 levels
    if (float(OPTION_GLARE) > 0.0) glow += cfGlare(hb) * seen;
  }

  // bloom, halo, shafts and the fog light all feed on the same brightness, so pile it up
  const float GLOW_MAX = 0.5;
  float glowLuma = min(dot(glow, LUMA) * uExposure * float(OPTION_EXPOSURE), 1.0e4) / GLOW_MAX;
  color += glow * inversesqrt(1.0 + glowLuma * glowLuma);
  float glowFrac = glowLuma * inversesqrt(1.0 + glowLuma * glowLuma);

  float toneLuma;
  color = tone(purkinje(cfExpose(color)), toneLuma);

  color *= 1.0 + (depth < 1.0 ? 0.5 : 0.5 * wx) * fogK * (1.0 - smoothstep(0.6, 0.9, dot(color, LUMA)));    // brighter fog

  // cold grading for more saturated blues
  color = mix(color, cfGrade(color, vUv, fogK), clamp(float(OPTION_BLUE), 0.0, 1.0));
  color = cfDayGrade(color, day, wx);

  float stainK = clamp(float(OPTION_STAIN), 0.0, 1.0) * stainGate;
  if (stainK > 0.0) color = cfStain(color, stainK, clamp(float(OPTION_STAINWARM), 0.0, 1.0));

  if (float(OPTION_SODIUM) > 0.0 && sodiumK > 0.0) color = cfSodium(color, sodiumK);

  if (domeAmt > 0.0) {
    float nightK = cfNightAll();
    float nightDome = mix(1.0, 0.0, nightK);   // black at night
    float veilGain = depth < 1.0 ? mix(1.0, mix(CF_VEIL_LOW, CF_VEIL_HIGH, smoothstep(0.06, 0.31, uRainStrength)), wx) : 1.0;
    color = mix(color, min(dispColor * dayTint * veilGain, vec3(1.0)) * nightDome, dispK * (1.0 - 0.8 * glowFrac * nightK));
  }

  float dv = clamp(float(OPTION_DARKVISION), 0.0, 1.0);
  if (dv > 0.0) color += dv * 0.07 * (1.0 - smoothstep(0.0, 0.25, dot(color, LUMA))) * mix(vec3(1.0), vec3(0.80, 0.95, 1.10), cfNight()) * (1.0 - dispK);

  float scan = clamp(float(OPTION_SCANLINE), 0.0, 1.0);   // crt like effect
  if (scan > 0.0) {
    float row = floor(gl_FragCoord.y) / max(float(OPTION_SCANLINESIZE), 1.0);
    float beam = 0.5 + 0.5 * cos(6.2831853 * row);          // 1 on the line and 0 in the gap
    float gap = scan * (1.0 - beam) * (1.0 - 0.5 * clamp(dot(color, LUMA) * 2.0, 0.0, 1.0));
    color *= (1.0 - gap) * (1.0 + 0.3 * scan * (1.0 - smoothstep(0.5, 0.9, dot(color, LUMA))));
  }

  float grain = clamp(float(OPTION_GRAIN), 0.0, 1.0);
  if (grain > 0.0) {
    float g = cfHash21(gl_FragCoord.xy + 5.588 * float(uFrame & 63)) - 0.5;
    color += g * grain * 0.09 * (1.0 - 0.6 * dot(color, LUMA));
  }

  float bits = floor(float(OPTION_COLORBITS) + 0.5);   // reduce colour depth with ordered dithering
  if (bits < 8.0) {
    float levels = exp2(bits) - 1.0;
    float b = cfBayer4(ivec2(floor(gl_FragCoord.xy / px)));
    color = floor(color * levels + mix(0.5, b, clamp(float(OPTION_DITHERING), 0.0, 1.0))) / levels;
  } else {
    color += (cfHash21(gl_FragCoord.xy + 17.0) - 0.5) / 255.0;
  }

  if (float(OPTION_FOGTEST) > 0.5) {
    vec4 t = cfTest(vUv, wx, day);
    if (t.a > 0.5) { fragColor = vec4(t.rgb, 1.0); return; }
  }
  fragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}
