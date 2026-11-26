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


## Exact destination profile and fixed-point investigation

The 3,144-byte standard sRGB profile from the native probe was obtained independently for local analysis from [a publicly accessible historical ImageMagick source tree](https://github.com/mikesplain/imagemagick/blob/master/config/sRGB.icm). Its SHA-256 exactly matches the measured registered target: `2B3AA1645779A9E634744FAF9B01E9102B0C9B88FD6DECED7934DF86B949AF7E`. It is ICC v2.1, XYZ PCS, with preferred CMM signature Lino, three XYZ colorants and a shared 1,024-point monotone TRC. There is no embedded A2B/B2A transform CLUT in this destination. The header CMM preference does not establish which CMM actually created the Windows transform. The profile is not redistributed in this repository.

The new [offline diagnostic](../scripts/theme/analyze-wallpaper-icc-engine.py) requires NumPy and Pillow (research only, not runtime) and refuses a nonmatching destination hash. It checks the original RGB input and source-profile/output hashes against the compact native evidence and computes errors over 1,024 unique RGB colors (3,072 channels per source), not repeated image pixels.

```sh
python3 scripts/theme/analyze-wallpaper-icc-engine.py --target /path/to/local/sRGB.icm
```

Pillow 12.3.0 / Little CMS 2.19 / NumPy 2.3.5, isolated local reconstruction using native RGB bytes verified against the archived hashes. Forty-eight Little CMS candidates (the exact destination, four intents, six flag choices, two sources) still do not match. The diagnostic then evaluates 32,768 shared multi-stage fixed-point parameter sets on both source profiles (65,536 comparisons), using only their actual profile matrices and curves. It compares input scaling, rounding at source linear RGB, XYZ and destination linear RGB, and final output scaling. The best shared model must use the same options for both profiles.

| Model | sRGB absolute channel error sum / differing channels / max error | Linear sRGB absolute channel error sum / differing channels / max error |
| --- | --- | --- |
| Best Little CMS with exact target | 541 / 415 / 3 | 485 / 469 / 4 |
| Direct profile matrix and inverse TRC, round 255 | 541 / 415 / 3 | 485 / 469 / 4 |
| Same direct transform, floor 256 and clamp | 523 / 403 / 3 | 139 / 130 / 3 |
| Best shared multi-stage candidate | 107 / 103 / 2 | 141 / 132 / 3 |

The best shared parameter set uses input normalization by 255, floor at 10-bit source linear RGB, ceil at 14-bit XYZ, ceil at 16-bit destination linear RGB, linear interpolation of the inverse target TRC and final floor after scaling by 256 (clamp to 255). Total absolute error falls from 1,026 to 248, but no set is exact. This is a hypothesis selected on the calibration inputs, not a verified CMM implementation. No runtime logic or cache revision is changed.

Additional local exploratory sweeps tested single-stage quantization with sampled TRC inversion (3,912 comparisons) and uniform RGB grids with trilinear/tetrahedral interpolation (1,152 comparisons); neither achieved equality. The committed diagnostic reproduces the exact-target Little CMS and shared multi-stage sweep, not those separate exploratory scripts.

Next measure the actual CMM identifier/version with [GetCMMInfo](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-getcmminfo), distinguish intermediate from final rounding with native higher-bit RGB outputs, and test whether [CreateDeviceLinkProfile](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-createdevicelinkprofile) exposes a usable intermediate transform. The public API's success and agreement with the measured BEST_MODE bitmap path must be established before relying on its output. Do not bundle a device link as a general replacement for arbitrary input ICCs. Independent mixed-color/transparent reference validation is still outstanding.

Local checks: Python syntax compilation, execution of the diagnostic with the hash-matching target, and rejection of a different target profile. The source tree in the local test directory is an isolated reconstruction using the original native report and matching archived input/output hashes; no full repository build, desktop acceptance, or CI was executed.


## Native precision and device-link measurement protocol

The new standalone [precision collector](../scripts/capture-windows-icc-precision.ps1) reuses the verified source profiles and registered standard RGB target. It requires the original reference build 26300.9974 and exact target profile hash. The 1,024 previous calibration colors are followed by a disjoint 16 x 16 x 16 mixed-color grid (R=8+16i, G=4+16j, B=12+16k). The grid adds 4,096 previously unseen colors, with distinct channel residues. It is reserved for independent checks rather than fitting the current model.

For both source profiles and the three matching intents (0, 1, 2), the collector creates a BEST_MODE transform once and measures 8- and 16-bit normalized input to 8-, 10- and 16-bit RGB output. GetCMMInfo records the actual CMM signature and versions. WIC BGR24 supplies an independent comparison; its first 1,024 outputs must exactly reproduce the previous native reference. The 16-bit input repeats each original byte (n*257); native output packing follows the [BMFORMAT byte layout](https://learn.microsoft.com/en-us/windows/win32/api/icm/ne-icm-bmformat).

CreateDeviceLinkProfile is attempted with the same source, destination, intent and flags. Returned memory is bounded by GlobalSize and the ICC header length, then released using GlobalFree as specified by Microsoft. If generated, the synthetic device link is captured and reopened as a single-profile transform for identical replay measurements. Unsupported formats or failed device-link calls are recorded separately, not interpreted as successful outputs. No Windows profile installation, DLL redistribution, wallpaper change or registry write occurs. Only synthetic color inputs and outputs, generated links for these two synthetic sources, profile hashes and CMM metadata are recorded. Device links are investigation evidence only, not a general runtime solution.

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\capture-windows-icc-precision.ps1
```

The report is written to the Desktop as windows-icc-precision.json.

```sh
python3 scripts/theme/analyze-wallpaper-icc-precision.py /path/to/windows-icc-precision.json
```

The NumPy-based comparator verifies input/source/target identity and all successful output hashes, requires the original WIC calibration to match, separates mixed and calibration metrics, compares four high-bit downconversion rules with the matching input-format RGB8 path, and reports device-link tag types/grid dimensions and replay differences. Agreement of downconversion rules would be evidence about output packing, not proof of the internal CMM representation.

Local validation: Python syntax compilation, exact prior calibration-input hash and 4,096 disjoint mixed inputs, synthetic RGB8/10/16 test buffers, synthetic ICC link-header parsing and replay metrics, rejection of tampered output hashes and of a nonmatching WIC baseline. The synthetic test does not establish native high-bit behavior or valid generated ICC link contents. The Windows PowerShell/C# code has been reviewed against the documented API signatures but cannot be executed in this Linux container. No actual CMM ID, high-bit results, or device-link availability is claimed until the new measurement returns. Runtime revision 2, main and CI are unchanged.


## Native precision result and exact portable RGB8 device-link execution

Reference build 26300.9974; original precision report SHA-256 `42F2C3D2FEBE30FC65B8F04F931CD154AFA520116DD5A40356C62AF9B5BDA76A`. All 81 binary payloads passed size and SHA-256 validation (one input, two WIC outputs, 36 direct outputs, six device links, and 36 replay outputs). All six transforms and links succeeded. GetCMMInfo reported CMM signature 0x57696E20 ("Win "), DLL version 65536 and Win version 262144, for every direct and replay transform. These are CMM-reported API versions, not the installed Windows build.

All three intents for each source returned identical direct RGB8 data; native WIC matched on all 5,120 colors, including the previously unseen 4,096 mixed inputs. Native replay matched the direct raw buffers for all six format combinations, across all six transforms.

All device links are 205,204-byte ICC v2.1 RGB-to-RGB profiles. A2B0 contains an mft2 tag with an identity matrix, three 256-entry 16-bit input tables, a 32 x 32 x 32 three-output 16-bit CLUT, and three 1,024-entry 16-bit output tables. The A2B0 contents are identical across the three intents within each source. The CLUT and output tables are identical between sources; input curves differ. Table hashes and reference output hashes (no captured tables or profile bytes are bundled):

| Component | SHA-256 |
| --- | --- |
| sRGB input curves | 888A2852424F361D9A87E68B17365304A7B49CFE4FCA63D22A0EFF13620F0ED3 |
| Linear sRGB input curves | 8B814990ADF93775BF8BFAF2C3A54DCEDE47D1F68E81809388E7E1D9624B24D6 |
| Shared CLUT | 61A243BB0A50A4B0346873DA3D9C6F20FDDC7EC2945DD8946B6DD2E8D93658B2 |
| Shared output curves | 1943A4178D0F62F28694CE524D529A944F04CBB4E7E9FC4722ABC906A13BF216 |
| sRGB RGB8 output | EE7B6683A8D6C9395DCF89DBEF9E1016C8EC6D1B2DBCC07B651367AF4F64878F |
| Linear sRGB RGB8 output | F35265C39A8D89B7B0AF1ED7755758084064601F017E65804EF6295BA00B2725 |

The prior shared matrix-based model was tested without refitting. It produced absolute channel error sums of 1,239 and 1,447 on the two independent mixed-color sets, versus 107 and 141 on the original calibration inputs. It is not a verified runtime algorithm.

A device-link replay experiment using the captured tables compared 2,304 shared interpolation/quantization models, then 896 shared fractional-precision/rounding models. Ranking used only the original calibration errors; the mixed set was evaluated separately. The best fixed-point model was exact on both sets. Implemented using integer operations only:

1. Read each RGB8 code from its 256-entry input curve (unsigned 16-bit).
2. Compute p = (curve_value * 31) >> 5. The high bits p >> 11 select a cell; p & 2047 is its 11-bit fractional coordinate.
3. Sort fractions descending, follow the corresponding tetrahedron's three edges, and accumulate the first grid vertex times 2048 plus each signed edge delta times its fraction. Do not round individual terms.
4. Shift the accumulated numerator right by 17 (11 interpolation bits + six low output bits) to index the 1,024-entry output table.
5. Return the high byte of each output table value.

The revised precision comparator implements this execution directly from the supplied device links and verifies the old WIC calibration, input identity, all successful buffer hashes, portable RGB8 output against WIC and direct ICM, and native replay versus direct output. All six portable runs matched on all 5,120 input colors, giving zero differing channels and identical output hashes; the two distinct sources account for 10,240 colors and 30,720 channel values, without counting repeated intents as independent tests. The report remains external to the repository. No native code is called by the portable execution helper.

High-bit caveat: despite the documented BM_16b_RGB byte ordering, the captured 8-to-16 raw output shows red/blue reversal (e.g. input (0,0,1) yields the first 16-bit word nonzero rather than the third), and 16-bit inputs show swapped output red/blue. Exact raw replay remains valid, but this invalidates interpreting the earlier raw cross-depth comparisons as rounding measurements. The updated analyzer restricts cross-depth comparisons to 8-to-10 and labels the 16-bit packing issue unresolved. Do not infer 16-bit interpolation from these raw buffers.

**Remaining implementation boundary:** execution of measured RGB8 device-link tables is reproduced; generation of equivalent tables from arbitrary ICC profiles is not. The direct matrix model differed from the shared native CLUT by up to 41 units at 16-bit grid nodes; direct sampled TRC inversion also differed. Next reproduce the source-curve, CLUT and output-curve construction, rather than packaging the captured tables. Tagged transparency and independent ICC profile families still need validation. No runtime change, new runtime dependency, CI or main change. Local syntax compilation and end-to-end analyzer execution used the supplied precision report and the archived calibration evidence from the isolated research directory; no full repository build or KDE desktop test was performed.


## Independent curve generation and CLUT construction candidates

The two curve stages have now been independently generated from the original ICC profiles. Neither generator consumes captured table values. The measured source inputs are shared parametric TRCs of types 0 and 3; the destination is the verified shared 1,024-point sampled TRC. This scope does not cover arbitrary ICC LUT profiles, other parametric types, channel-specific curves, or transparency.

- Source: sample codes 0,4,...,252,255. Multiply by the binary64 reciprocal of 255, evaluate the actual ICC parametric curve, multiply by 65535 and floor. Interpolate between the resulting integer anchors with half-up rounding, including the final three-code interval. Replacing reciprocal multiplication with division changes 24 linear-source samples.
- Destination: for index i, compute x = floor((65535*i+511)/1023). Find the monotone TRC interval containing x, choosing the preceding interval at exact interior knots. For interval k, calculate floor(65536*k/1023) + floor(65536*(x-TRC[k])/(1023*(TRC[k+1]-TRC[k]))), clamped to 0..65535.

Each generated 768-entry input table and the shared 3,072-entry output table (three channels) exactly matches the native hash recorded above. Replaying with the independently generated curves and the still-native CLUT reproduces all 5,120 RGB8 colors for each source. This is not a fully independent CMM: the CLUT remains an essential native input in that particular comparison.

The RGB8 execution helper now accepts validated integer table arrays separately from device-link parsing. The new diagnostic constructs two experimental CLUTs directly from the profile matrices (no captured table values or per-color corrections) and reports both table-level and final RGB8 errors.

| Generated CLUT | Differing entries / 98,304 | Absolute error sum | Max 16-bit error |
| --- | ---: | ---: | ---: |
| Direct matrix | 91,580 | 698,630 | 41 |
| Quantized matrix/XYZ candidate | 63,513 | 542,583 | 43 |

The quantized candidate uses nearest rounding on the source matrix at 14 fractional bits, XYZ at 13 fractional bits and inverse matrix at 16 fractional bits, then floors the 16-bit output. An exploratory analysis of 27,000 interior native grid points also found a pronounced approximately eight-unit XYZ quantization pattern when applying the target matrix to native output. This is evidence for further investigation, not proof of the internal CMM arithmetic.

| Model | sRGB calibration / mixed differing colors | Linear sRGB calibration / mixed differing colors |
| --- | ---: | ---: |
| Generated curves + native CLUT | 0 / 0 | 0 / 0 |
| All stages generated, direct matrix | 41 / 215 | 33 / 408 |
| All stages generated, quantized candidate | 50 / 219 | 37 / 370 |

The improved CLUT error does not imply a better final transform on every sample. Neither model passes the zero-error requirement, and neither enters the runtime.

Reproduce with the previous precision report and the verified local target ICC:

```sh
python3 scripts/theme/analyze-wallpaper-icc-generation.py /path/to/windows-icc-precision.json --target /path/to/sRGB.icm
```

Local checks: both Python files compiled, all precision-report buffers and reference inputs were checked by the existing diagnostics, the regenerated curves matched the native table hashes, and invalid curve shapes, out-of-range table entries and incorrect target profiles were rejected. The local directory remains an isolated research reconstruction, not a full repository checkout. No runtime cache revision, new runtime dependency, main change or CI run. Next isolate forward XYZ and inverse matrix fixed-point construction; additional ICC profile families and tagged alpha remain unverified.


## Separate CLUT coordinate and matrix quantization

The new [matrix diagnostic](../scripts/theme/analyze-wallpaper-icc-matrix.py) checks the previous full precision report, exact ICC source/destination identities, independently generated curves and all six native RGB8 replays. It then projects the 27,000 unclipped interior native grid nodes through the target colorant matrix. In units of 8 raw CLUT codes, the projected XYZ residuals from their nearest integer lie within [-0.291,-0.013], [-0.359,-0.016], and [-0.228,-0.003] for X, Y, Z. This is consistent with an approximately 13-fractional-bit PCS lattice. It does not directly observe the native intermediate representation. The inferred nearest lattice indices are diagnostic values only.

An exploratory decomposition of the residuals by grid axis revealed an alternating odd/even offset close to half a 14-bit coordinate step (with an anomalous region at node 13). This motivated testing quantized coordinates before the matrix, rather than changing the already verified tetrahedral execution. The reproducible full-grid sweep covers 672 combinations of coordinate sampling, source matrix precision, XYZ rounding, inverse matrix precision and output quantization. The best table-level candidate differs from the previous fixed13 candidate only by round-half-up sampling of each grid coordinate at scale 16384.

| Model | Differing table entries / 98,304 | Absolute table error sum | Max table error |
| --- | ---: | ---: | ---: |
| Previous fixed13 | 63,513 | 542,583 | 43 |
| 14-bit grid sampling + fixed13 | 61,369 | 508,403 | 43 |

| Model | sRGB calibration / mixed differing colors | Linear sRGB calibration / mixed differing colors |
| --- | ---: | ---: |
| Previous fixed13 | 50 / 219 | 37 / 370 |
| 14-bit grid sampling + fixed13 | 29 / 163 | 25 / 316 |

No candidate is exact. On the inferred interior PCS lattice, forward-model disagreements decrease from 16,880 to 15,151 of 81,000 values, each by one lattice unit. Supplying those inferred PCS indices directly to the candidate inverse calculation still leaves 29,337 differing interior RGB entries (absolute error sum 29,361, maximum 2). Thus changing coordinate sampling alone does not resolve the full calculation. The inferred PCS is not a native measurement, and neither model enters the runtime. No per-color correction is fitted or bundled.

```sh
python3 scripts/theme/analyze-wallpaper-icc-matrix.py /path/to/windows-icc-precision.json --target /path/to/sRGB.icm
```

Rather than further fit the same pair of matrices, the standalone [controlled matrix probe](../scripts/capture-windows-icc-matrix.ps1) reuses the previously executed ICM BEST_MODE/relative-colorimetric collector helper and adds four small synthetic ICC v2.1 matrix/linear-TRC profiles: a D50 diagonal, a mixed matrix, a mixed matrix with 1–4 code colorant perturbations preserving its white point, and a v2 profile with the original source colorants. The nine source/target combinations include the original control, v2/v4 comparison, diagonal-to-diagonal, forward matrix isolation, inverse matrix isolation and perturbation tests. The diagonal profile is a mathematical diagnostic, not a real display profile. All synthetic ICCs were loaded and converted successfully using Little CMS locally. Native acceptance is not yet verified.

The collector exports only synthetic ICC inputs, calibration RGB inputs and outputs, generated device links, CMM metadata, hashes and errors. It does not export the installed sRGB profile, modify wallpaper, install profiles, write registry values, or require elevation. It checks the reference build, original target and input hashes. Unsupported native combinations are recorded rather than treated as matching.

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\capture-windows-icc-matrix.ps1
```

Output: windows-icc-matrix.json on the Desktop. This is a focused measurement to isolate both matrix stages and low-bit coefficient sensitivity; it is not a repeat of the wallpaper capture. The PowerShell wrapper and synthetic ICC inputs have been inspected locally, but the new combinations have not been run on Windows. Python syntax compilation and the full matrix diagnostic passed using the actual supplied precision report in the isolated research checkout. Runtime revision 2, main and CI remain unchanged.


## Controlled matrix capture results and RGB8 endpoint correction

The controlled matrix probe completed on build 26300.9974. Report SHA-256: `8D746E6AD1BD358F46245612B4D824A098BF8304C664535A95B36D2C2D97B55A`. All 32 binary payloads verified (one calibration input, four synthetic profiles, nine device links, nine direct RGB8 outputs and nine native link-replay outputs). All nine ICM transforms and device links succeeded, reported CMM "Win ", and matched their native replay. The original linear-sRGB control also matched the prior RGB8 hash.

The previous portable execution had three differing colors in each of the mixed-to-diagonal and mixed-delta-to-diagonal cases, all involving maximum input codes: (0,0,255), (255,0,0), and (255,0,255). With a source curve code of 65535, the ordinary coordinate calculation gives 63487 (cell 30, fraction 2047) instead of the exact final vertex. Treat that endpoint as fraction 2048 in cell 30. This correction produces exact RGB8 hashes for all nine new transforms (9,216 color evaluations) and preserves exactness for the previous two distinct 5,120-color sets and all six previous intent replays. The new diagnostic contains a synthetic endpoint regression, not a color-specific output adjustment.

Matrix-specific observations:

- The v2 and v4 linear source profiles with the same colorants yield identical input curves, CLUT and output curves for the registered sRGB target.
- Changing the mixed source colorants by 1–4 signed 16.16 codes while preserving the white point changes zero of 98,304 CLUT entries when the target is the diagonal profile. Applying the same perturbation to the destination with the diagonal source changes 58,827 of 98,304 entries. Forward and inverse coefficient handling must be tested separately; the result alone does not establish a particular bit width.
- With linear sRGB as source, both the diagonal and registered sRGB destinations yield the same inferred XYZ lattice indices at all 29,895 mutually unclipped grid nodes (89,685 channel values). Compute these indices by multiplying each native RGB grid output by its destination colorant matrix, dividing by eight and rounding to the nearest integer. This is consistent with a shared approximately Q13 PCS representation, but the intermediate indices are inferred from native RGB output, not directly captured.
- The diagonal control has no cross-channel leakage, yet its Y-axis inferred indices at the first two nonzero grid positions are 265 and 529. Round-half-up Q14 coordinate sampling followed by flooring to Q13 yields 264 and 528; the other 30 positions match. A simple uniform quantized coordinate model is therefore insufficient.

The remaining inverse-stage error can be isolated by supplying the inferred diagonal-source PCS indices to the existing approximate Q16 inverse matrix candidate. Evaluate 27,000 interior nodes for each destination:

| Destination | Differing entries / 81,000 | Absolute error sum | Max raw 16-bit error |
| --- | ---: | ---: | ---: |
| Diagonal | 16,200 | 16,200 | 1 |
| Registered sRGB | 20,340 | 20,613 | 2 |
| Mixed | 31,355 | 32,701 | 2 |
| Mixed-delta | 36,986 | 38,885 | 2 |

These errors are for an inferred-input diagnostic, not an independently generated CLUT. Exploratory shared forward/inverse rounding sweeps did not find an exact model. In particular, quantizing the source coefficients to nearest Q13 or Q12 makes the mixed perturbation invariant, but the tested invariant candidate worsened the original registered-sRGB CLUT compared with the preceding fixed13 model. Do not infer the native matrix precision solely from the perturbation. No candidate is promoted to runtime. The newly tested linear destination output curve also differs from naive rounded linear sampling at 270 of 1,024 positions; the previously verified output-curve generator was scoped to the registered sampled sRGB target.

Reproduce the controlled capture checks with the local, hash-matching sRGB ICC:

```sh
python3 scripts/theme/analyze-wallpaper-icc-matrix-capture.py /path/to/windows-icc-matrix.json --target /path/to/sRGB.icm
```

The updated diagnostics were compiled and run locally against the actual matrix and previous precision reports, using the isolated repository reconstruction. All nine new and six previous RGB8 replays matched, the synthetic endpoint regression passed, and a tampered link hash was rejected. The new analyzer does not archive the native device-link tables or the full report. Full independent table generation, additional ICC families and tagged alpha remain unresolved. No runtime/cache revision, main or CI change.


## Matrix separability counterexamples and periodic residuals

The [quantization diagnostic](../scripts/theme/analyze-wallpaper-icc-quantization.py) reruns the complete controlled matrix report validation, including nine exact portable RGB8 replays, then examines the four source profiles converted to the diagonal destination. No new measurement or runtime dependency is required. It uses the same inferred PCS code q = round(M_destination * native_RGB16 / 8), excludes clipped output components, and does not treat q as a directly captured native buffer.

The diagonal target provides 7,457, 7,180 and 6,266 distinct inferred X, Y and Z values respectively. Repeated inferred scalar codes always map to the same raw output component across these four source profiles. This supports investigating the inverse scalar normalization separately.

For an affine scalar transform with a single final quantizer whose error lies in an interval of width one, any two unclipped samples (q1,y1) and (q2,y2) constrain the slope to [(y2-y1-1)/(q2-q1), (y2-y1+1)/(q2-q1)]. The diagnostic finds strictly incompatible rational bounds for every component:

| Component | Lower slope bound | Upper slope bound |
| --- | ---: | ---: |
| X | 17/2 | 315/38 |
| Y | 8 | 32783/4098 |
| Z | 59/6 | 281/29 |

For example, the Y samples (66,527) and (75,600) require a slope >= 8, while (2958,23664) and (7056,56446) require a slope <= 32783/4098. These witnesses reject the single-affine, single-uniform-rounding model on the inferred lattice even if the coefficients and offset are freely chosen. They do not establish the actual internal PCS representation.

The diagonal green colorant is exactly one, so the residual is native_green - 8*q. Its observed range is -2..0. Comparing values separated by a fixed PCS-code lag reveals a 128-code periodic structure with a downward trend:

| Lag | Available pairs | Equal residual | Increase | Decrease |
| ---: | ---: | ---: | ---: | ---: |
| 16 | 7068 | 5637 | 708 | 723 |
| 32 | 7031 | 4649 | 1181 | 1201 |
| 64 | 7044 | 3943 | 1534 | 1567 |
| 128 | 6960 | 6846 | 0 | 114 |
| 256 | 6811 | 6587 | 0 | 224 |
| 512 | 6561 | 6130 | 0 | 431 |

This favors investigation of staged normalization or segmented fixed-point calculations rather than another single affine coefficient adjustment. It does not prove a 128-entry internal LUT or an exact quantization formula.

Forward-stage test: if an inferred coordinate is formed from three arbitrary independent axis contributions plus a constant and one floor (or ceil or half-up) operation, its alternating sum on any two-axis rectangle is -1, 0 or 1. The actual inferred coordinates contain violations on all three components of both independent source matrices:

| Source | X violations | Y violations | Z violations |
| --- | ---: | ---: | ---: |
| Linear sRGB | 814 | 117 | 7 |
| Mixed | 33 | 1712 | 171 |

For the linear-sRGB X coordinate, one adjacent rectangle is [[719,820],[833,936]], with alternating sum 2. The diagnostic reports a witness for each component and counts adjacent rectangles across all three axis pairs, excluding clipped outputs. This rejects the stated single-round separable model on the inferred coordinates, not arbitrary staged or nonuniform quantization.

An additional exploratory search evaluated 22,464 candidate forward models (coordinate/coefficient precision, optional term rounding, pair order, intermediate rounding and final rounding) on a deterministic subset of the linear-sRGB and mixed grids, then reevaluated the top 100 on the full unclipped grids, with mixed-delta and diagonal as holdouts. The previous candidate accumulated 36,311 lattice-unit errors across the two training grids; the best reevaluated staged candidate accumulated 36,188, while worsening the linear-sRGB error individually from 18,619 to 20,102. No promoted algorithm resulted. This sweep is separate exploratory work; the committed diagnostic reproduces the structural counterexamples rather than this search.

Reproduce:

```sh
python3 scripts/theme/analyze-wallpaper-icc-quantization.py /path/to/windows-icc-matrix.json --target /path/to/sRGB.icm
```

Local checks on the isolated repository reconstruction: the precision and matrix-capture helper Git blob hashes match the testing revisions; Python syntax compilation passed; the supplied matrix report was fully validated; the synthetic affine, incompatible-slope, periodic-identity and separable-grid tests passed; a tampered link hash was rejected; the previous six intent replays on 5,120 colors each remained exact. No full repository build, desktop acceptance or CI was run. No captured normalization LUT, sample-specific corrections, runtime or main changes. Independently generating the complete CLUT remains open.


## Linear ICC v2 curve generation and inverse projection ordering

The previously unresolved linear target curve is now generated independently from the ICC v2 unity-gamma curveType tag (count 1, u8Fixed8 value 256). The input curve uses the same four-code source-anchor construction as the measured linear parametric v4 curve. The output curve uses anchors at indices 0,16,...,1008,1023, with integer values round-half-up(65535*i/1023). Interpolate the integer anchors with half-up rounding, including the final 15-code interval. A 16-code interval is exact on the measured curve; naive per-index rounding differs at 270 positions. The generated linear destination table SHA-256 is `0802A0EAAEA62A838818E62E3485650B01B939B3CE858E9294B24D63273FE19A`. No recorded curve values are used by the generator.

The existing generation diagnostic now shares integer anchor interpolation between the two curve stages, and the existing matrix-capture diagnostic regenerates the input and output tables for all nine source/target pairs directly from their verified profiles. All 6,912 input-table entries and 27,648 output-table entries match (counts include repeated tables for different transforms), and all 9,216 RGB8 evaluations match when the independently generated curves are combined with the native CLUT. The prior two 5,120-color precision sets remain exact with generated curves and native CLUT. The newly covered curve format is unity-gamma v2 only; other gamma curves and arbitrary ICC LUT profiles are not newly verified.

The inverse quantization diagnostic now also compares projection ordering for each measured destination and channel, using every available source that was independently converted to the diagonal profile. Starting with inferred unclipped PCS codes, compute the exact inverse projection key with the adjugate of the signed 16.16 colorant matrix (the positive determinant is common within each destination), and compare against the nearest-Q16 inverse coefficients using integer arithmetic. Exclude clipped observed channels; group equal keys and check whether the maximum output at a lower key exceeds the minimum output at the next distinct key. A reversal rejects any deterministic monotone scalar post-map for that specific inverse coefficient matrix on the inferred PCS codes, rather than only rejecting a particular rounding mode.

| Destination | Exact inverse: reversed adjacent keys (R/G/B) | Nearest-Q16 inverse: reversed adjacent keys (R/G/B) |
| --- | --- | --- |
| Diagonal | 0 / 0 / 0 | 0 / 0 / 0 |
| Registered sRGB | 2271 / 3579 / 2202 | 2871 / 1900 / 890 |
| Mixed | 0 / 402 / 91 | 0 / 203 / 3 |
| Mixed-delta | 212 / 0 / 119 | 212 / 0 / 119 |

No equal-key conflicts were found in these within-destination comparisons. The diagonal green residual also shows a 512-code modulation of its 128-code repeating structure: the boundary of the one-unit residual interval moves between blocks. A simple affine sawtooth model with a 512-code block index and a 128-code phase still misses 56 of the 7,180 observed values; it is not used as a generator. The order reversals do not reject every possible inverse coefficient matrix. Exploratory ordering constraints with freely adjustable row coefficients admit alternative linear orderings on the measured sets, but those fitted coefficients and arbitrary monotone maps are not portable formulas. Neither the inferred PCS nor the fitted coefficients are directly observed native intermediates.

Reproduce with the existing matrix-capture, generation and quantization commands. Local static Python AST parsing passed for all three changed files. Offline analysis of the supplied matrix report and previous precision report confirmed the exact curve hashes and matching RGB8 replays above. No full repository build, automated test suite, desktop acceptance, CI, runtime change or main change. All of the CLUT construction still needs a general profile-derived solution; the verified curve changes do not remove the dependency on the native CLUT for exact replay.


## Isolated PCS boundary measurement (pending native capture)

The existing matrix report provides indirect PCS estimates, not an independently measured intermediate. Further offline exploration evaluated 18,720 shared models of an internal sampled matrix stage (trilinear/tetrahedral interpolation, 1–128 cells per axis, coordinate/fraction precision, colorant quantization and vertex/final rounding). Candidate ranking used 1,024 deterministic sampled grid nodes for each of linear-sRGB and mixed; the best 30 were reevaluated on full unclipped component data with mixed-delta and diagonal holdouts. The best reevaluated candidate had absolute inferred-lattice error sums 19,896 and 14,910 on linear-sRGB and mixed, but 28,039 and 13,312 on the respective holdouts. No model was exact or adopted. This exploratory sweep is not a runtime change or an automated project test.

The next experiment deliberately separates the two stages with synthetic ICC v2.1 color-space profiles, rather than fitting more parameters to the same RGB-to-RGB device links. The existing [matrix collector](../scripts/capture-windows-icc-matrix.ps1) gains an optional Pcs probe set; its default Matrix report and original nine-pair loop are retained.

Three new in-memory profiles use two-point input/output tables, a 2x2x2 mft2 CLUT and an identity matrix in both A2B0 and B2A0. The XYZ-to-XYZ and RGB-to-XYZ bridge profiles preserve the raw normalized PCS words; a second RGB bridge swaps X and Z in both directions. The color-space class is spac, and these are mathematical controls, not display calibrations. All three exact profile byte hashes were checked, and independent Little CMS 16-bit transforms reproduced the intended identity and ZYX permutation on asymmetric marker colors. That establishes their intended mapping in Little CMS only; acceptance, sampling behavior and fidelity in the Win CMM are unverified.

The new probe uses 23 directed source/target pairs. Each receives 57,355 three-word inputs: eight asymmetric/end-point markers, 32,768 full-range normalized grid nodes, and three dense axis sweeps of 8,193 codes (q*4 for q=0..8192). The independently calculated input hash is CE19EB355E773C647F28C7A7DD9FDE12B756955FC590C0B4CD51996B2ACD9997. It measures TranslateColors (COLOR_RGB / COLOR_XYZ), TranslateBitmapBits (BM_16b_RGB / BM_16b_XYZ) and generated device links independently, recording unsupported cases separately. The [Windows SDK COLOR union](https://github.com/tpn/winsdk-10/blob/master/Include/10.0.14393.0/um/Icm.h) includes pointer-alignment padding, so the COLOR array stride is 16 bytes on 64-bit Windows and 8 bytes on 32-bit Windows. Only the first six bytes of each entry are exported. Bitmap rows are padded to a DWORD boundary and processed in bounded batches. See [TranslateColors](https://learn.microsoft.com/en-us/windows/win32/api/icm/nf-icm-translatecolors) and [BMFORMAT](https://learn.microsoft.com/en-us/windows/win32/api/icm/ne-icm-bmformat). No assumptions about observed channel ordering, XYZ normalization or CMM internal precision are made before the identity/permutation controls and the old RGB-to-RGB links are compared.

The intended discrimination is between source-to-PCS construction, PCS-to-destination construction, device-link sampling and 16-bit API packing. A successful XYZ or RGB bridge must first agree with the corresponding controls; even successful API creation does not prove that its path is identical to the internal matrix-only transform. The output contains gzip-compressed base64 input, result and link buffers with uncompressed lengths and SHA-256 hashes; this limits upload size. Only synthetic data and existing profile hashes are collected, not installed profile contents. No registry, wallpaper, installed profile or display settings are changed.

Run the updated collector on the reference Windows VM:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\capture-windows-icc-matrix.ps1 -ProbeSet Pcs
```

The default Pcs output is windows-icc-pcs.json on the Desktop. Static review covered the full diff, documented native signatures, array strides, allocation lengths, profile header sizes and hashes, original loop preservation, and independent input hash calculation. No C# compilation or Windows execution, repository build, automated test suite, CI, main or runtime change. The missing native report is the remaining dependency for this experiment.


## PCS boundary capture: high-bit packing resolved, public transforms not composable

The supplied Pcs report (Windows build 26300.9974, SHA-256 `6ED9DA8D7FAB4A7F36DDAC4CAB40F17391FA633C19E3BFD6FBD5E1079E162465`) contains 57,355 input colors and 23 directed pairs. All 67 binary payloads passed length/hash validation: one input, seven synthetic profiles, 23 COLOR outputs, 13 bitmap outputs and 23 device links. All transforms and links succeeded and reported the Win CMM. The ten pairs involving XYZ device space returned native error 2017 from TranslateBitmapBits; their TranslateColors outputs and device links succeeded. Unsupported bitmap results are not counted as successful conversions. The previous matrix-only linear-sRGB to registered-sRGB and diagonal-to-diagonal control links retain identical input, CLUT and output tables.

### High-bit packing

TranslateColors reads/writes the first three COLOR words in logical channel order. On this capture's Win CMM, BM_16b_RGB bitmap input and output words instead have B,G,R order. The complete 32-cube and axis-sweep inputs (57,347 of the 57,355 colors per pair) admit an exact R/B-reversed input permutation. For each of the 13 RGB-to-RGB pairs, applying that permutation to the COLOR output and reversing the bitmap output words gives zero differing channels. Asymmetric matrix transforms distinguish this from identity and channel-permutation controls that by themselves cannot resolve a simultaneous input/output reversal. All marker words are still retained and hash-checked; the eight markers are not included in the symmetric-set packing comparison.

The existing precision diagnostic now normalizes 16-bit bitmap output words to RGB, and compares high-bit outputs only with outputs using the same input format (the prior 16-bit input bytes themselves were BGR). The older report's RGB10 outputs are exactly the high ten bits of the corrected RGB16 outputs, for all 24 source/intent/direct-or-replay/input-depth combinations (368,640 channel comparisons). The RGB8 path does not in general equal the high byte of RGB16; no new high-bit interpolation formula is claimed. All previous RGB8 replays remain exact.

### Independent PCS boundaries

The three identity paths (RGB-to-RGB, XYZ-to-RGB and RGB-to-XYZ) produce identical numeric tables and COLOR outputs to XYZ-to-XYZ. The seven forward/inverse bridge comparisons (three matrix sources and four matrix targets) likewise give exactly equal tables and COLOR outputs for the XYZ device profile and its RGB bridge. The ZYX controls give exact channel permutation of the expected forward output or inverse input axes, both in the measured COLOR data and in the CLUT. However, even the identity COLOR transform is not a numerical no-op: 116,693 channel values differ from the input by up to 12 raw 16-bit units; the identity CLUT differs from ideal normalized grid coordinates at 92,160 of 98,304 entries, by at most eight units.

Comparing the bridge CLUT rounded to the inferred Q13 PCS scale (round-half-up(raw XYZ / 4)) with the earlier inferred matrix-only lattice from the diagonal-target link:

| Source | Unclipped entries | Different entries | Max inferred lattice error |
| --- | ---: | ---: | ---: |
| Linear sRGB | 98,298 | 49,314 | 1 |
| Mixed | 98,299 | 50,493 | 1 |
| Diagonal | 93,184 | 38,912 | 1 |

This rejects identifying the bridge's measured grid directly with the previously inferred intermediate lattice. Neither the earlier inferred lattice nor the public bridge is a direct dump of the matrix-only CMM's internal PCS buffer.

A stronger composition counterexample uses exact measured XYZ axis inputs, without interpolation or a fitted matrix. For each diagonal-source axis input whose forward COLOR result is a multiple of four within the captured inverse-axis domain, compare its recorded inverse COLOR result to the direct diagonal-to-diagonal COLOR result. All off-axis components are zero.

| Axis | Exactly available inverse input | Different composed output | Max 16-bit difference |
| --- | ---: | ---: | ---: |
| X | 2,053 | 2,036 | 16 |
| Y | 2,191 | 2,172 | 18 |
| Z | 2,048 | 2,015 | 19 |

For example, RGB WORDs (0,260,0) produce PCS WORDs (0,128,0); the separately measured inverse gives (0,255,0), while the direct transform gives (0,258,0). Thus the public two-transform route introduces additional quantization even when an exact intermediate input is available. It cannot serve as an exact replacement for the matrix-only link, and adding a bridge profile to the theme would not solve independent CLUT generation.

The existing matrix-capture diagnostic now accepts an optional PCS report, reusing the previous verified matrix capture and the bounded binary decoder. The generic measured mft2 reader validates the expected color spaces, while RGB8 replay still accepts only RGB-to-RGB links. The new diagnostic reconstructs the input words, checks profile and payload hashes, preserves API failures, and reports the comparisons above without archiving or fitting captured tables.

```sh
python3 scripts/theme/analyze-wallpaper-icc-matrix-capture.py /path/to/windows-icc-matrix.json --target /path/to/sRGB.icm --pcs-report /path/to/windows-icc-pcs.json
```

Local static Python AST parsing and offline comparison of the actual supplied matrix, precision and PCS reports succeeded in a writable isolated reconstruction of the repository. The original matrix curve comparisons and six precision intent replays remain exact. No runtime changes, new dependencies, repository build, automated test suite, CI or main change. Next investigate the measured identity-link normalization and matrix-only sampling stages; the public bridge measurements are additional evidence, not an independently generated CLUT.


## Q15 normalization of the synthetic mft2 bridge curves

The three hash-verified synthetic PCS bridge profiles use unity two-point input/output tables in both A2B0 and B2A0. Unlike the previously measured matrix-profile TRCs, their generated device-link curves follow a distinct two-stage normalization. For each sample index i in a table of N entries, independently compute q = floor((2*i*32768 + N-1)/(2*(N-1))). The 16-bit exported value is floor((q*S + 16384)/32768), with the final entry set to 65535. Input uses N=256 and S=65534; output uses N=1024 and S=65535. These are integer operations, not stored native curve values. The 15 fractional bits refer to the intermediate normalization in this observed formula, not a proven precision for every CMM stage.

| Generated curve | Transform instances | Entries checked (including repeated tables) | Different entries |
| --- | ---: | ---: | ---: |
| Bridge input | 14 | 10,752 | 0 |
| Bridge output | 12 | 36,864 | 0 |

Input table SHA-256: `6C61F33985621A47ACF0628A58E168E4A1215FE3BE5369CDDE2E1F4A94919605`. Output table SHA-256: `4404EC04FB9473830A5F4F24502FF3144BF7ACD7DCE6629803F26BCE890DC517`. The existing PCS diagnostic now checks the two-point mft2 curve structure and regenerates these tables from the verified synthetic profiles, reporting errors and hashes separately. It does not extend this rule to arbitrary mft2 LUTs.

The three identity/permutation controls and three diagonal controls (diagonal-to-diagonal, diagonal-to-XYZ and XYZ-to-diagonal) have exactly axis-separable CLUTs after correcting the intentional ZYX permutation. Each complete native grid is reconstructed from its measured axis samples for this diagnostic. This is evidence of separability, not independent grid generation. No cross-channel leakage occurs in those six controls.

Extending the Q15 output formula directly to 32 equally spaced CLUT coordinates does not reproduce the identity CLUT: 92,160 of 98,304 entries differ, with an absolute error sum of 479,232 and maximum error of eight. A separate exploratory enumeration of up to five sequential integer normalization stages (scales 8191, 8192, 16383, 16384, 32767, 32768, 65534, 65535 and 65536; floor, half-up or ceil; deduplicated intermediate vectors) evaluated 197,153 full-range candidates on the 32-point identity axis, enforcing the full-scale endpoint. The best axis candidate differs at 19 of 32 entries, with a sum of 24 and maximum error of two. None is exact. This search is local exploratory work, not a committed generator or a proof that all staged normalization formulas fail.

A separate 16-bit axis replay sweep evaluated 222,720 combinations of input/output coordinate scaling, fraction precision and per-stage interpolation rounding, ranking against every fourth sample of the identity green-axis sweep. The leading candidate has 3,249 differing values among all 8,193 identity green-axis samples (maximum two). It does not establish exact RGB16 interpolation, and the independently verified RGB8 tetrahedral execution is unchanged. These exploratory sweeps are not required to reproduce the committed curve and separability diagnostics.

Local review: the baseline analyzer, precision, generation and engine Git blob hashes matched testing; the full analyzer diff was reviewed and Python AST parsing passed. Running the existing diagnostic on the actual matrix and PCS reports verified all 67 PCS payloads, the generated bridge curve results above, and all nine original matrix RGB8 replays. The separate existing precision diagnostic verified all six earlier 5,120-color intent replays. No runtime implementation, new dependency, build, automated project test suite, CI or main change. The complete matrix-only CLUT generation is still unresolved; the new bridge normalization must not be substituted for the verified matrix-profile TRC rules.


## Integer fixed14 candidate, full RGB8 domain, and wallpaper colorization impact

The existing generation diagnostic now reproduces the previously explored Q14-coordinate/Q14-source/Q13-PCS/Q16-inverse candidate using integer arithmetic: exact signed ICC 16.16 colorant codes, rounded integer grid coordinates, and the exact destination adjugate/determinant to construct the rounded inverse coefficients. The input/destination colorant range and inverse magnitude are bounded to keep NumPy integer products safe. This is the previous approximate model, not an identified native matrix algorithm. Its shared CLUT SHA-256 is `6D832C2353183C27AA6C5CE817DC2716D6011AF426025A6F2721A90F74CA79A7`, with the previous 61,369 differing entries, absolute error sum 508,403 and maximum 43 raw 16-bit units.

With exact matching input and output curves, the tetrahedral interpolation is a convex combination of the four vertices. A maximum difference of 43 is less than the 64 raw units per output-table index, so the two replays can differ by at most one output index. The largest adjacent difference in the registered sRGB table's high bytes is three. This gives a bound of three RGB8 units for these two measured profiles, independent of the selected color. It does not bound other profiles or native paths.

The optional full-domain comparison enumerates every RGB8 triple in ascending R/G/B order in 262,144-color batches, comparing the generated integer candidate against the portable replay of the captured native table. It is **not** a new native Windows capture over all RGB8 codes. The original calibration and mixed-color references still validate the replay on 5,120 observed colors per profile.

| Profile | Colors compared | Different colors | Different channels | Absolute error sum | Max channel error |
| --- | ---: | ---: | ---: | ---: | ---: |
| sRGB | 16,777,216 | 1,049,942 | 1,083,532 | 1,257,602 | 3 |
| Linear sRGB | 16,777,216 | 647,452 | 659,113 | 777,581 | 3 |

RGB8 error histograms (number of channel values with error 0, 1, 2, 3):

- sRGB: 49,248,116 / 954,755 / 83,484 / 45,293.
- Linear sRGB: 49,672,535 / 577,917 / 43,924 / 37,272.

The sRGB full-domain replay hashes are `F6A018561FE98663E3FAD255E1A1DD8B837B874A0C7CA212315A5CCD42388EAC` (candidate) and `FD5EEB3579A1F00177FF32350870FB4AB020A76E393B8FD3A432009E0FC0D86F` (native table). The linear sRGB hashes are `609632924A84E66B3D2D6BEB7AB08CD69FA027D05FB6CC2E17C417E6DEDA3300` and `89A60E70F2990F0AC205BB194D59E8074D41A5ED92CA25DF3183F058C3964349`. For example, the candidate transforms (0,3,231) to (0,0,231) rather than (0,3,231) on sRGB, and (0,1,182) to (0,12,220) rather than (0,9,220) on linear sRGB. These counterexamples demonstrate why matching an individual wallpaper's color does not establish exact ICC conversion.

The diagnostic also reconnects the CLUT comparison to the actual theme's colorization goal. It verifies all six archived DecodeProfile BGRX buffers, reconstructs both controlled opaque tagged source images, and compares the current runtime's Little CMS conversion, each independently generated CLUT candidate, and native-table replay using the existing 256x256 bitmap resampling, weighted seed and normalization functions. The two native-table replay cache hashes exactly match the archived transcoded caches.

| Method | sRGB different cache pixels / max channel error | Linear sRGB different cache pixels / max channel error |
| --- | ---: | ---: |
| Current runtime Little CMS | 55,098 / 3 | 55,405 / 4 |
| Direct matrix CLUT | 528 / 2 | 424 / 3 |
| Q13 candidate | 640 / 2 | 474 / 3 |
| Integer Q14 candidate | 369 / 1 | 322 / 1 |
| Native-table replay | 0 / 0 | 0 / 0 |

| Method | sRGB weighted seed / colorization ARGB | Linear sRGB weighted seed / colorization ARGB |
| --- | --- | --- |
| Recorded Windows colorization | Not measured / 0xAFD24444 | Not measured / 0xAFD44343 |
| Current runtime Little CMS | #DC2A2A / 0xAFD44343 | #ED6464 / 0xAFD44343 |
| Native-table replay | #DC2929 / 0xAFD24444 | #EE6464 / 0xAFD44343 |
| Each of the three independent candidates | #DC2929 / 0xAFD24444 | #EE6464 / 0xAFD44343 |

All three candidate grids reproduce the observed colorization ARGB on these two tagged synthetic wallpapers, despite differing from their cache pixels. The weighted seeds in this table are calculated by the theme, not independently reported by Windows. No arbitrary-wallpaper, independent profile-family, final shade-ramp, tagged-alpha or desktop acceptance claim follows. The full-domain counterexamples remain; do not install the candidate as an exact CMM or relax the acceptance requirement without approval.

Reproduce the cache/colorization comparison using the existing generation diagnostic; add the optional full-domain flag for the 33,554,432 combined replay comparisons:

```sh
python3 scripts/theme/analyze-wallpaper-icc-generation.py /path/to/windows-icc-precision.json --target /path/to/sRGB.icm --full-rgb8
```

Local review: baseline diagnostic blob hashes matched testing, the complete generation-script diff was reviewed, Python AST parsing passed, the integer CLUT metrics reproduced the previous candidate, and the full-domain enumeration and the extended cache/colorization analysis completed. The isolated research directory contains a reconstruction of the original cache report and the runtime functions relevant to these measurements, including the existing ICC conversion, weighting and normalization; the observed ARGB values were read from the exact repository archive. It is not a full repository checkout. The full-domain enumeration was run before adding the downstream cache colorization metrics; those additions were checked in a separate normal diagnostic execution. No new runtime dependencies, runtime/cache revision change, build, automated project test suite, CI or main change.


## Downstream seven-role palette comparison

The existing generation diagnostic now compares the entire calculated seven-role UISettings ramp against each archived DecodeProfile observation, not only the colorization ARGB. It also reports the two theme mode accents separately. Native replay and all three independent CLUT candidates match all seven roles on both measured tagged images. The existing Little CMS path differs on all seven sRGB roles and both mode accents, but matches all seven linear-sRGB roles.

| Profile | Native dark-mode role | Native light-mode role | Current Little CMS matching roles | Integer Q14 matching roles |
| --- | --- | --- | ---: | ---: |
| sRGB | #EC968E | #BB2D2D | 0/7 | 7/7 |
| Linear sRGB | #ED958D | #BE2B2B | 7/7 | 7/7 |

The diagnostic ran on the actual precision report and the isolated cache reconstruction, with the seven-role observations transcribed from the exact repository archive and the relevant existing runtime shade functions. Its Python source passed AST parsing. This is not a full repository checkout or a desktop acceptance test. The first local invocation exposed missing appearance fields in the minimal local archive reconstruction; after including those recorded fields, the comparison completed. The source archive already contains those fields and does not need a modification. The full-domain differences and arbitrary-profile limits from the previous section remain; no approximate ICC candidate is installed. The related runtime synchronization changes are independent of this ICC investigation and do not change the analysis algorithm revision.


## Private measured RGB8 replay in the runtime

The supplied precision report was reopened from the owner's original file.
Its raw SHA-256 matches the earlier report identity. The relative-colorimetric
device links have SHA-256 values
2E9CF49200C44791A7F70EBEF00A889E1EADABC8E992B5350CF1EE0CB1FAB1CD
and
97E8FB0C2828CEB25B993BB6F6D2EA8967C292C86D843187CD9F01951F93FE36
for the measured sRGB and linear-sRGB source profiles, respectively.

The new local-only importer extracts those two exact links, verifies their
sizes, hashes and RGB mft2 shape, compares the scalar replay with all
10240 recorded RGB8 outputs before permitting installation, and publishes a 410408-byte private data
file with SHA-256 CDB09ED87EFC0B147BA64E705E2343CAC1C6E37828AC97B424937CE7B51DA6D2.
No native profile, device link or report payload is committed or packaged.

```sh
python3 -I scripts/theme/wallpaper-icc.py --import-report /path/to/windows-icc-precision.json
```

The installed helper is also shipped in the unified look-and-feel's
contents/scripts directory. The private data lives at
$XDG_DATA_HOME/windows-modern/icc-replay-v1.bin (normally
~/.local/share/windows-modern/icc-replay-v1.bin). The existing wallpaper
watcher observes its file and parent. The existing appearance sync command
can refresh the current selection explicitly after importing. Removing the
file returns to the previous color-managed baseline. The saved accent and
material caches distinguish the two decoder paths (analysis revision 3).

Only the exact two measured source ICC SHA-256 identities select the
native RGB8 replay; arbitrary profiles still use Little CMS. The scalar
replay uses the same 5-bit grid, 11-bit fractions, tetrahedral weights and
final output-curve truncation as the existing independent diagnostic.
Conversion is pointwise and precedes resizing: only the at most four
source taps per output pixel are converted, with a bounded color cache.
This avoids a new NumPy runtime dependency and full-image native replay.
The existing tagged-alpha restrictions remain in place.

This local reference path is an intermediate use of the verified
measurements, not independent matrix/CLUT generation. The original
native replays were verified by the earlier diagnostics; the new runtime
implementation and regression definitions have not been executed.
Unknown ICC profiles, tagged alpha, general native table generation and
live same-style Kvantum reloading remain open.

Global scheme publication now checks all twelve RGB roles in each of
the six owned Colors groups and all six WM roles in one local kdeglobals
snapshot, in addition to the KDE scheme hash. This follows Plasma 6.8.3's
colorsapplicator transparent-accent copy path. Explicit wallpaper input
and decoder identity are rechecked at publication; automatic and material
cache entries include the local replay reference identity.

## Full native RGB8-domain and combined alpha/profile diagnostics

The original 5,120-color precision protocol remains available unchanged in
schema 1. The opt-in schema 2 collection measures the WIC BGR24 transform
over the entire RGB8 input domain (16,777,216 colors per source), in a
4096 x 4096 synthetic image ordered by ascending packed RGB. It records
the output SHA-256 and 256 individual red-slice hashes rather than the
50,331,648-byte output. The registered sRGB target and reference build
checks remain mandatory. The two original synthetic profiles are controls;
up to four explicitly supplied local RGB ICC profiles may be included.
Only profile identities, diagnostic transforms and output evidence are
recorded, not the input profile bytes or their paths. Keep reports with
native device-link payloads private. The new default output name preserves
the earlier precision report.

Run in Windows PowerShell on the reference VM:

```powershell
.\capture-windows-icc-precision.ps1 -FullRgb8
```

Optional additional RGB ICC files use the `-SourceProfile` argument.
The existing Linux precision analyzer recognizes schema 2, preserves the
schema 1 control comparisons, and hashes a portable relative-colorimetric
RGB8 replay in the same order. It reports differing red slices and
unsupported link shapes rather than silently changing the runtime
interpolator. A hash match would establish equivalence of the two
measured outputs for that exact source, destination, format and build;
it would not establish independent CLUT generation or alpha handling.

```sh
python3 scripts/theme/analyze-wallpaper-icc-precision.py /path/to/windows-icc-full-rgb8.json
```

The existing wallpaper collector also has a combined DecodeAlphaProfile
probe set: the two alpha levels (1 and 128), alpha gradients, and mixed
opaque/transparent rows under each of the three existing profile controls.
This must be collected on the single-display 1280x800 Windows reference VM
with a static Picture background and Automatic accent mode. Use the same
folder for the two wallpaper/accent collectors:

```powershell
.\capture-windows-wallpaper-probes.ps1 -ApplyTemporarily -ProbeSet DecodeAlphaProfile -IncludeNativeWallpaperColor
```

The extended offline ICC analyzer reconstructs the six synthetic RGBA
sources, validates the raw BGRA and analysis-buffer identities, and
compares their observed source and transcoded cache buffers. It tests
three candidate sequences: straight RGB conversion before premultiplication
and scaling; a premultiplication round trip before conversion and scaling;
and straight RGB conversion after scaling. RGB and marker differences
are reported separately. The existing private precision report supplies
the verified RGB8 link tables without installing them or modifying the
source images. The analyzer compares both the complete pipeline's
colorization and seven palette roles and the shades calculated directly
from the observed native colorization RGB. Thus decoder differences are
distinguished from shade-generation differences.

```sh
python3 scripts/theme/analyze-wallpaper-icc.py --alpha-report /path/to/wallpaper-probes.json --precision-report /path/to/windows-icc-precision.json
```

These are reference-analysis tools only. The full-domain capture,
combined alpha/profile results and new shade-boundary observations have
not been collected or verified in this change. The installed decoder,
private bundle format, cache revision and palette algorithm are unchanged.
No approximate native conversion or inferred alpha ordering is enabled.

## Opt-in full-domain native RGB8 replay import

A second private receipt format extends the runtime to additional exact
source ICC hashes without distributing native tables or independently
generating an approximate CLUT. Import requires a schema 2 report from
the reference build and registered destination profile, matching the
previous 5,120-color control measurements. The selected source link must
have the reviewed RGB-to-RGB mft2 shape (three channels, 32-point grid,
256/1024-entry curves and identity matrix). The scalar implementation
used at runtime must match the captured 5,120 RGB8 samples, all 256
red-slice hashes and the complete native RGB8 output hash before the
receipt is published. The owner's local report is trusted as measurement
input; its hashes are integrity checks, not Microsoft signatures.

```sh
python3 -I scripts/theme/wallpaper-icc.py --import-full-report /path/to/windows-icc-full-rgb8.json
```

Optional repeatable `--profile-sha256` values select individual source
profiles. The exhaustive scalar comparison runs once at explicit import,
not during wallpaper updates; it processes one red slice at a time and
does not require NumPy. A mismatch or unsupported link layout refuses
publication. The receipt stores only the verified fixed-size tables and
source/output identities in `icc-replay-v2.bin` beside the existing local
v1 bundle, with a bounded size and a checksum over the entire receipt.
It is published atomically without overwriting a different existing
receipt. To replace a receipt, the owner must explicitly remove the old
v2 file before importing another. The v1 importer and file are preserved.
When both exist, a fully verified v2 entry takes precedence for its exact
source hash; v1 retains its previous behavior for the remaining controls.

The existing wallpaper watcher observes both local files and their
parent directory; it also observes the data directory until the parent
exists. Either receipt changing or disappearing changes the shared cache
identity. Untagged images and unmeasured ICC profiles retain the existing
paths. No new service, runtime dependency or independent light/dark
palette is introduced. This supports measured RGB8 links only, not
arbitrary ICC generation, other table geometries or tagged transparency.
The new full-domain import has not been exercised against native schema
2 data; the added regression definition concerns receipt integrity,
profile selection and cache invalidation, not native parity.

## Deterministic seven-role shade arithmetic and alpha evidence boundaries

The final byte-domain blend in the candidate CIELAB palette uses nominal
integer percentages and half-up rounding. For example, the 58% blend of
byte values 0 and 25 is exactly 14.5 and rounds to 15; a binary floating
point product can fall just below the half-integer. Saturation restoration
now scales the exact mixed RGB chroma at its unchanged HSL lightness and
hue. If saturation is already sufficient, retain the mixed bytes rather
than doing an unnecessary floating-point round trip. The hue-zero
convention for achromatic mixed RGB is unchanged. The LAB conversion,
seven weights, provisional 15% branch threshold, manual presets and
legacy HSL branch remain unchanged.

An independent numerical transcription of the old and proposed byte
arithmetic was compared with the existing archives. Among 118 eligible
automatic sample observations (source and registered image identities
matched, with native API or recorded registry colorization evidence),
114 selected the chromatic candidate branch. Together with the
conditionally identified manual purple input, these are 115 observations
of 46 distinct chromatic RGB inputs. Both calculations match all seven
observed roles for those inputs. The nominal exact arithmetic resolves
implementation-dependent half-integer errors; it is not proof of native
Windows rounding at unmeasured boundaries. The other four automatic
observations were outside that comparison. Existing automatic cache
revision is incremented to 4, so the next normal sync recomputes its
palette. The shared material cache will also be refreshed once. Saved
explicit manual and fixed-wallpaper ramps remain selected until the
owner explicitly reselects them.

The existing regression definitions now cover representative formula
boundaries and normalize the compact Refinement archive's RGB spelling
before comparison. The archived baseline has no preceding-probe fields;
only actual probe samples assert those fields. No reference fixture data
is changed. The combined ICC/alpha analyzer separately checks changed
cache identity and baseline isolation. It retains pixel comparisons but
labels native colorization inconclusive when the native ARGB did not
change or the observation was not settled. This prevents a stale palette
from being used as evidence of conversion ordering. No new Windows
alpha observations or exact ICC generation have been obtained.

## Independent per-channel curve generation and full-domain comparison

The offline generation diagnostic now accepts individual red, green and
blue tone curves. Alongside the previously verified shared parametric
and v2 unity-gamma controls, it evaluates ICC curveType identity, gamma
and sampled tables and parametricCurveType functions 0 through 4.
Additional forms apply the existing four-code anchor construction as a
candidate, not a confirmed native sampling rule. The original controls
retain their previous reciprocal, power and rounding order. This does
not change the installed decoder.

To distinguish input-curve differences from matrix precision, the
existing precision collector offers two optional synthetic profiles with
the exact colorants of the earlier source-v2 matrix control. The first
has separate red gamma (563/256), green sampled (33 points) and blue
unity TRCs; the second uses the same red gamma for all three channels.
Their hashes and synthetic bytes are checked and included in the
report. Real user-supplied profiles remain local and are identified
only by hash. No actual display profile is exported or installed.

Run once in Windows PowerShell:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\capture-windows-icc-precision.ps1 -FullRgb8 -CurveProfiles
```

The existing generation diagnostic accepts that schema 2 report and
optional local source ICC files (repeat `--source-profile` for each).
For each reviewed matrix/TRC profile, it compares the independently
generated input curves, CLUT and destination curves individually and
reports their combined RGB8 errors against the native calibration and
mixed inputs. With `--full-rgb8`, it also compares the generated
transform against the actual native full-domain and red-slice hashes,
not only against the portable replay of a measured link.

```sh
python3 scripts/theme/analyze-wallpaper-icc-generation.py /path/to/windows-icc-full-rgb8.json --target /path/to/sRGB.icm --full-rgb8
```

The previously measured matrix report was reopened locally and its
SHA-256 matched 8D746E6AD1BD358F46245612B4D824A098BF8304C664535A95B36D2C2D97B55A.
Its diagonal controls still show nonuniform integer residuals (for the
green scalar map, output minus eight times inferred PCS ranges from
-2 to 0). These observations do not establish a complete matrix
formula. The new synthetic profile payloads were constructed from
the verified mathematical source-v2 control and their ICC tag
lengths and SHA-256 identities checked during construction. They
have not yet been accepted or measured by Windows. Schema 2 native
output and combined DecodeAlphaProfile evidence are still required.
No runtime approximation, native table payload, additional runtime
dependency or separate theme is introduced.

## Measured full-domain replay and sampled RGB8 source curve

The owner supplied the schema 2 full RGB8 report from Windows build
26300.9974, SHA-256
25D40E5C3CE78C0A3715BC38D1FC41777B60F83D2D6BAD46D3E4138BF53636CB.
All 163 embedded binary payloads passed length and SHA-256 checks. The
four WIC full-domain measurements are complete. A local numerical
transcription of the existing vectorized tetrahedral replay reproduced
all 16,777,216 RGB8 outputs per source, with identical whole-stream
SHA-256 and all 256 red-slice hashes. All four 5,120-color calibration
and mixed comparisons were exact. Each source's three intent links have
byte-identical A2B0 tags (but different complete profile hashes).
Thus the full-domain check covers four unique sets of conversion tables,
or 67,108,864 source/color pairs, not twelve independent WIC measurements.
All four sources also have identical CLUT and output-curve tables.

The new shared gamma (563/256) input matched all 768 source entries.
The independent-channel profile's red gamma and blue unity matched
all 512 entries. The previous four-code anchor candidate for its
33-point green sampled curve differed at 167 of 256 entries, with a
maximum difference of 10 uint16 units and two mismatching RGB8 colors
in the 5,120-input comparison using native CLUT/output tables.

The observed sampled-curve result is reproduced by a separate candidate
integer interpolation, where x is an RGB8 code, N is the ICC sample
count and S is its uint16 sample array:

    p = x * 257 * (N - 1)
    i = p >> 16
    f = p & 65535
    d = ((S[i + 1] - S[i]) >> 1) << 1
    result = S[i] + ((d * f + 32767) >> 16)

This differs from the analytic four-code anchor scheme: truncate the
slope to even integer units, interpolate in Q16 and round an exact
half down. The 33-point control reproduces every input-curve entry,
including x=224 (51900) and x=255 (65533). The generator now uses this
candidate for sampled source curves and reports per-channel differences.
Combined with the native CLUT and output curves, matching all source
entries implies identical replay for every RGB8 input in this control.
No additional native measurement for other sampled curve sizes or
parametric families has established their exact CMM behavior.

The report does not establish independent CLUT generation. In particular,
using the observed native grid to isolate source curves must not be
counted as a fully generated transform. The new sampled interpolation
remains in the offline diagnostic, not the installed runtime. The
owner's raw capture and device-link data remain private. Tagged alpha
ordering still requires the separate DecodeAlphaProfile capture.

## Full-domain generated-matrix errors for the new curve controls

The exact registered destination profile was obtained again from the
previously recorded public reference, and its local SHA-256 matches
the schema 2 report. The independent source-curve and destination-curve
formulas reproduce all 768 input and 3,072 output entries for each of
the two new synthetic profiles. The same approximate Q14 matrix model
as before still differs at 61,369 of 98,304 CLUT entries (absolute error
sum 508,403, maximum 43). The full-domain difference is therefore
isolated to matrix construction in these controls.

Local offline numerical comparison of the two generated transforms
against their measured-table replays checked each reference red-slice
hash and the complete native WIC hash before attributing numerical
differences to native output:

| Source control | Different RGB8 colors | Different channels | Absolute error sum | Max RGB8 error |
| --- | ---: | ---: | ---: | ---: |
| Independent R/G/B curves | 867,771 | 887,367 | 1,058,993 | 3 |
| Shared gamma | 856,198 | 874,338 | 970,009 | 3 |

Each denominator is 16,777,216 colors; both generated output streams
differ from all 256 native red-slice hashes. These additional input
curves do not eliminate the CLUT errors. No candidate matrix formula
is promoted to the installed theme.

The existing precision analyzer now applies the same binary and format
validation to custom source profiles as to the original controls,
including every successful direct and link-replay output at all three
rendering intents and six bitmap-format combinations. Embedded
synthetic profile identity is checked independently. Unsupported
custom link geometry is reported without discarding its native
precision measurements. For each source only one full-domain WIC
measurement exists; other intent links are listed as equivalent only
when all three conversion-table hashes match.

The existing generation analyzer's optional full-domain comparison
now reports exact differing-color and channel counts, the RGB8 error
histogram, maximum error and a witness, rather than only the generated
output hash. These numerical errors are identified with native WIC
only if the reference replay matches all actual native hashes.
Otherwise the analyzer retains the generated hash comparison without
mislabeling portable-reference errors as native errors. The schema 1
diagnostic retains its original portable-versus-portable comparison.
No private ICC payload or new runtime dependency is included.

The numerical comparison above is an isolated analysis of the owner's
supplied data and the recorded exact destination profile, using a
transcription of the existing formulas. It is not a run of the
modified repository analyzer, a build, or desktop acceptance. Exact
independent CLUT construction, native tagged-alpha ordering and other
curve families remain unresolved.

## Reusing the full-domain report for combined alpha evidence

The current schema 2 report and the earlier schema 1 control links have
different complete ICC device-link hashes but identical conversion
tables. The two combined table hashes (big-endian input curves, CLUT,
output curves, in that order) are:

- sRGB: 97E7346083017BD0E85A33FF4A95B2B358494328EE144C5C1DCCD4551452B283
- Linear sRGB: DFA3F6063DDC61DCDB6D9A221F4BC837377F741EA6DA168B539316824821790D

These were calculated from the owner's actual full-domain report and
checked against the previously documented individual table hashes.
Consequently the alpha diagnostic accepts the new full-domain report
as well as the older precision capture. It checks the original source
and destination identities, known full-domain hashes, exact table
identity and the scalar 5,120-color calibration/mixed comparison for
each control. It does not repeat the exhaustive import or write an
ICC receipt. The full-domain hashes identify previously reviewed
measurements; they are not a new exhaustive scalar comparison.

The WIC collector already records a SHA-256 of the full decoded BGRA
cache frame, when available. The alpha analyzer now compares it with
the original frame, a premultiply/unpremultiply round trip, straight
RGB conversion (both with and without hidden RGB at alpha zero), and
the two orders of conversion and premultiplication round trip.
These are separate candidate frame identities; the original 256x256
buffer and native palette comparisons remain. A matching frame hash
can locate the boundary before resampling; it cannot by itself prove
the native path for other formats. A missing or unmatched frame hash
is not silently treated as an exact conversion.

For the next collection use the existing wallpaper probe script
with the DecodeAlphaProfile option and the accompanying accent
collector. No updated Windows script or repeat of the complete
RGB8 capture is needed.

```sh
python3 scripts/theme/analyze-wallpaper-icc.py --alpha-report /path/to/wallpaper-probes.json --precision-report /path/to/windows-icc-full-rgb8.json
```

The matrix report was reopened and its original SHA-256 reproduced.
In a numerical examination of the diagonal-target grid, using twice
the inferred green-axis PCS codes in place of the approximate Q14
coordinates eliminated the green-axis error in the diagonal control,
but increased the total inferred-lattice errors for the linear-sRGB
and mixed source controls. This does not establish independent grid
generation. The measured green-axis output is not a portable
coordinate formula. No matrix approximation or tagged-alpha path
enters the runtime in this change. The separate combined alpha
capture is still outstanding.
