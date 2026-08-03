import hilog from '@ohos.hilog';
import { ChecksumUtils } from '../utils/ChecksumUtils';

const DOMAIN: number = 0xFF00;
const TAG: string = 'MemByteBuffer';

export class MemByteBuffer {
  private buffer: Uint8Array;
  private readOffset: number = 0;
  private writeOffset: number = 0;

  constructor(initialCapacity: number = 256) {
    this.buffer = new Uint8Array(initialCapacity);
  }



  static fromArray(array: Uint8Array): MemByteBuffer {
    const result = new MemByteBuffer(array.length);
    result.writeBytes(array);
    result.readOffset = 0;
    return result;
  }

  /**
   * 零拷贝包装：直接引用外部 ArrayBuffer，避免整帧拷贝
   * 适用于解压结果等只读大数据，调用方不得对返回实例执行写入操作
   */
  static wrapArrayBuffer(buffer: ArrayBuffer): MemByteBuffer {
    const result = new MemByteBuffer(0);
    result.buffer = new Uint8Array(buffer);
    result.writeOffset = result.buffer.length;
    result.readOffset = 0;
    return result;
  }

  /**
   * 零拷贝包装 Uint8Array（视图），避免瓦片数据中间拷贝
   * 适用于 NullRLE 直通路径，调用方不得对返回实例执行写入操作
   */
  static wrapUint8Array(data: Uint8Array): MemByteBuffer {
    const result = new MemByteBuffer(0);
    result.buffer = data;
    result.writeOffset = data.length;
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
    const value = this.buffer[this.readOffset++] & 0xFF;
    return value > 127 ? value - 256 : value;
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
    const result = (b1 << 8) | b2;
    const signedResult = result > 32767 ? result - 65536 : result;
    return signedResult;
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

  copyRange(start: number, end: number): Uint8Array {
    const from = Math.max(0, start);
    const to = Math.min(this.writeOffset, Math.max(from, end));
    return this.buffer.slice(from, to);
  }

  toArray(): Uint8Array {
    return this.buffer.slice(0, this.writeOffset);
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

  /**
   * 填充指定数量的字节
   * @param len 填充长度
   * @param value 填充值
   */
  fill(len: number, value: number): void {
    this.ensureCapacity(len);
    this.buffer.fill(value & 0xFF, this.writeOffset, this.writeOffset + len);
    this.writeOffset += len;
  }

  /**
   * 计算当前缓冲区数据的校验和
   * @returns Adler32校验和
   */
  computeChecksum(): number {
    const data = this.buffer.subarray(0, this.writeOffset);
    return ChecksumUtils.computeAdler32(data);
  }

  /**
   * 验证当前缓冲区数据的校验和
   * @param expectedChecksum 期望的校验和
   * @returns 是否验证通过
   */
  verifyChecksum(expectedChecksum: number): boolean {
    const data = this.buffer.subarray(0, this.writeOffset);
    return ChecksumUtils.verifyChecksum(data, expectedChecksum);
  }

  /**
   * 写入校验和到缓冲区
   */
  writeChecksum(): void {
    const checksum = this.computeChecksum();
    this.writeInt(checksum);
  }

  /**
   * 读取并验证校验和
   * @param expectedChecksum 期望的校验和
   * @returns 是否验证通过
   */
  readAndVerifyChecksum(expectedChecksum: number): boolean {
    const checksum = this.readInt();
    return checksum === expectedChecksum;
  }
}
