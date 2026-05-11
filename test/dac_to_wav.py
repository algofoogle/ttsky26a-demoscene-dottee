#!/usr/bin/env python3
import argparse
import wave
import numpy as np


# Example:
# python ./dac_to_wav.py --input-rate 25175000 --output-rate 50350 --gain 0.95 frames_out/audio_stream.bin frames_out/audio_stream.wav

def unpack_lsb_first(data: bytes) -> np.ndarray:
    """Unpack bytes into bits, LSB-first within each byte."""
    b = np.frombuffer(data, dtype=np.uint8)
    bits = ((b[:, None] >> np.arange(8)) & 1).astype(np.uint8)
    return bits.reshape(-1)


def write_wav_mono_16(filename: str, samples: np.ndarray, sample_rate: int) -> None:
    """Write float samples in [-1, 1] as mono 16-bit PCM WAV."""
    samples = np.clip(samples, -1.0, 1.0)
    pcm = np.round(samples * 32767.0).astype(np.int16)

    with wave.open(filename, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(pcm.tobytes())


def main():
    ap = argparse.ArgumentParser(
        description="Convert packed 1-bit DAC stream to WAV via simple decimation."
    )
    ap.add_argument("input_bin", help="Packed DAC bitstream (8 samples per byte, LSB-first)")
    ap.add_argument("output_wav", help="Output WAV filename")
    ap.add_argument("--input-rate", type=int, default=25_000_000,
                    help="Input DAC bitstream sample rate in Hz (default: 25000000)")
    ap.add_argument("--output-rate", type=int, default=50_000,
                    help="Output WAV sample rate in Hz (default: 50000)")
    ap.add_argument("--gain", type=float, default=0.95,
                    help="Output gain after DC removal and normalization (default: 0.95)")
    args = ap.parse_args()

    if args.input_rate % args.output_rate != 0:
        raise SystemExit(
            f"ERROR: input-rate ({args.input_rate}) must be an integer multiple of "
            f"output-rate ({args.output_rate}) for this simple converter."
        )

    decim = args.input_rate // args.output_rate
    print(f"Input rate   : {args.input_rate} Hz")
    print(f"Output rate  : {args.output_rate} Hz")
    print(f"Decimation   : {decim}")

    with open(args.input_bin, "rb") as f:
        raw = f.read()

    bits = unpack_lsb_first(raw).astype(np.float64)

    # Trim to a whole number of decimation blocks
    usable = (len(bits) // decim) * decim
    bits = bits[:usable]

    # Average each decimation block.
    # bits are 0/1, so mean is in [0,1].
    pcm = bits.reshape(-1, decim).mean(axis=1)

    # Convert [0,1] to [-1,1]
    pcm = pcm * 2.0 - 1.0

    # Remove any tiny DC offset
    pcm = pcm - np.mean(pcm)

    # Normalize
    peak = np.max(np.abs(pcm))
    if peak > 0:
        pcm = pcm / peak

    pcm *= args.gain

    write_wav_mono_16(args.output_wav, pcm, args.output_rate)

    print(f"Wrote WAV: {args.output_wav}")
    print(f"Samples  : {len(pcm)}")


if __name__ == "__main__":
    main()
