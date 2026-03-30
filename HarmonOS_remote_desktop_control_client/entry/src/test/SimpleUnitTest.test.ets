/**
 * 简单的单元测试示例
 * 
 * 这是一个基础的单元测试，用于演示如何编写和运行测试
 */

import { describe, it, expect } from '@ohos/hypium';

export default function simpleUnitTest() {
  describe('简单单元测试', () => {
    
    it('测试加法运算', 0, () => {
      const result = 2 + 3;
      expect(result).assertEqual(5);
      console.info('✓ 加法测试通过');
    });
    
    it('测试字符串拼接', 0, () => {
      const result = 'Hello' + ' ' + 'World';
      expect(result).assertEqual('Hello World');
      console.info('✓ 字符串拼接测试通过');
    });
    
    it('测试数组操作', 0, () => {
      const arr = [1, 2, 3];
      expect(arr.length).assertEqual(3);
      expect(arr[0]).assertEqual(1);
      console.info('✓ 数组操作测试通过');
    });
    
    it('测试对象创建', 0, () => {
      const obj = { name: 'test', value: 123 };
      expect(obj.name).assertEqual('test');
      expect(obj.value).assertEqual(123);
      console.info('✓ 对象创建测试通过');
    });
    
    it('测试布尔值', 0, () => {
      const isTrue = true;
      const isFalse = false;
      expect(isTrue).assertTrue();
      expect(isFalse).assertFalse();
      console.info('✓ 布尔值测试通过');
    });
    
  });
}
