import { MemByteBuffer } from './MemByteBuffer';

export interface RunLengthEncoder {
  runLengthEncode(out: MemByteBuffer, capture: MemByteBuffer): void;
  runLengthDecode(out: MemByteBuffer, encoded: MemByteBuffer): void;
}

export class NullRunLengthEncoder implements RunLengthEncoder {
  runLengthEncode(out: MemByteBuffer, capture: MemByteBuffer): void {
    const data = capture.getInternal();
    out.writeBytes(data);
  }

  runLengthDecode(out: MemByteBuffer, encoded: MemByteBuffer): void {
    const data = encoded.getInternal();
    out.writeBytes(data);
  }
}

export class RegularRunLengthEncoder implements RunLengthEncoder {
  runLengthEncode(out: MemByteBuffer, capture: MemByteBuffer): void {
    const data = capture.getInternal();
    const len = capture.size();
    let pos = 0;
    let prev = -2147483648;
    while (pos < len) {
      const current = data[pos];
      out.writeByte(current);
      if (current !== prev) {
        prev = current;
        pos++;
      } else {
        let count = 0;
        let noMatch = 0;
        while (count < 255 && pos + 1 < len && (noMatch = data[pos + 1]) === current) {
          count++;
          pos++;
        }
        if (count === 255) {
          out.writeByte(255);
          prev = -2147483648;
          pos++;
        } else if (pos + 1 < len) {
          out.writeByte(count);
          prev = noMatch;
          out.writeByte(prev);
          pos += 2;
        } else {
          if (count > 0) {
            out.writeByte(count);
          }
          break;
        }
      }
    }
  }

  runLengthDecode(out: MemByteBuffer, encoded: MemByteBuffer): void {
    const data = encoded.getInternal();
    const len = encoded.size();
    console.log(`[步骤6-RLE解码] 开始解码, 输入数据大小: ${len}字节`);
    let pos = 0;
    let prev = -2147483648;
    let decodeCount = 0;
    while (pos < len) {
      const current = data[pos++];
      out.writeByte(current);
      decodeCount++;
      if (current !== prev) {
        prev = current;
      } else if (pos < len) {
        const count = data[pos++] & 0xFF;
        for (let i = 0; i < count; i++) {
          out.writeByte(current);
          decodeCount++;
        }
        prev = -2147483648;
      }
    }
    console.log(`[步骤6-RLE解码] 解码完成, 输出数据大小: ${out.size()}字节, 解码字节数: ${decodeCount}`);
  }
}
