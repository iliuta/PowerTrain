import numpy as np
from scipy.io.wavfile import write

def generate_tick(frequency, output_file, volume=0.6):
    """Generate a mechanical clock tick sound at specified frequency"""
    sample_rate = 44100  # Hz
    duration = 0.03  # seconds (very short, 30ms)

    # Generate time array
    t = np.linspace(0, duration, int(sample_rate * duration), False)

    # Generate a short sine wave burst
    wave = np.sin(frequency * 2 * np.pi * t)

    # Add a tiny bit of higher harmonic for metallic quality
    wave += 0.2 * np.sin(frequency * 4 * 2 * np.pi * t)

    # Create extremely sharp attack and immediate decay
    attack_time = 0.001  # 1ms attack (ultra sharp)
    attack_samples = int(sample_rate * attack_time)

    envelope = np.zeros_like(wave)
    # Ultra sharp attack
    envelope[:attack_samples] = np.linspace(0, 1, attack_samples)
    # Very fast exponential decay
    remaining_samples = len(wave) - attack_samples
    if remaining_samples > 0:
        envelope[attack_samples:] = np.exp(-np.linspace(0, 8, remaining_samples))

    wave = wave * envelope

    # Add a small amount of filtered noise for mechanical texture
    #noise = 0.05 * np.random.normal(0, 1, len(wave))
    # Simple low-pass filter simulation (rough)
    #noise_filtered = np.convolve(noise, np.ones(5)/5, mode='same')
    #wave += noise_filtered * envelope

    # Normalize
    wave = wave / np.max(np.abs(wave)) * volume

    # Convert to 16-bit
    wave = np.int16(wave * 32767)

    # Write to WAV file
    write(output_file, sample_rate, wave)
    print(f"Mechanical tick sound generated: {output_file}")

# Generate higher tick (for metronome)
generate_tick(frequency=400, output_file="assets/sounds/tick_high.wav", volume=1.5)

# Generate lower tick (for metronome)
generate_tick(frequency=250, output_file="assets/sounds/tick_low.wav", volume=1.5)

print("Metronome tick sounds generated: tick_high.wav and tick_low.wav")