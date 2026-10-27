// tone library with curve
#ifndef PSEUDOGRADE
#define PSEUDOGRADE

// the tone curve cuts everything above 2.0 to flat white so this eases it in first
vec3 cfExpose(vec3 c) {
  vec3 e = max(c * uExposure * float(OPTION_EXPOSURE), vec3(0.0));
  float el = dot(e, LUMA);
  const float KNEE = 0.6, TOP = 1.4;
  float lim = el > KNEE ? KNEE + (TOP - KNEE) * (1.0 - exp(-(el - KNEE) / (TOP - KNEE))) : el;
  lim = mix(lim, 2.0, smoothstep(40.0, 200.0, el));
  return e * (lim / max(el, 1.0e-6));
}

vec3 cfGrade(vec3 c, vec2 uv, float fogK) {
  float protect = clamp(fogK * CF_GREEN * 1.2, 0.0, 1.0);
  float sat = mix(float(OPTION_BLUESATURATION), 0.95, protect);
  float cool = float(OPTION_BLUENESS) * (1.0 - protect * 0.85) * cfNight();

  float l = dot(c, LUMA);
  c = mix(vec3(l), c, sat);

  // take off warm residual and take it to the blue tone, but strong light does not get affected
  float keep = smoothstep(0.3, 0.6, (c.r - c.b) / max(c.r, 1.0e-4));
  float warm = max(c.r - max(c.g, c.b), 0.0) * float(OPTION_WARMDOWN) * cfNight() * (1.0 - keep);
  c.r -= warm;
  c.g += warm * 0.12;
  c.b += warm * 0.80;

  l = dot(c, LUMA);
  vec3 tint = mix(vec3(0.70, 0.88, 1.05), vec3(0.92, 0.98, 1.02), smoothstep(0.0, 0.7, l));
  c *= mix(vec3(1.0), tint, cool * (1.0 - keep));

  vec3 contrasted = (c - 0.45) * float(OPTION_BLUECONTRAST) + 0.45;
  c = mix(c, contrasted, smoothstep(0.0, 0.3, dot(c, LUMA)));

  float r = length((uv - 0.5) * vec2(1.15, 0.95));
  c *= 1.0 - smoothstep(0.35, 0.95, r) * float(OPTION_BLUEVIGNETTE);

  return clamp(c, 0.0, 1.0);
}

// everything sinks into brown like rust or rot, warm 0 is plain and 1 is rust
vec3 cfStain(vec3 c, float amount, float warm) {
  float l = dot(c, LUMA);
  vec3 tint = mix(vec3(1.12, 1.00, 0.60), vec3(1.32, 0.88, 0.56), warm);
  vec3 stained = vec3(l) * tint;
  stained *= mix(vec3(0.80, 0.66, 0.50), vec3(1.0), smoothstep(0.0, 0.45, l));   // the shadows sink into umber
  return mix(c, stained, amount);
}

#endif
