Voice Guardian assets — what is still in the APK, and what is not (2026-10-01):

    silero_vad.tflite 650 KB   "is this human speech?" gate — Silero VAD v4, driven
                               frame-by-frame with its LSTM state (see SpeechGate.kt)
    models.json        1 KB    a copy of the server manifest, so Settings can list the
                               models (labels, sizes, notes) while offline. Hashes used
                               for verification always come from the SERVER copy.

Since 5.2.36 (2026-10-21) the app offers only "Powerful"; a Light pick or Light profiles move
to it (GuardianModels.offered). The server still lists both, for older app versions.

The speaker models are NOT bundled any more. Both are downloaded from
    https://getmaya.online/models/guardian/manifest.json
         (files: rdn2b6s.tflite + cohort_rdn2b6s.bin  — "Powerful", ReDimNet2-B6, 3 s window
                 ecapa6s.tflite + cohort.bin          — "Medium",   ECAPA-TDNN,   6 s window)
into filesDir/guardian_models/<id>/ by voice/guardian/GuardianModelStore (sha256-verified,
.part + rename, a `.ok` marker only once both files are good). The user picks one under
Settings → Voice Guardian → Recognition model (GuardianModelPrefs); a phone with existing
profiles keeps the model they were enrolled with, a fresh phone gets Powerful unless it
is low on RAM. The ids `rdn2b6s` / `ecapa6s` are a wire format: every profile stores the
id of the model its voiceprints were made with. Never rename them.

On the server: /var/www/maya/models/guardian/ on newvps, served by nginx at /models/
(immutable cache headers, so a re-converted model gets a NEW file name and a manifest edit).

Why: the two graphs were 69 MB of a 95 MB APK for a feature most phones never switch on,
and a phone only ever runs one of them.

Window notes (ECAPA, kept from the original README): the 6 s window is filled with
CONCATENATED VOICED AUDIO — never wall-clock audio, never zero-padded. Measured at 5 dB
SNR on LibriSpeech: 6 s contiguous 1.35% EER; 6 s holding only 2 s of speech 17.14%;
1.5 s zero-padded to 6 s 30.00%; 1.5 s repeated to fill 6 s 1.43%.
