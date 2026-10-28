// day shades library
#ifndef PSEUDODAY
#define PSEUDODAY

uniform float uDayFraction;

struct CfDay {
  float morning;
  float cold;
  float sunset;
  float dawn;
  float dusk;
};

// uSkySun turns into the moon once the sun is under -6 degrees so the real sun is read from uSunTrue
CfDay cfDayPhase() {
  float s = uSunTrue.y;
  float dayK = (1.0 - smoothstep(0.1, 0.5, uNight)) * smoothstep(-0.10, 0.02, s);
  float pm = smoothstep(0.40, 0.60, uDayFraction);
  float am = 1.0 - pm;
  float twilight = smoothstep(-0.30, -0.12, s) * (1.0 - smoothstep(-0.10, 0.02, s));
  CfDay d;
  d.morning = am * (1.0 - smoothstep(0.4, 0.85, s)) * dayK;
  d.sunset = pm * (1.0 - smoothstep(0.35, 0.8, s)) * dayK;
  d.cold = dayK * (1.0 - d.morning) * (1.0 - d.sunset);
  d.dawn = am * twilight;
  d.dusk = pm * twilight;
  return d;
}

// colour pushed on the whole image
vec3 cfDayTint(CfDay d, float weather) {
  float k = clamp(float(OPTION_DAYLOOK), 0.0, 1.0) * (1.0 - 0.6 * weather);
  vec3 yellow = vec3(1.28, 1.08, 0.55);
  vec3 sepia = vec3(1.16, 0.93, 0.64);
  vec3 orange = vec3(1.40, 0.78, 0.36);
  vec3 ice = vec3(0.84, 0.96, 1.12);
  vec3 violet = vec3(0.90, 0.76, 1.22);   // dawn has no red in it
  vec3 plum = vec3(1.22, 0.62, 1.06);   // dusk keeps some red
  vec3 t = mix(vec3(1.0), mix(yellow, sepia, 0.5), d.morning * k);
  t = mix(t, orange, d.sunset * k);
  t = mix(t, violet, d.dawn * k);
  t = mix(t, plum, d.dusk * k);
  return mix(t, t * ice, d.cold * k * 0.8);
}

// rich colour at dawn and dusk, drained colour in the cold afternoon
vec3 cfDayGrade(vec3 c, CfDay d, float weather) {
  float k = clamp(float(OPTION_DAYLOOK), 0.0, 1.0) * (1.0 - 0.6 * weather);
  float sat = 1.0 + 0.25 * (d.morning + d.sunset) * k + 0.15 * (d.dawn + d.dusk) * k - 0.2 * d.cold * k;
  float l = dot(c, LUMA);
  return mix(vec3(l), c, sat);
}

// the sun disc and a soft glow around it, dir is the view direction, it is only added where there is sky
vec3 cfSun(vec3 dir, CfDay d, float weather) {
  float c = dot(dir, normalize(uSkySun));
  float disc = smoothstep(0.99985, 0.99995, c);
  float glow = pow(max(c, 0.0), 220.0) * 0.04;
  float up = smoothstep(-0.05, 0.05, uSkySun.y) * (1.0 - smoothstep(0.1, 0.5, uNight));
  vec3 col = mix(vec3(1.0, 0.92, 0.72), vec3(1.0, 0.50, 0.18), d.sunset);
  return col * (disc + glow) * 40.0 * up * (1.0 - 0.9 * weather) * float(OPTION_SUN);
}

// stronger after sunrise
float cfRays(CfDay d) {
  return 1.0 + 1.5 * d.morning * clamp(float(OPTION_DAYLOOK), 0.0, 1.0);
}

#endif
