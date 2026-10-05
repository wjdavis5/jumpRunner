"""Generates the procedural weather and near-miss sounds for Courier Dash.

These three sounds are synthesized, not sampled, so they carry no third-party
licence and can be re-tuned by editing the numbers here:

  assets/audio/sfx/rain_ambience.ogg   seamless rain loop
  assets/audio/sfx/thunder.ogg         one thunderclap with a rolling tail
  assets/audio/sfx/bark_near_miss.ogg  short whoosh for a near-miss stunt

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


def write_ogg(name, samples, quality):
    path = os.path.join(OUT_DIR, name)
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
    write_ogg("rain_ambience.ogg", rain(), quality=3)
    write_ogg("thunder.ogg", thunder(), quality=4)
    write_ogg("bark_near_miss.ogg", whoosh(), quality=4)


if __name__ == "__main__":
    main()
