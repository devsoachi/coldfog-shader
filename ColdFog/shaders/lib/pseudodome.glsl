// pseudodome library for coldFog, made by soachi | fog domes, one per cell of a grid, needs pseudonoise first
#ifndef PSEUDODOME
#define PSEUDODOME

const vec3 DOME_COLOR[4] = vec3[4](vec3(0.596, 0.624, 0.588), vec3(0.741, 0.804, 0.784), vec3(0.753, 0.816, 0.788), vec3(0.792, 0.851, 0.824));
const vec3 DOME_FAR = vec3(0.792, 0.851, 0.824);
const float DOME_CELL = 18.0;
const int DOME_STEPS = 4;
const float DOME_CURRENT = 0.85;
const float DOME_CLEAR = 0.15;   // domes left in clear weather, a faint spray
const float DOME_DENSITY = 6.0;
const float DOME_BOUND = 1.3;
const float DOME_TURB = 0.8;
const float DOME_HUG = 0.6;
const float DOME_WALL = 0.6;

// the air is pushed round in circles, weaker in clear weather
vec3 cfCurrent(vec3 p, float weather) {
  float amount = DOME_CURRENT * mix(0.4, 1.0, weather);
  vec2 rel = p.xz - uEye.xz;
  float r2 = dot(rel, rel);
  float f = exp(-r2 / 36.0);                                         // it reaches about 6 squares from you
  float a = amount * f * 1.2 * sin(uTime * 0.6 + sqrt(r2) * 0.35);   // it turns back and forth, more in the middle
  float cs = cos(a);
  float sn = sin(a);
  float up = amount * f * 2.0 * (0.5 + 0.5 * sin(uTime * 0.4));
  return vec3(uEye.x + cs * rel.x - sn * rel.y, p.y - up, uEye.z + sn * rel.x + cs * rel.y);
}

// tau is how much fog the ray meets, tint is its colour and walls is how many dome walls it crosses
void cfDomes(vec3 vd, float dist, float wallness, float amount, float weather, out float tau, out vec3 tint, out float walls) {
  tau = 0.0;
  tint = vec3(0.0);
  walls = 0.0;
  float sigma = DOME_DENSITY / DOME_CELL * amount;
  float groundY = uEye.y - 1.7;
  float hugRange = max(1.0, 0.2 * DOME_CELL);
  float jit = cfHash21(gl_FragCoord.xy + 5.588 * float(uFrame & 63));   // the grain hides the stepping
  vec2 cell = floor(uEye.xz / DOME_CELL);
  for (int j = -1; j <= 1; j++) {
    for (int i = -1; i <= 1; i++) {
      vec2 id = cell + vec2(float(i), float(j));
      float hx = cfHash21(id);
      float hz = cfHash21(id + 17.3);
      float hr = cfHash21(id + 41.7);
      float hc = cfHash21(id + 83.1);
      vec3 centre = vec3((id.x + 0.25 + 0.5 * hx) * DOME_CELL, groundY, (id.y + 0.25 + 0.5 * hz) * DOME_CELL);
      float radius = DOME_CELL * (0.32 + 0.18 * hr) * 1.35;
      vec3 radii = vec3(radius, max(radius * 0.5, 4.0), radius);   // flattened, but never lower than you
      vec3 o = (uEye - centre) / (radii * DOME_BOUND);
      vec3 d = vd / (radii * DOME_BOUND);
      float a = dot(d, d);
      float b = dot(o, d);
      float disc = b * b - a * (dot(o, o) - 1.0);
      if (disc > 0.0) {
        float root = sqrt(disc);
        float t1 = (-b - root) / a;
        float t2 = (-b + root) / a;
        float t0 = max(t1, 0.0);
        float t3 = min(t2, dist);
        if (t3 > t0) {
          float seg = t3 - t0;
          float dens = 0.0;
          for (int s = 0; s < DOME_STEPS; s++) {
            float t = t0 + seg * (float(s) + jit) / float(DOME_STEPS);
            vec3 pw = cfCurrent(uEye + vd * t, weather);
            vec3 u = (pw - centre) / radii;
            // the texture is on the dome and slides faster the faster you move
            vec2 q = (vec2(pw.x + pw.y * 0.7, pw.z + pw.y * 0.45) + uEye.xz * 0.5) / (radius * 0.25);
            float n = cfLumps(q, uTime * (0.5 + hr));
            float shape = 1.0 - smoothstep(0.3, 1.0, dot(u, u) + (n - 0.5) * DOME_TURB);   // a cloud and not a ball
            float hug = 1.0 + DOME_HUG * wallness * exp(-(dist - t) / hugRange);
            dens += shape * (0.5 + n) * hug * smoothstep(0.2 * DOME_CELL, 0.7 * DOME_CELL, t);   // thin close to you and thick further
          }
          float w = sigma * dens * seg / float(DOME_STEPS);
          tau += w;
          tint += DOME_COLOR[int(hc * 4.0) & 3] * w;
          walls += (t1 > 0.0 && t1 < dist ? 1.0 : 0.0) + (t2 > 0.0 && t2 < dist ? 1.0 : 0.0);
        }
      }
    }
  }
  tint = tau > 1.0e-5 ? tint / tau : DOME_FAR;
}

#endif
