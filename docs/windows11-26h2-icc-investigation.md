# Windows 11 26H2 ICC transform investigation

Reference: build 26300.9974, [DecodeProfile capture](windows11-26h2-wallpaper-probes-decode-profile.json), original runtime revision 2.

## Reproducible comparison

Run from the repository root:

```sh
python3 scripts/theme/analyze-wallpaper-icc.py
```

Optional repeatable `--target /path/to/profile.icc` arguments compare local RGB destination profiles. The diagnostic reconstructs the exact controlled source, verifies its decoded BGRA SHA-256, verifies all six BGRX capture buffers and both embedded synthetic profiles, transforms the 1,024 distinct colors before resampling using the existing runtime helper, and reports byte hashes, differing pixel/channel counts, total absolute error and maximum channel error. It does not read desktop settings, install profiles or publish an accent. No new runtime dependency or system profile is bundled.

## Measured results

Local isolated run: Pillow 12.3.0, Little CMS 2.19. The reference buffers were reconstructed from the archived row data and checked against the original SHA-256 values. The repository resampling helper was copied verbatim for this run because the container could not resolve github.com. This is not a full repository test or a desktop acceptance run.

Four target profiles, four ICC rendering intents, six Little CMS flag choices and two tagged source profiles produced 192 comparisons. The targets were the generated sRGB profile, the HP-equivalent sRGB profile (SHA-256 049e05b4b9f85e2b65d43e1bed89e301d157f14ba8dadefe3a92e12814d763da), Artifex sRGB (eddaf344b5edea13269e0d20055f335610e5e0b6e33e6e536f2701bc18c5f7d5) and sRGB2014 (384b832de3412066743b52a75ee906b6fb9fb8d9e09e936fc2c43223815c6e0a). None of the target profiles has been verified as the Windows shell destination.

| Source and candidate | Differing pixels / 65,536 | Differing channels | Total absolute error | Max error |
| --- | ---: | ---: | ---: | ---: |
| Untagged control | 0 | 0 | 0 | 0 |
| sRGB, current relative colorimetric | 55,098 | 108,199 | 109,801 | 3 |
| sRGB, best tested (tied with current) | 55,098 | 108,199 | 109,801 | 3 |
| Linear sRGB, current relative colorimetric | 55,405 | 57,238 | 57,441 | 4 |
| Linear sRGB, best tested (NOOPTIMIZE) | 55,380 | 57,187 | 57,390 | 4 |

The small improvement from disabling optimization on the linear sample is insufficient to justify changing runtime semantics. No tested candidate produced an exact buffer.

The two mixed calibration-band rows (169 and 182) in each tagged native buffer match integer bilinear truncation of adjacent native colors in all 1,024 bytes per row. This supports retaining the existing resize kernel for this geometry; it does not prove universal interpolation parity.

On the six active gray/primary channel ramps (1,536 channel samples per profile), the ideal IEC sRGB transfer gives 411 differing channel samples for tagged sRGB and 444 for tagged linear sRGB. Flooring to a 1,024-step linear grid and rounding the final sRGB value reduces the standard sRGB disagreement to 235, but does not reproduce the linear profile. A 1,025-step grid yields 229 disagreements on the standard sample and is not evidence of an actual Windows representation. Gray versus corresponding primary ramps differ at 8/6/3 red/green/blue input levels for standard sRGB and 9/2/8 for linear sRGB. A single independent per-channel LUT cannot explain these observations.

## Remaining boundary

Microsoft documents finite-precision color shifts in [CreateColorTransformW](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-createcolortransformw) and the [WCS RGB virtual device model](https://learn.microsoft.com/en-us/windows/win32/wcs/wcs-color-device-model-profile-schema-and-algorithms). Neither document identifies the wallpaper shell's destination profile, intent, transform flags or quantization implementation on this build. Next discriminate ICC/WCS transform precision and actual destination configuration using native API evidence before introducing any replacement algorithm. Mixed RGB colors, tagged transparency and desktop runtime acceptance remain open. Do not fit or bundle sample-specific corrections. Runtime revision 2 is unchanged.
