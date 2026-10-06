"""Generates the procedural weather and near-miss sounds for Courier Dash.

These three sounds are synthesized, not sampled, so they carry no third-party
licence and can be re-tuned by editing the numbers here:

  assets/audio/sfx/rain_ambience.ogg   seamless rain loop
  assets/audio/sfx/thunder.ogg         one thunderclap with a rolling tail
  assets/audio/sfx/bark_near_miss.ogg  short whoosh for a near-miss stunt
  assets/audio/music/courier_groove_layer.ogg   streak arp over the day track
  assets/audio/music/courier_night_layer.ogg    streak arp over the night track

Requires Python 3 with numpy, and ffmpeg (with libvorbis) on PATH.

    python tool/generate_audio.py

Output is deterministic: every random stream is seeded.
"""

import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

RATE = 44100
OUT_DIR = os.path.join("assets", "audio", "sfx")
MUSIC_DIR = os.path.join("assets", "audio", "music")

# The streak layers ride on top of the two music tracks, so they hold exactly
# as many samples as those tracks (read from their Ogg headers). Started
# together with the BGM they re-align on every repeat and never drift.
GROOVE_SAMPLES = 354564  # courier_groove.ogg: 8.04 s
NIGHT_SAMPLES = 474075  # courier_night.ogg: 10.75 s


def db(level):
    return 10.0 ** (level / 20.0)


def shaped_noise(n, shape, rng):
    """Noise whose spectrum follows shape(freq_hz).

    Built in the frequency domain, so the result is periodic over its own
    length: played on a loop it has no seam.
    """
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    spectrum = shape(freqs) * np.exp(2j * np.pi * rng.random(len(freqs)))
    spectrum[0] = 0.0
    return np.fft.irfft(spectrum, n)


def band(freqs, low, high, order=2):
    """Smooth band-pass magnitude: rolls off below low and above high."""
    f = np.maximum(freqs, 1e-6)
    highpass = 1.0 / np.sqrt(1.0 + (low / f) ** (2 * order))
    lowpass = 1.0 / np.sqrt(1.0 + (f / high) ** (2 * order))
    return highpass * lowpass


def normalize_rms(x, level_db):
    return x * (db(level_db) / np.sqrt(np.mean(x ** 2)))


def normalize_peak(x, level_db):
    return x * (db(level_db) / np.max(np.abs(x)))


def rain():
    """Eight seconds of steady rain that loops without a seam."""
    seconds = 8.0
    n = int(seconds * RATE)
    rng = np.random.default_rng(27)
    t = np.arange(n) / RATE

    def hiss(freqs):
        # Broad hiss, tilted so the top end is soft rather than harsh.
        tilt = np.where(freqs > 900.0, (900.0 / np.maximum(freqs, 1.0)) ** 0.8, 1.0)
        return band(freqs, 300.0, 7000.0) * tilt

    def body(freqs):
        return band(freqs, 60.0, 260.0)

    shared = shaped_noise(n, hiss, rng)
    channels = []
    for side in range(2):
        own = shaped_noise(n, hiss, rng)
        low = shaped_noise(n, body, rng)
        mix = 0.45 * shared + 0.55 * own
        mix = mix / np.sqrt(np.mean(mix ** 2))
        mix = mix + 0.22 * low / np.sqrt(np.mean(low ** 2))

        # Gusts: whole cycles per loop, so the swell also wraps cleanly.
        gust = (1.0
                + 0.10 * np.sin(2 * np.pi * 3 * t / seconds + 0.7 + side)
                + 0.06 * np.sin(2 * np.pi * 7 * t / seconds + 2.1 - side))
        mix = mix * gust

        # Patter: a few hundred single drops landing close by.
        drops = np.zeros(n)
        for _ in range(300):
            start = int(rng.integers(0, n))
            length = int(rng.integers(int(0.004 * RATE), int(0.012 * RATE)))
            tick = rng.standard_normal(length) * np.exp(-np.arange(length) / (length / 4.0))
            # Smoothed, then differenced: a soft tick, neither hiss nor thud.
            tick = np.convolve(tick, np.ones(6) / 6.0, mode="same")
            tick = np.diff(tick, prepend=0.0)
            gain = db(float(rng.uniform(-6.0, 4.0)))
            index = (start + np.arange(length)) % n  # wraps round the loop
            drops[index] += gain * tick
        mix = mix + 0.9 * drops
        channels.append(mix)

    stereo = np.stack(channels, axis=1)
    stereo = normalize_rms(stereo, -19.0)
    return np.clip(stereo, -db(-1.0), db(-1.0))


