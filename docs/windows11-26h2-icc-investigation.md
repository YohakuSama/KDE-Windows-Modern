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


## Native API discrimination (next measurement)

A separate offline experiment reused the hash-verified flat calibration rows (1,024 distinct RGB inputs). The exact embedded ICC colorant matrix and chromatic adaptation matrix were used to test XYZ and Lab intermediate quantization under D50 and D65. Uniform 8–16-bit quantization, two grid scales, three intermediate rounding modes and two final rounding modes gave 432 candidates for each tagged profile (864 total). These were limited models, not Microsoft's actual CMM. For standard sRGB the best total absolute channel error remained 541, matching the ideal-transfer baseline; for linear sRGB the best was 460 versus 462. No candidate reproduced either profile. This does not rule out quantization in another domain, a nonuniform multidimensional LUT, or other CMM behavior. Do not change runtime quantization based on these results.

Microsoft documents a sampled multidimensional LUT and interpolation in [WCS Transform Creation Algorithms](https://learn.microsoft.com/en-us/windows/win32/wcs/wcs-transform-creation-algorithms). [CreateMultiProfileTransform](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-createmultiprofiletransform) accepts quality flags and WCS_ALWAYS, the latter forcing the WCS path even for all-ICC transforms. [GetStandardColorSpaceProfileW](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-getstandardcolorspaceprofilew) identifies the registered standard profile, with current-user and system fallback. The [WIC color transform](https://learn.microsoft.com/en-us/windows/win32/api/wincodec/nf-wincodec-iwiccolortransform-initialize) takes explicit source and destination contexts and output pixel format. None of these public APIs identifies the shell's actual parameters by itself.

The standalone [native probe](../scripts/capture-windows-icc-native.ps1) uses the same two synthetic ICC profiles and all 1,024 original calibration RGB colors, independently of wallpaper installation. It compares:

- Registered sRGB/Windows color-space profiles, the installed standard sRGB ICC when present, and the synthetic sRGB target. Identical profile hashes are deduplicated and aliases recorded.
- WIC color-context transforms for opaque BGR24, BGR32 and BGRA32, including an EXIF-sRGB destination.
- CreateMultiProfileTransform and TranslateBitmapBits using default and WCS_ALWAYS paths, all four rendering intents, four quality-flag choices and RGB24/BGRX32 bitmap formats.
- Successes and native errors. Only synthetic RGB inputs/outputs, target-profile hashes, flags, error codes and Windows build are exported, not installed profile contents or paths.

Run in the reference VM using Windows PowerShell:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\capture-windows-icc-native.ps1
```

The report is written to the Desktop as windows-icc-native.json. No wallpaper is applied, no registry value is changed, and no profile is installed.

On Linux:

```sh
python3 scripts/theme/analyze-wallpaper-icc.py --native-report /path/to/windows-icc-native.json
```

The comparator requires build 26300.9974, exact input colors and source ICC hashes, and valid output hashes. It reconstructs full candidate BGRX buffers with the existing resize helper, checks all six archived reference buffers, and ranks candidates by total absolute error. Unsupported API/format combinations stay visible as failures. A fixture-only local test derived candidate colors from the archived buffers; both reconstructed buffers matched their original SHA-256, and a deliberately incorrect output hash was rejected. This verifies the comparison plumbing, not a native transform match. Python syntax was checked locally on the isolated reconstruction. The PowerShell/C# collector has been reviewed against published SDK signatures but has not been compiled or executed on Windows; no native results are claimed. An exact candidate on the calibration set would still need independent mixed-color and transparency validation. Runtime revision 2 remains unchanged.


## Native API results: exact calibration-buffer match

The standalone probe was executed successfully on the reference build 26300.9974. All 274 candidates succeeded (256 ICM and 18 WIC); every 3,072-byte output and the input SHA-256 verified. The registered sRGB, registered Windows and installed sRGB targets all resolved to the same 3,144-byte ICC profile, SHA-256 `2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E`. The synthetic target is a separate profile. There are 29 distinct outputs for the sRGB input and 31 for linear sRGB.

The offline comparator was executed in the isolated reconstruction of the repository with the existing resize helper; all six original buffer hashes and the source BGRA hash verified. A separate vectorized resampling check independently reproduced the same full-buffer hashes. The following paths matched both native cache buffers in every byte:

| API | Destination | Formats | Intent | Flags |
| --- | --- | --- | --- | --- |
| WIC | registered sRGB or EXIF sRGB | BGR24, BGR32, BGRA32 | API default | API default |
| ICM | registered sRGB | RGB24, BGRX32 | 0, 1, 2 | 3 (BEST_MODE) |

There were 12 exact candidates per source (24 total); these are equivalent outputs on this calibration set, not 24 independent algorithms. Both reconstructed 256x256 BGRX buffers matched their archived SHA-256. No other candidate matched, including forced WCS_ALWAYS. The best forced WCS candidates still differed by 65,536 and 42,328 pixels, with maximum errors 24 and 32 respectively for the two profiles. The tested evidence shifts priority from forced WCS quantization to the high-quality ICC-compatible transform. It does not uniquely prove the shell's private call sequence or rendering intent.

A [compact native evidence excerpt](windows11-26h2-icc-native-matches.json) preserves the original report SHA-256, the two exact WIC output buffers, their source/target identities and the matching parameter families. The full user-supplied report was analyzed locally; only representative synthetic outputs are archived. Regression coverage reconstructs both exact buffers from these independently captured RGB values using the existing runtime resampler. These bytes are test evidence only, not runtime lookup tables.

The Windows reference operation is now reproduced for the measured opaque ICC calibration set. The portable Linux implementation remains revision 2 and is not byte-identical. Next investigate the ICC-compatible CMM's high-quality transform and the verified destination profile's structure; independently validate mixed RGB inputs and tagged transparency before a runtime change. No additional capture is required for this comparison. No full repository test or CI has been run.
