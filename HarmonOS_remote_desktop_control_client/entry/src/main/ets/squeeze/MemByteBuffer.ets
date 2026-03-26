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
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + this.writeOffset);
    view.setInt16(0, value, false);
    this.writeOffset += 2;
  }

  writeInt(value: number): void {
    this.ensureCapacity(4);
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + this.writeOffset);
    view.setInt32(0, value, false);
    this.writeOffset += 4;
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
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + this.readOffset);
    const result = view.getInt16(0, false);
    this.readOffset += 2;
    return result;
  }


  readUnsignedShort(): number {
    if (this.readOffset + 2 > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + this.readOffset);
    const result = view.getUint16(0, false);
    this.readOffset += 2;
    return result;
  }

  readInt(): number {
    if (this.readOffset + 4 > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const view = new DataView(this.buffer.buffer, this.buffer.byteOffset + this.readOffset);
    const result = view.getInt32(0, false);
    this.readOffset += 4;
    return result;
  }

  readBytes(length: number): Uint8Array {
    if (this.readOffset + length > this.writeOffset) {
      throw new Error('Buffer underflow');
    }
    const result = this.buffer.subarray(this.readOffset, this.readOffset + length);
    this.readOffset += length;
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

  reset(): void {
    this.readOffset = 0;
  }
}
