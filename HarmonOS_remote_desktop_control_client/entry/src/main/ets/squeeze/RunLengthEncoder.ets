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
    let pos = 0;
    while (pos < data.length) {
      const start = pos;
      const value = data[pos];
      pos++;
      while (pos < data.length && data[pos] === value && pos - start < 128) {
        pos++;
      }
      const count = pos - start;
      if (count > 1) {
        out.writeByte(-(count - 1));
        out.writeByte(value);
      } else {
        out.writeByte(count - 1);
        out.writeByte(value);
      }
    }
  }

  runLengthDecode(out: MemByteBuffer, encoded: MemByteBuffer): void {
    const data = encoded.getInternal();
    let pos = 0;
    while (pos < data.length) {
      const flag = data[pos++];
      if (flag >= 0) {
        const count = flag + 1;
        for (let i = 0; i < count && pos < data.length; i++) {
          out.writeByte(data[pos++]);
        }
      } else {
        const count = -flag + 1;
        const value = data[pos++];
        for (let i = 0; i < count; i++) {
          out.writeByte(value);
        }
      }
    }
  }
}
