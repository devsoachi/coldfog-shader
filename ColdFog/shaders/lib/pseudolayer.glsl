// fog layers library needs pseudonoise first
#ifndef PSEUDOLAYER
#define PSEUDOLAYER

const int LAYER_STEPS = 4;
const float LAYER_HEIGHT = 4.0;
const float LAYER_SWIRL = 0.85;
const float LAYER_LUMP = 10.0;

// amount is the classic option already scaled by the weather
float cfLayer(vec3 vd, float dist, float amount, float clump) {
  float dmax = min(dist, 60.0);                      // past this the fog is already dense
  float groundY = uEye.y - 1.7;
  float jit = cfHash21(gl_FragCoord.xy + 5.588 * float(uFrame & 63));   // the grain hides the stepping
  vec2 wind = vec2(uTime * 0.05, uTime * 0.03);
  float tau = 0.0;
  for (int i = 0; i < LAYER_STEPS; i++) {
    vec3 p = uEye + vd * (dmax * (float(i) + jit) / float(LAYER_STEPS));
    float n;
    if (clump > 0.0) {
      n = cfLumps(p.xz / LAYER_LUMP, uTime);
    } else {
      vec2 q = p.xz * 0.11 + wind;
      n = 0.65 * cfNoise(q) + 0.35 * cfNoise(q * 2.7 + 17.3);
    }
    tau += exp(-max(p.y - groundY, 0.0) / LAYER_HEIGHT) * mix(1.0, 2.0 * n, LAYER_SWIRL);
  }
  tau *= dmax / float(LAYER_STEPS);
  return 1.0 - exp(-tau * amount * 0.3);
}

#endif
