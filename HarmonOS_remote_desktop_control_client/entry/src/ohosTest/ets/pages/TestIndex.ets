
import hilog from '@ohos.hilog';
import { describe, it, expect } from '@ohos/hypium';

@Entry
@Component
struct TestIndex {
  @State message: string = '测试运行中...';

  aboutToAppear(): void {
    hilog.info(0x0000, 'testTag', 'TestIndex aboutToAppear');
    
    // 运行测试
    this.runTests();
  }

  runTests(): void {
    try {
      // 导入测试套件
      import('./../test/List.test').then((module) => {
        const testSuite = module.default;
        if (typeof testSuite === 'function') {
          // 运行测试套件
          testSuite();
          
          // 简化测试结果处理
          hilog.info(0x0000, 'testTag', '测试套件执行完成');
          this.message = '测试执行完成';
        } else {
          hilog.error(0x0000, 'testTag', '测试套件不是一个函数');
          this.message = '测试套件加载失败';
        }
      }).catch((error:Error) => {
        hilog.error(0x0000, 'testTag', `导入测试套件失败: ${error.message}`);
        this.message = `导入测试套件失败: ${error.message}`;
      });
    } catch (error) {
      hilog.error(0x0000, 'testTag', `运行测试时发生错误: ${error.message}`);
      this.message = `运行测试时发生错误: ${error.message}`;
    }
  }

  build() {
    Column() {
      Text(this.message)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 50 })
      
      Text('测试结果将在日志中显示')
        .fontSize(16)
        .margin({ top: 20 })
      
      Text('请查看hilog日志获取详细测试结果')
        .fontSize(14)
        .margin({ top: 10 })
        .fontColor(Color.Gray)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}