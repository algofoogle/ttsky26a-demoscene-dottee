# SPDX-FileCopyrightText: © 2026 Anton Maurovic
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, ClockCycles
import time
from os import environ as env
import re

HIGH_RES        = float(env.get('HIGH_RES')) if 'HIGH_RES' in env else None # If not None, scale H res by this, and step by CLOCK_PERIOD/HIGH_RES instead of unit clock cycles.
CLOCK_PERIOD    = float(env.get('CLOCK_PERIOD') or 40.0) # Default 40.0 (period of clk oscillator input, in nanoseconds)
FRAMES          =   int(env.get('FRAMES')       or   30) # Default 30 (total frames to render)
REG             =   int(env.get('REG')          or    0) # Default 0 (UNregistered outputs)

print(f"""
Test parameters (can be overridden using ENV vars):
---     HIGH_RES: {HIGH_RES}
--- CLOCK_PERIOD: {CLOCK_PERIOD}
---       FRAMES: {FRAMES}
---          REG: {REG}
""")

# This can represent hard-wired stuff:
def set_default_start_state(dut):
    dut.ena.value                   = 1
    # # Present registered outputs?
    # dut.registered_outputs.value    = REG


async def async_run_all(steps):
    for step in steps:
        await step


@cocotb.test()
async def test_frames(dut):
    """
    Generate a number of full video frames and write to frames_out/frame-###.ppm
    """

    dut._log.info("Starting test_frames...")

    frame_count = FRAMES # No. of frames to render.
    hrange = 800
    frame_height = 525
    vrange = frame_height
    hres = HIGH_RES or 1

    print(f"Rendering {frame_count} full frame(s)...")

    set_default_start_state(dut)
    # Start with reset released:
    dut.rst_n.value = 1

    clk = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    cocotb.start_soon(clk.start())

    # Wait 3 clocks...
    await ClockCycles(dut.clk, 3)
    dut._log.info("Assert reset...")
    # ...then assert reset:
    dut.rst_n.value = 0
    # ...and wait another 10 clocks...
    await ClockCycles(dut.clk, 10)
    dut._log.info("Release reset...")
    # ...then release reset:
    dut.rst_n.value = 1
    x_count = 0 # Counts unknown signal values.
    z_count = 0
    sample_count = 0 # Total count of pixels or samples.

    audio_bit_counter = 0
    audio_bit_accum = 0
    audio_x = 0
    audio_z = 0
    total_audio_bits = 0

    dds = open(f"frames_out/audio_stream.bin", "wb")

    for frame in range(frame_count):
        render_start_time = time.time()

        nframe = frame + 1

        # Create PPM file to visualise the frame, and write its header:
        img = open(f"frames_out/frame-{frame:03d}.ppm", "w")
        img.write("P3\n")
        img.write(f"{int(hrange*hres)} {vrange:d}\n")
        img.write("255\n")

        for n in range(vrange): # 525 lines * however many frames in frame_count
            dds.flush()
            print(f"Rendering line {n} of frame {frame}")
            for n in range(int(hrange*hres)): # 800 pixel clocks per line.
                speaker = dut.speaker.value
                sc = str(speaker).lower()
                audio_bit_accum <<= 1
                if 'x' in sc:
                    audio_x += 1
                elif 'z' in sc:
                    audio_z += 1
                else:
                    audio_bit_accum |= (int(speaker) & 1)
                if audio_bit_counter == 7:
                    # Write this bit out, then reset the accumulator:
                    dds.write(audio_bit_accum.to_bytes(1))
                    audio_bit_accum = 0
                    audio_bit_counter = 0
                else:
                    audio_bit_counter += 1
                total_audio_bits += 1

                if n % 100 == 0:
                    print('.', end='')
                if 'x' in str(dut.rgb.value).lower():
                    # Output is unknown; make it green:
                    r = 0
                    g = 255
                    b = 0
                elif 'z' in str(dut.rgb.value).lower():
                    # Output is HiZ; make it magenta:
                    r = 255
                    g = 0
                    b = 255
                else:
                    rr = int(dut.rr.value)
                    gg = int(dut.gg.value)
                    bb = int(dut.bb.value)
                    hsyncb = 255 if str(dut.hsync_n.value).lower()=='x' else (0==dut.hsync_n.value)*0b110000
                    vsyncb = 128 if str(dut.vsync_n.value).lower()=='x' else (0==dut.vsync_n.value)*0b110000
                    r = (rr << 6) | hsyncb
                    g = (gg << 6) | vsyncb
                    b = (bb << 6)
                sample_count += 1
                if 'x' in (str(dut.rgb.value) + str(dut.hsync_n.value) + str(dut.vsync_n.value)).lower():
                    x_count += 1
                if 'z' in (str(dut.rgb.value) + str(dut.hsync_n.value) + str(dut.vsync_n.value)).lower():
                    z_count += 1
                img.write(f"{r} {g} {b}\n")
                if HIGH_RES is None:
                    await ClockCycles(dut.clk, 1) 
                else:
                    await Timer(CLOCK_PERIOD/hres, unit='ns')
        img.close()
        render_stop_time = time.time()
        delta = render_stop_time - render_start_time
        print(f"[{render_stop_time}: Frame simulated in {delta} seconds]")
    dds.close()
    print("Waiting 1 more clock, for start of next line...")
    await ClockCycles(dut.clk, 1)

    # await toggler

    print(f"DONE: Out of {sample_count} pixels/samples, got: {x_count} 'x'; {z_count} 'z' -- Out of {total_audio_bits} audio bits, got: {audio_x} 'x'; {audio_z} 'z'")
