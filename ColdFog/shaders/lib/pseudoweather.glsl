// weather behaviour library for coldFog
#ifndef PSEUDOWEATHER
#define PSEUDOWEATHER


const float CF_BOOST = 0.4;
const float CF_VIS_NEAR = 30.0;
const float CF_VIS_FAR = 200.0;
const float CF_VIS_NIGHT = 80.0;
const float CF_HORIZON_FLAT = 0.04;
const float CF_HORIZON_TOP = 0.18;
const float CF_SKY_PAINT = 0.5;
const float CF_NIGHT_NEAR = 30.0; 
const float CF_NIGHT_FAR = 70.0;
const float CF_VEIL_LOW = 1.0;
const float CF_VEIL_HIGH = 1.0;
const float CF_WALL_START = 0.35;
const float CF_WALL_SOFT = 1.0;
const float CF_WALL_ROUGH = 0.6;
const float CF_WALL_PUFF = 0.3;
const float CF_FLOOR = 0.12;
const float CF_HUMID = 0.004;
const float CF_GREY = 0.5;
const float CF_GREEN = 0.18;
const float CF_INDOOR = 0.8;
const float COLDFOG_MIST_SIGMA = 0.075;
const float COLDFOG_MIST_HEIGHT = 12.0;

float cfWeather() {
  float natural = smoothstep(0.05, 0.5, uMist);
  float storm = smoothstep(0.005, 0.06, max(uRainStrength, uSnowStrength));
  return max(max(natural, storm), clamp(float(OPTION_ALWAYS), 0.0, 1.0));
}

// the fog amount along a sight line
float cfFog(vec3 pos, float dist, float linDepth) {
  float fog = max(fogAt(linDepth, uFogRange), hazeAt(dist, uHaze));
  // it only starts a few squares away
  float mu = (pos.y - uEye.y) / max(dist, 1.0e-4);
  float tau = cfMistDepth(uMist * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), mu, dist);
  float mist = (1.0 - exp(-tau)) * smoothstep(8.0, 40.0, dist);
  fog = 1.0 - (1.0 - fog) * (1.0 - mist);
  fog = pow(clamp(fog, 0.0, 1.0), CF_BOOST);
  float floorK = 1.0 - exp(-dist * CF_FLOOR * cfWeather());
  fog = max(fog, floorK);
  float humid = 1.0 - exp(-dist * CF_HUMID * (1.0 - 0.5 * cfNight()));
  return 1.0 - (1.0 - fog) * (1.0 - humid);
}

// the fog amount seen in the sky
float cfSkyFog(vec3 dir, float ref) {
  float tau = cfMistDepth(uMist * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), max(dir.y, 1.0e-3), 1.0e6);
  float natural = pow(clamp(1.0 - exp(-tau), 0.0, 1.0), CF_BOOST);
  float floorK = 1.0 - exp(-ref * CF_FLOOR * cfWeather());
  float shape = 1.0 - smoothstep(0.0, mix(0.12, 1.3, floorK), max(dir.y, 0.0));
  return 1.0 - (1.0 - natural) * (1.0 - floorK * shape);
}

// far scenery that has no depth
float cfHorizon(vec3 dir) {
  return (1.0 - smoothstep(CF_HORIZON_FLAT, CF_HORIZON_TOP, max(dir.y, 0.0))) * clamp(float(OPTION_MODERN), 0.0, 1.0);
}

// sight limit by day
float cfVisDay(float weather) {
  float modern = clamp(float(OPTION_MODERN), 0.0, 1.0);
  if (modern <= 0.0) return 1.0e4;
  return mix(CF_VIS_FAR, CF_VIS_NEAR, pow(weather * modern, 0.6));
}

// sight limit on the ground
float cfVis(float weather) {
  float vis = cfVisDay(weather);
  float nightK = cfNight();
  return min(vis, mix(1.0e4, CF_VIS_NIGHT, nightK));
}

float cfWall(vec3 vd, float vis, float weather) {
  if (CF_WALL_ROUGH <= 0.0) return 1.0;
  vec2 h = normalize(vd.xz + vec2(1.0e-4, 0.0));
  float s = max(vis * CF_WALL_PUFF, 6.0);
  vec2 p = (uEye.xz + h * vis) / s;   // read where the wall stands so it stays in the world when you walk
  float big = cfLumps(p, uTime);
  float fine = cfLumps(p * 3.1 + 7.3, uTime * 1.7);
  float n = 0.7 * big + 0.3 * fine;
  return 1.0 + (n - 0.5) * CF_WALL_ROUGH * mix(0.4, 1.0, weather);
}

vec3 cfFogColor(vec3 viewDir) {
  vec3 fc = skyColor(viewDir, uFogColor, uZenith, uSkySun, vec3(0.0), 0.0) * SKY_BRIGHTNESS;
  float fl = dot(fc, LUMA);
  vec3 tint = mix(vec3(0.90, 0.98, 1.08), vec3(0.97, 1.03, 0.86), CF_GREEN);
  return mix(fc, vec3(fl) * tint, CF_GREY * mix(0.3, 1.0, cfWeather()));
}

#endif
