import numpy as np
from scipy.io.wavfile import write

# Parameters
sample_rate = 44100  # Hz
duration = 0.4  # seconds (longer for more impact)
frequency = 300  # Hz (higher frequency - better for phone speakers)

# Generate time array
t = np.linspace(0, duration, int(sample_rate * duration), False)

# Generate sine wave
wave = np.sin(frequency * 2 * np.pi * t)

# Add fade-in and fade-out envelope for smoother sound
fade_time = 0.05  # 50ms fade
fade_samples = int(sample_rate * fade_time)
envelope = np.ones_like(wave)
envelope[:fade_samples] = np.linspace(0, 1, fade_samples)
envelope[-fade_samples:] = np.linspace(1, 0, fade_samples)
wave = wave * envelope

# Boost amplitude significantly for maximum loudness
amplitude_boost = 1  # Much louder
wave = wave * amplitude_boost

# Hard clip to prevent overflow while maintaining maximum volume
wave = np.clip(wave, -1.0, 1.0)

# Normalize to 16-bit range at maximum volume
wave = np.int16(wave * 32767 * 0.95)

# Write to WAV file
write("assets/sounds/disappointing_beep.wav", sample_rate, wave)

print("Disappointing beep sound generated: assets/sounds/disappointing_beep.wav")