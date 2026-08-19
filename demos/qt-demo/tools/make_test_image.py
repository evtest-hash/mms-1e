#!/usr/bin/env python3
"""生成 demo 用测试镜像 (test.img) + bmap 文件 (test.bmap)。

- 镜像为稀疏文件（未填写的块全为 0），只有少数区段有数据，模拟真实系统镜像。
- bmap 文件按 intel/bmap-tools 的 v2.0 格式生成，与移植的 BmapParser 一一对应。
"""
import os
import struct

OUT = os.path.dirname(os.path.abspath(__file__)) or "."
IMG = os.path.join(OUT, "test.img")
BMAP = os.path.join(OUT, "test.bmap")

BLOCK = 4096
TOTAL_BLOCKS = 128 * 1024 * 1024 // BLOCK  # 128 MiB 镜像

# 有数据的块区间（块号, 结束块号，含端点）
FILL = [
    (0, 8),       # 引导区
    (64, 72),     # 中间数据段
    (1000, 1016),  # 后段数据
]

with open(IMG, "wb") as f:
    f.truncate(TOTAL_BLOCKS * BLOCK)
    seq = 0
    for start, end in FILL:
        for b in range(start, end + 1):
            f.seek(b * BLOCK)
            chunk = bytearray(b"MMS1E-DEMO|")
            while len(chunk) < BLOCK:
                chunk += struct.pack(">I", seq % 0xFFFFFFFF)
                seq += 1
            f.write(chunk[:BLOCK])

mapped = sum(e - s + 1 for s, e in FILL)

with open(BMAP, "w", encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n')
    f.write('<bmap version="2.0">\n')
    f.write(f'  <ImageSize>{TOTAL_BLOCKS * BLOCK}</ImageSize>\n')
    f.write(f'  <BlockSize>{BLOCK}</BlockSize>\n')
    f.write(f'  <BlocksCount>{TOTAL_BLOCKS}</BlocksCount>\n')
    f.write(f'  <MappedBlocksCount>{mapped}</MappedBlocksCount>\n')
    f.write('  <ChecksumType>sha256</ChecksumType>\n')
    f.write('  <BlockMap>\n')
    for start, end in FILL:
        f.write(f'    <Range>{start}-{end}</Range>\n')
    f.write('  </BlockMap>\n')
    f.write('</bmap>\n')

print(f"生成 {IMG}  ({TOTAL_BLOCKS * BLOCK} bytes, {mapped} mapped blocks)")
print(f"生成 {BMAP}")
