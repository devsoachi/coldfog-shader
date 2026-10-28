// options with their value
#ifndef PSEUDOOPT
#define PSEUDOOPT

#ifndef OPTION_MODERN
#define OPTION_MODERN 1.0
#endif
#ifndef OPTION_CLASSIC
#define OPTION_CLASSIC 0.0
#endif
#ifndef OPTION_ALWAYS
#define OPTION_ALWAYS 0.0
#endif
#ifndef OPTION_DAYLOOK
#define OPTION_DAYLOOK 1.0
#endif
#ifndef OPTION_SUN
#define OPTION_SUN 1.0
#endif
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
#ifndef OPTION_LIGHTCUT
#define OPTION_LIGHTCUT 0.3
#endif
#ifndef OPTION_PENETRATION
#define OPTION_PENETRATION 0.6
#endif
#ifndef OPTION_SODIUM
#define OPTION_SODIUM 0.0
#endif
#ifndef OPTION_GLARE
#define OPTION_GLARE 0.0
#endif
#ifndef OPTION_HALO
#define OPTION_HALO 1.0
#endif
#ifndef OPTION_FOGLIGHT
#define OPTION_FOGLIGHT 1.0
#endif
#ifndef OPTION_FOGTEST
#define OPTION_FOGTEST 0.0
#endif
#ifndef OPTION_DARKVISION
#define OPTION_DARKVISION 0.4
#endif
#ifndef OPTION_STAIN
#define OPTION_STAIN 0.0
#endif
#ifndef OPTION_STAINWARM
#define OPTION_STAINWARM 0.5
#endif
#ifndef OPTION_STAINSPOTS
#define OPTION_STAINSPOTS 0.0
#endif
#ifndef OPTION_STAINNIGHT
#define OPTION_STAINNIGHT 0.0
#endif
#ifndef OPTION_SCANLINE
#define OPTION_SCANLINE 0.0
#endif
#ifndef OPTION_SCANLINESIZE
#define OPTION_SCANLINESIZE 3
#endif

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

float cfNight() {
  return smoothstep(0.45, 0.9, uNight) * smoothstep(0.5, 0.8, uEyeSky);
}

float cfNightAll() {
  return smoothstep(0.45, 0.9, uNight);
}

#endif
