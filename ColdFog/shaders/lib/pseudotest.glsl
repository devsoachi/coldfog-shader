// debug test
#ifndef PSEUDOTEST
#define PSEUDOTEST

uniform float uWet;
uniform float uCloudCover;

// alpha is 0 outside the strip, boxes go left to right and every box is 3 percent of the width
// 1 uMist, 2 uMist x 10, 3 fogAt at 100, 4 far range / 400, 5 near range / 400, 6 sun y, 7 sun x, 8 sun z, 9 sun length / 2
// 10 night, 11 to 13 fog colour rgb, 14 fog brightness / 4, 15 weather, 16 morning, 17 cold, 18 sunset, 19 dusk, 20 dawn
// 21 rain, 22 snow, 23 overcast, 24 wet, 25 cloud cover
vec4 cfTest(vec2 uv, float weather, CfDay d) {
  if (!((uv.y < 0.05 || uv.y > 0.95) && uv.x < 0.75)) return vec4(0.0);
  float box = floor(uv.x / 0.03);
  float hm = max(max(uFogColor.r, uFogColor.g), max(uFogColor.b, 1.0e-4));
  float v = (box < 1.0) ? uMist
          : (box < 2.0) ? uMist * 10.0
          : (box < 3.0) ? fogAt(100.0, uFogRange)
          : (box < 4.0) ? uFogRange.y / 400.0
          : (box < 5.0) ? uFogRange.x / 400.0
          : (box < 6.0) ? uSkySun.y * 0.5 + 0.5
          : (box < 7.0) ? uSkySun.x * 0.5 + 0.5
          : (box < 8.0) ? uSkySun.z * 0.5 + 0.5
          : (box < 9.0) ? length(uSkySun) * 0.5
          : (box < 10.0) ? uNight
          : (box < 11.0) ? uFogColor.r / hm
          : (box < 12.0) ? uFogColor.g / hm
          : (box < 13.0) ? uFogColor.b / hm
          : (box < 14.0) ? hm * 0.25
          : (box < 15.0) ? weather
          : (box < 16.0) ? d.morning
          : (box < 17.0) ? d.cold
          : (box < 18.0) ? d.sunset
          : (box < 19.0) ? d.dusk
          : (box < 20.0) ? d.dawn
          : (box < 21.0) ? uRainStrength
          : (box < 22.0) ? uSnowStrength
          : (box < 23.0) ? uOvercast
          : (box < 24.0) ? uWet
          : uCloudCover;
  return vec4(vec3(clamp(v, 0.0, 1.0)), 1.0);
}

#endif
