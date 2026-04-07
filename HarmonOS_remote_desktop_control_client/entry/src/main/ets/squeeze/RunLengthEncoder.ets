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
        while (count < 255 && ++pos < len && (noMatch = data[pos]) === current) {
          count++;
        }
        if (count === 255) {
          out.writeByte(255);
          prev = -2147483648;
          pos++;
        } else if (pos < len) {
          out.writeByte(count);
          prev = noMatch;
          out.writeByte(prev);
          pos++;
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
    let pos = 0;
    let prev = -2147483648;
    while (pos < len) {
      const current = data[pos++];
      out.writeByte(current);
      if (current !== prev) {
        prev = current;
      } else if (pos < len) {
        const count = data[pos++] & 0xFF;
        out.fill(count, current);
        prev = -2147483648;
      }
    }
  }
}
