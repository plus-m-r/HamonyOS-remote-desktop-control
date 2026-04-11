/**
 * 校验和工具类
 * 实现Adler32算法，与Java客户端保持一致
 */
export class ChecksumUtils {
  /**
   * Adler32算法的模数
   */
  private static readonly MOD_ADLER: number = 65521;

  /**
   * 计算Adler32校验和
   * @param data 要计算校验和的数据
   * @returns Adler32校验和
   */
  static computeAdler32(data: Uint8Array): number {
    let a: number = 1;
    let b: number = 0;
    
    for (let i = 0; i < data.length; i++) {
      a = (a + data[i]) % ChecksumUtils.MOD_ADLER;
      b = (b + a) % ChecksumUtils.MOD_ADLER;
    }
    
    return (b << 16) | a;
  }

  /**
   * 验证校验和
   * @param data 要验证的数据
   * @param expectedChecksum 期望的校验和
   * @returns 是否验证通过
   */
  static verifyChecksum(data: Uint8Array, expectedChecksum: number): boolean {
    const actualChecksum = ChecksumUtils.computeAdler32(data);
    return actualChecksum === expectedChecksum;
  }

  /**
   * 计算ArrayBuffer的校验和
   * @param buffer 要计算校验和的ArrayBuffer
   * @returns Adler32校验和
   */
  static computeAdler32FromBuffer(buffer: ArrayBuffer): number {
    const data = new Uint8Array(buffer);
    return ChecksumUtils.computeAdler32(data);
  }

  /**
   * 验证ArrayBuffer的校验和
   * @param buffer 要验证的ArrayBuffer
   * @param expectedChecksum 期望的校验和
   * @returns 是否验证通过
   */
  static verifyChecksumFromBuffer(buffer: ArrayBuffer, expectedChecksum: number): boolean {
    const data = new Uint8Array(buffer);
    return ChecksumUtils.verifyChecksum(data, expectedChecksum);
  }
}
