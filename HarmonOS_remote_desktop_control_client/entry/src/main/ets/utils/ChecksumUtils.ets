/**
 * 校验和工具类
 * 实现Adler32算法，与Java客户端保持一致
 */
export class ChecksumUtils {
  private static readonly MOD_ADLER: number = 65521;
  private static readonly CHUNK_SIZE: number = 5552;

  static computeAdler32(data: Uint8Array): number {
    let a: number = 1;
    let b: number = 0;
    const len = data.length;
    let i = 0;

    while (i < len) {
      const end = Math.min(i + ChecksumUtils.CHUNK_SIZE, len);
      for (let j = i; j < end; j++) {
        a += data[j];
        b += a;
      }
      a %= ChecksumUtils.MOD_ADLER;
      b %= ChecksumUtils.MOD_ADLER;
      i = end;
    }

    return (b << 16) | a;
  }

  static verifyChecksum(data: Uint8Array, expectedChecksum: number): boolean {
    const actualChecksum = ChecksumUtils.computeAdler32(data);
    return actualChecksum === expectedChecksum;
  }

  static computeAdler32FromBuffer(buffer: ArrayBuffer): number {
    const data = new Uint8Array(buffer);
    return ChecksumUtils.computeAdler32(data);
  }

  static verifyChecksumFromBuffer(buffer: ArrayBuffer, expectedChecksum: number): boolean {
    const data = new Uint8Array(buffer);
    return ChecksumUtils.verifyChecksum(data, expectedChecksum);
  }
}
