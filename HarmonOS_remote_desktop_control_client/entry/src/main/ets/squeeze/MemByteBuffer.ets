import hilog from '@ohos.hilog';

const DOMAIN: number = 0xFF00;
const TAG: string = 'MemByteBuffer';

export class MemByteBuffer {
  private buffer: Uint8Array;
  private readOffset: number = 0;
  private writeOffset: number = 0;
  private marks: Map<number, number> = new Map();

  constructor(initialCapacity: number = 256) {
    this.buffer = new Uint8Array(initialCapacity);
  }



  static fromArray(array: Uint8Array): MemByteBuffer {
    const result = new MemByteBuffer(array.length);
    result.writeBytes(array);
    result.readOffset = 0;
    return result;
  }

  private ensureCapacity(needed: number): void {
    const required = this.writeOffset + needed;
    if (required > this.buffer.length) {
      const newCapacity = Math.max(this.buffer.length * 2, required);
      const newBuffer = new Uint8Array(newCapacity);
      newBuffer.set(this.buffer.subarray(0, this.writeOffset));
      this.buffer = newBuffer;
    }
  }

  mark(): number {
    const id = this.marks.size;
    this.marks.set(id, this.writeOffset);
    return id;
  }

  writeLenAsShort(markId: number): void {
    const markPos = this.marks.get(markId);
    if (markPos === undefined) {
      throw new Error('Invalid mark id');
    }
    const length = this.writeOffset - markPos - 2;
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + markPos);
    view.setInt16(0, -length, false);
  }

  writeByte(value: number): void {
    this.ensureCapacity(1);
    this.buffer[this.writeOffset++] = value & 0xFF;
  }

  writeBytes(bytes: Uint8Array): void {
    this.ensureCapacity(bytes.length);
    this.buffer.set(bytes, this.writeOffset);
    this.writeOffset += bytes.length;
  }

  writeShort(value: number): void {
    this.ensureCapacity(2);
    this.buffer[this.writeOffset++] = (value >> 8) & 0xFF;
    this.buffer[this.writeOffset++] = value & 0xFF;
  }

  writeInt(value: number): void {
    this.ensureCapacity(4);
    this.buffer[this.writeOffset++] = (value >> 24) & 0xFF;
    this.buffer[this.writeOffset++] = (value >> 16) & 0xFF;
    this.buffer[this.writeOffset++] = (value >> 8) & 0xFF;
    this.buffer[this.writeOffset++] = value & 0xFF;
  }

  readByte(): number {
    if (this.readOffset >= this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    return this.buffer[this.readOffset++] & 0xFF;
  }

  readUnsignedByte(): number {
    return this.readByte() & 0xFF;
  }

  readShort(): number {
    if (this.readOffset + 2 > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const b1 = this.buffer[this.readOffset++] & 0xFF;
    const b2 = this.buffer[this.readOffset++] & 0xFF;
    let result = (b1 << 8) | b2;
    // 与 Java 的 DataInputStream.readShort() 一致
    if ((result & 0x8000) !== 0) {
      result = result - 0x10000;
    }
    hilog.error(DOMAIN, TAG, 'readShort: b1=0x%{public}s, b2=0x%{public}s, result=%{public}d', b1.toString(16), b2.toString(16), result);
    return result;
  }

  readUnsignedShort(): number {
    if (this.readOffset + 2 > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const b1 = this.buffer[this.readOffset++] & 0xFF;
    const b2 = this.buffer[this.readOffset++] & 0xFF;
    return (b1 << 8) | b2;
  }

  readInt(): number {
    if (this.readOffset + 4 > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const b1 = this.buffer[this.readOffset++] & 0xFF;
    const b2 = this.buffer[this.readOffset++] & 0xFF;
    const b3 = this.buffer[this.readOffset++] & 0xFF;
    const b4 = this.buffer[this.readOffset++] & 0xFF;
    let result = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    return result;
  }

  readBytes(length: number): Uint8Array {
    hilog.error(DOMAIN, TAG, 'readBytes requested: %{public}d, available: %{public}d', length, this.writeOffset - this.readOffset);
    if (this.readOffset + length > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const result = this.buffer.subarray(this.readOffset, this.readOffset + length);
    this.readOffset += length;
    return result;
  }

  /**
   * 尽力读取最多 length 字节，不抛出异常
   * 返回实际读取的字节数
   */
  readBytesBestEffort(length: number): Uint8Array {
    const available = this.writeOffset - this.readOffset;
    const toRead = Math.min(available, length);
    hilog.error(DOMAIN, TAG, 'readBytesBestEffort requested: %{public}d, available: %{public}d, toRead: %{public}d', length, available, toRead);
    const result = this.buffer.subarray(this.readOffset, this.readOffset + toRead);
    this.readOffset += toRead;
    return result;
  }

  readAllBytes(): Uint8Array {
    return this.buffer.subarray(0, this.writeOffset);
  }

  getInternal(): Uint8Array {
    return this.buffer.subarray(0, this.writeOffset);
  }
  size(): number {
    return this.writeOffset;
  }

  getReadOffset(): number {
    return this.readOffset;
  }

  getWriteOffset(): number {
    return this.writeOffset;
  }

  reset(): void {
    this.readOffset = 0;
  }

  fill(count: number, value: number): void {
    this.ensureCapacity(count);
    for (let i = 0; i < count; i++) {
      this.buffer[this.writeOffset++] = value & 0xFF;
    }
  }
}