def thunder():
    """A clap followed by a rumble that rolls away over about three seconds."""
    seconds = 3.2
    n = int(seconds * RATE)
    rng = np.random.default_rng(63)
    t = np.arange(n) / RATE

    def rumble(freqs):
        # Low and heavy, but with enough above 200 Hz to exist on a phone.
        tilt = (120.0 / np.maximum(freqs, 120.0)) ** 0.9
        return band(freqs, 35.0, 900.0) * tilt

    def crack(freqs):
        return band(freqs, 250.0, 3500.0)

    channels = []
    for side in range(2):
        low = shaped_noise(n, rumble, rng)
        low = low / np.max(np.abs(low))
        # The roll: a fast swell, then decay with two fading after-rolls.
        swell = 1.0 - np.exp(-t / 0.035)
        decay = np.exp(-t / 0.95)
        rolls = 1.0 + 0.55 * np.sin(2 * np.pi * 1.15 * t + 0.4 + 0.3 * side) * np.exp(-t / 1.6)
        low = low * swell * decay * rolls

        high = shaped_noise(n, crack, rng)
        high = high / np.max(np.abs(high))
        clap = high * np.exp(-t / 0.11) * (1.0 - np.exp(-t / 0.002))

        channels.append(low + 0.55 * clap)

    stereo = np.stack(channels, axis=1)
    # End on silence so the tail does not click off.
    fade = int(0.45 * RATE)
    stereo[-fade:] *= np.linspace(1.0, 0.0, fade)[:, None] ** 2
    return normalize_peak(stereo, -2.0)


def whoosh():
    """A quick pass-by swish: noise swept up and back down."""
    seconds = 0.30
    n = int(seconds * RATE)
    rng = np.random.default_rng(48)
    progress = np.arange(n) / n

    # Centre frequency rises to a peak just before the middle, then falls.
    centre = 350.0 + 1550.0 * np.sin(np.pi * np.minimum(progress / 0.45, 1.0) / 2.0) ** 2
    centre = np.where(progress > 0.45,
                      1900.0 - 1250.0 * (np.maximum(progress - 0.45, 0.0) / 0.55) ** 1.5,
                      centre)
    envelope = np.sin(np.pi * progress) ** 2

    channels = []
    for side in range(2):
        # Pink-ish source, so the swish is air rather than hiss.
        noise = shaped_noise(n, lambda f: (200.0 / np.maximum(f, 200.0)) ** 0.5, rng)
        noise = noise / np.max(np.abs(noise))
        # Two state-variable band-passes in a row, centre frequency moving.
        out = noise
        for _ in range(2):
            source = out
            out = np.zeros(n)
            low = 0.0
            bandpass = 0.0
            damping = 0.7
            for i in range(n):
                f = 2.0 * np.sin(np.pi * centre[i] / RATE)
                high = source[i] - low - damping * bandpass
                bandpass += f * high
                low += f * bandpass
                out[i] = bandpass
        # The swish passes left to right.
        pan = progress if side == 1 else 1.0 - progress
        channels.append(out * envelope * (0.55 + 0.45 * pan))

    return normalize_peak(np.stack(channels, axis=1), -5.0)


