// weather behaviour library for coldFog
#ifndef PSEUDOWEATHER
#define PSEUDOWEATHER


const float CF_BOOST = 0.4;
const float CF_VIS_NEAR = 30.0;
const float CF_VIS_FAR = 380.0;
const float CF_VIS_NIGHT = 80.0;
const float CF_HORIZON_CLEAR = 0.3;
const float CF_HORIZON_TOP = 0.18;
const float CF_HORIZON_FLAT = 0.04;
const float CF_SKY_PAINT = 0.5;
const float CF_SKY_TOP = 0.95;
const float CF_NIGHT_NEAR = 30.0; 
const float CF_NIGHT_FAR = 70.0;
const float CF_WALL_START = 0.35;
const float CF_WALL_SOFT = 1.0;
const float CF_WALL_ROUGH = 0.6;
const float CF_WALL_PUFF = 0.3;
const float CF_FLOOR = 0.12;
const float CF_HUMID = 0.0025;
const float CF_GREY = 0.5;
const float CF_GREEN = 0.18;
const float CF_INDOOR = 0.8;
const float CF_RAIN_GAIN = 0.62;
const float CF_RAIN_SAT = 0.55;
const float CF_RAIN_MIST = 0.35;
const float CF_SNOW_FOG = 0.2;
const float CF_RAIN_FOG = 0.2;
const float CF_RAIN_VIS = 0.2;
const float CF_RAIN_LEVEL = 0.6;
const float CF_RAIN_FAR = 0.52;
const float CF_RAIN_WHITE = 0.85;
const float CF_RAIN_KEEP = 0.6;
const float CF_CUT_MORNING = 0.25;
const float CF_CUT_AFTERNOON = 0.40;
const float CF_MUTE_GAIN = 2.0;
const float CF_MUTE_DIM = 0.85;
const float CF_OVERCAST_DIM = 0.4;
const float CF_OVERCAST_GREY = 0.95;
const float CF_OVERCAST_FAR = 0.5; 
const float COLDFOG_MIST_SIGMA = 0.075;
const float COLDFOG_MIST_HEIGHT = 12.0;

float cfMist() {
  float rain = smoothstep(0.005, 0.06, uRainStrength) * clamp(float(OPTION_DIMRAIN), 0.0, 1.0);
  return max(uMist - CF_RAIN_MIST * rain, 0.0);
}

// how much of the rain is dim and clear instead of foggy, real mist in the game keeps its fog
float cfRainAmt() {
  float natural = smoothstep(0.05, 0.5, cfMist());
  return clamp(float(OPTION_DIMRAIN), 0.0, 1.0) * smoothstep(0.005, 0.06, uRainStrength) * (1.0 - natural);
}

float cfWeather() {
  float natural = smoothstep(0.05, 0.5, cfMist());
  float rain = smoothstep(0.005, 0.06, uRainStrength) * (1.0 - cfRainAmt());
  float storm = max(rain, smoothstep(0.005, 0.06, uSnowStrength) * mix(1.0, CF_SNOW_FOG, clamp(float(OPTION_DIMRAIN), 0.0, 1.0)));
  float rainFog = CF_RAIN_FOG * cfRainAmt();
  return max(max(max(natural, storm), rainFog), clamp(float(OPTION_ALWAYS), 0.0, 1.0));
}

float cfFogWeather() {
  return clamp(cfWeather() + CF_RAIN_FOG * cfRainAmt(), 0.0, 1.0);
}

float cfOvercast() {
  return smoothstep(0.15, 0.7, uOvercast) * (1.0 - cfWeather());
}

float cfOvercastFog() { // fog does not get the rain dim
  return cfOvercast() * (1.0 - cfRainAmt());
}

vec3 cfMute(vec3 c, float m) {
  float l = dot(c, LUMA);
  return mix(c, vec3(l), 0.7 * m) * mix(1.0, CF_MUTE_DIM, m);
}

// the far veil follows the dark light of a covered sky
vec3 cfFarDim(vec3 c) {
  float k = cfOvercast();
  float l = dot(c, LUMA);
  c = mix(c, vec3(l) * vec3(0.92, 0.98, 1.04), CF_OVERCAST_GREY * k);
  return c * mix(1.0, CF_OVERCAST_FAR, k);
}

// the fog amount along a sight line
float cfFog(vec3 pos, float dist, float linDepth) {
  float fog = max(fogAt(linDepth, uFogRange), hazeAt(dist, uHaze)) * (1.0 - cfRainAmt());
  // it only starts a few squares away
  float mu = (pos.y - uEye.y) / max(dist, 1.0e-4);
  float tau = cfMistDepth(cfMist() * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), mu, dist);
  float mist = (1.0 - exp(-tau)) * smoothstep(8.0, 40.0, dist);
  fog = 1.0 - (1.0 - fog) * (1.0 - mist);
  fog = pow(clamp(fog, 0.0, 1.0), CF_BOOST);
  float floorK = 1.0 - exp(-dist * CF_FLOOR * cfFogWeather());
  fog = max(fog, floorK);
  float humid = 1.0 - exp(-dist * CF_HUMID * (1.0 - 0.5 * cfNight()));
  return 1.0 - (1.0 - fog) * (1.0 - humid);
}

// the fog amount seen in the sky
float cfSkyFog(vec3 dir, float ref) {
  float tau = cfMistDepth(cfMist() * COLDFOG_MIST_SIGMA, COLDFOG_MIST_HEIGHT, max(uEye.y, -3.0 * COLDFOG_MIST_HEIGHT), max(dir.y, 1.0e-3), 1.0e6);
  float natural = pow(clamp(1.0 - exp(-tau), 0.0, 1.0), CF_BOOST);
  float floorK = 1.0 - exp(-ref * CF_FLOOR * cfFogWeather());
  float shape = 1.0 - smoothstep(0.0, mix(0.12, 1.3, floorK), max(dir.y, 0.0));
  return 1.0 - (1.0 - natural) * (1.0 - floorK * shape);
}

// far scenery that has no depth
float cfHorizon(vec3 dir) {
  return (1.0 - smoothstep(CF_HORIZON_FLAT, CF_HORIZON_TOP, max(dir.y, 0.0))) * clamp(float(OPTION_MODERN), 0.0, 1.0) * mix(CF_HORIZON_CLEAR, 1.0, cfFogWeather());
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
  float grey = CF_GREY * mix(0.3, 1.0, cfWeather());
  grey = mix(grey, CF_OVERCAST_GREY, cfOvercast());
  vec3 col = mix(fc, vec3(fl) * tint, grey);
  return mix(col, vec3(dot(col, LUMA)), cfRainAmt() * CF_RAIN_WHITE);
}

#endif
