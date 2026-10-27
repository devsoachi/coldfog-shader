// light library
#ifndef PSEUDOLIGHT
#define PSEUDOLIGHT

const vec3 SODIUM_HUE = vec3(1.0, 0.62, 0.20) / 0.6704;   // sodium lamp

float cfMask(vec3 c) {
  float b = dot(c, LUMA) * uExposure * float(OPTION_EXPOSURE);
  float cut = max(float(OPTION_LIGHTCUT), 0.01);
  return smoothstep(cut, cut * 4.0, b);
}

float cfEmit(vec3 c) {
  float b = dot(c, LUMA) * uExposure * float(OPTION_EXPOSURE);
  float cut = max(float(OPTION_LIGHTCUT), 0.01);
  return smoothstep(cut * 2.5, cut * 7.0, b);
}

// light on lamp
float cfLamp(vec3 c) {
  float warmth = (c.r - c.b) / max(c.r, 1.0e-4);
  float gOverR = c.g / max(c.r, 1.0e-4);
  return smoothstep(0.55, 0.8, warmth) * smoothstep(0.25, 0.45, gOverR) * (1.0 - smoothstep(1.3, 1.8, gOverR))
       * smoothstep(0.03, 0.2, dot(c, LUMA) * uExposure * float(OPTION_EXPOSURE)) * cfNight();
}

// soft glare around bright lamps
vec3 cfGlare(vec3 hb) {
  vec3 gb = hb * 0.2;
  float nightK = cfNight();
  float gLuma = dot(gb, LUMA) * uExposure * float(OPTION_EXPOSURE);
  float gWarm = smoothstep(0.55, 0.8, (gb.r - gb.b) / max(gb.r, 1.0e-6)) * nightK;
  float gMask = max(cfMask(gb * 3.0), gWarm * cfMask(gb * 12.0)) * nightK;
  vec3 gHue = gb / max(dot(gb, LUMA), 1.0e-6);
  float ring = 1.0 + 0.18 * cos(log2(max(gLuma, 1.0e-4)) * 5.6);
  float gAmount = pow(gLuma, 0.65) * ring * gMask * float(OPTION_GLARE) * 0.12;
  return gHue * gAmount / max(uExposure * float(OPTION_EXPOSURE), 1.0e-3);
}

vec3 cfSodium(vec3 c, float lampK) {
  float sl = dot(c, LUMA);
  float strength = clamp(float(OPTION_SODIUM) * lampK, 0.0, 1.0);
  vec3 amber = SODIUM_HUE * sl * (1.0 + 0.6 * float(OPTION_SODIUM) * lampK);
  amber = mix(amber, vec3(1.0), smoothstep(0.85, 1.0, sl));
  return mix(c, amber, strength);
}

#endif