def streak_layer(total, steps, seed, pattern, root_hz, decay, harmonics, hat_level):
    """A high-tempo arpeggio that loops seamlessly over exactly `total` samples.

    `steps` must divide `total`: every note lands on a fixed grid, every tone
    is built from whole cycles across the loop, and every envelope wraps round
    the seam like the rain patter's drops do — so the layer has no click and
    stays sample-locked to the track it rides. Plays while a stunt streak of
    three or more is live (issue #63).
    """
    assert total % steps == 0, "the note grid must divide the loop exactly"
    n = total
    rng = np.random.default_rng(seed)
    step_len = n // steps
    left = np.zeros(n)
    right = np.zeros(n)

    for s in range(steps):
        semitones = pattern[s % len(pattern)]
        start = int(s * step_len)
        # Alternating placement throws the arp across the stereo field.
        pan = 0.75 if s % 2 == 0 else 0.25

        f = root_hz * 2.0 ** (semitones / 12.0)
        # Whole cycles across the loop: the nearest pitch that wraps silently.
        cycles = max(1, int(round(f * n / RATE)))
        phase = rng.random() * 2.0 * np.pi

        window = min(n, int(decay * 7.0 * RATE))
        i = np.arange(window)
        tone = np.zeros(window)
        for h, gain in enumerate(harmonics, start=1):
            tone += gain * np.sin(2 * np.pi * cycles * h * i / n + phase)
        env = (1.0 - np.exp(-i / (0.004 * RATE))) * np.exp(-i / (decay * RATE))

        index = (start + i) % n
        amp = 0.55 + 0.45 * rng.random()
        left[index] += amp * (1.0 - pan) * tone * env
        right[index] += amp * pan * tone * env

    if hat_level > 0.0:
        # One sizzle every four notes, off the beat, cut from one full-loop
        # periodic noise bed so it too wraps without a seam.
        def sizzle(freqs):
            return band(freqs, 5000.0, 11000.0)

        hats = shaped_noise(n, sizzle, rng)
        hats = hats / np.sqrt(np.mean(hats ** 2))
        burst = int(0.03 * RATE)
        bi = np.arange(burst)
        hat_env = np.exp(-bi / (0.006 * RATE))
        for s in range(steps):
            if s % 4 != 2:
                continue
            index = (int(s * step_len) + bi) % n
            gain = (0.7 + 0.3 * rng.random()) * hat_level
            left[index] += gain * 0.6 * hats[index] * hat_env
            right[index] += gain * 0.4 * hats[index] * hat_env

    stereo = np.stack([left, right], axis=1)
    return normalize_peak(stereo, -9.0)


def groove_streak_layer():
    """A fast A-minor-pentatonic arp for the day track: the streak sound."""
    return streak_layer(
        GROOVE_SAMPLES,
        steps=108,
        seed=73,
        pattern=[0, 3, 7, 10, 12, 10, 7, 3],
        root_hz=440.0,
        decay=0.09,
        harmonics=[1.0, 0.45, 0.25, 0.12],
        hat_level=0.35,
    )


def night_streak_layer():
    """The same arp, tuned softer to sit under the mellow night track."""
    return streak_layer(
        NIGHT_SAMPLES,
        steps=75,
        seed=91,
        pattern=[0, 3, 7, 10, 12, 10, 7, 3],
        root_hz=293.66,
        decay=0.14,
        harmonics=[1.0, 0.30, 0.15],
        hat_level=0.15,
    )


def write_ogg(name, samples, quality, out_dir=None):
    path = os.path.join(out_dir or OUT_DIR, name)
    pcm = np.int16(np.clip(samples, -1.0, 1.0) * 32767.0)
    with tempfile.TemporaryDirectory() as scratch:
        wav_path = os.path.join(scratch, "sound.wav")
        with wave.open(wav_path, "wb") as wav:
            wav.setnchannels(pcm.shape[1])
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-i", wav_path,
                "-c:a", "libvorbis", "-q:a", str(quality),
                # Keep the files byte-stable from run to run.
                "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
                "-serial_offset", "1",
                path,
            ],
            check=True,
        )
    seconds = len(samples) / RATE
    peak = 20 * np.log10(np.max(np.abs(samples)))
    rms = 10 * np.log10(np.mean(samples ** 2))
    print(f"{path}: {seconds:.2f} s, peak {peak:.1f} dBFS, rms {rms:.1f} dBFS, "
          f"{os.path.getsize(path) / 1024:.0f} KB")


def main():
    if not os.path.isdir(OUT_DIR):
        sys.exit(f"Run from the repository root: {OUT_DIR} not found")
    if not os.path.isdir(MUSIC_DIR):
        sys.exit(f"Run from the repository root: {MUSIC_DIR} not found")
    write_ogg("rain_ambience.ogg", rain(), quality=3)
    write_ogg("thunder.ogg", thunder(), quality=4)
    write_ogg("bark_near_miss.ogg", whoosh(), quality=4)
    write_ogg("courier_groove_layer.ogg", groove_streak_layer(), quality=3, out_dir=MUSIC_DIR)
    write_ogg("courier_night_layer.ogg", night_streak_layer(), quality=3, out_dir=MUSIC_DIR)


if __name__ == "__main__":
    main()
