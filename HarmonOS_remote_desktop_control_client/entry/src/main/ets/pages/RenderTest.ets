import {
  ArkZeroSurfaceView,
  SurfaceViewConfig,
  ArkZeroRenderSession,
  RenderSessionConfig,
  PixelFormat,
  TileRegion
} from '@plusml/arkzero';
import hilog from '@ohos.hilog';

const TAG = 'RenderTestPage';
const DOMAIN = 0x0000;
const W = 320;
const H = 240;
const TILE = 64;

interface TestStep {
  label: string;
  run: (session: ArkZeroRenderSession) => Promise<void>;
}

@Entry
@Component
struct RenderTest {
  @State private logText: string = '';
  @State private currentStep: number = -1;
  @State private isRunning: boolean = false;
  @State private statusText: string = '等待Surface加载...';
  @State private sessionReady: boolean = false;

  private renderSession: ArkZeroRenderSession | null = null;

  private appendLog(msg: string): void {
    this.logText += msg + '\n';
    hilog.info(DOMAIN, TAG, '%{public}s', msg);
  }

  private makeSolidColor(count: number, r: number, g: number, b: number): Uint8Array {
    const buf = new Uint8Array(count * 4);
    for (let i = 0; i < buf.length; i += 4) {
      buf[i] = r; buf[i + 1] = g; buf[i + 2] = b; buf[i + 3] = 255;
    }
    return buf;
  }

  private makeTile(tx: number, ty: number, r: number, g: number, b: number): TileRegion {
    const tw = Math.min(TILE, W - tx);
    const th = Math.min(TILE, H - ty);
    const d = this.makeSolidColor(tw * th, r, g, b);
    return {
      ratioX: tx / W, ratioY: ty / H,
      tilePixelWidth: tw, tilePixelHeight: th,
      pixelData: d.buffer.slice(0)
    } as TileRegion;
  }

  private makeAllTiles(r: number, g: number, b: number): TileRegion[] {
    const tiles: TileRegion[] = [];
    for (let ty = 0; ty < H; ty += TILE) {
      for (let tx = 0; tx < W; tx += TILE) {
        tiles.push(this.makeTile(tx, ty, r, g, b));
      }
    }
    return tiles;
  }

  private readonly testSteps: TestStep[] = [
    {
      label: 'T1: renderFullFrame 红(R=255,G=0,B=0)',
      run: async (session: ArkZeroRenderSession) => {
        const buf = this.makeSolidColor(W * H, 255, 0, 0);
        await session.renderFullFrame(buf.buffer.slice(0), W, H);
        this.appendLog('  → 应为红色');
      }
    },
    {
      label: 'T2: renderTileRegions 全绿 swap=true',
      run: async (session: ArkZeroRenderSession) => {
        await session.renderTileRegions(this.makeAllTiles(0, 255, 0), W, H, true);
        this.appendLog('  → 应为全绿');
      }
    },
    {
      label: 'T3: 1红瓦片(0,0) swap=true 增量',
      run: async (session: ArkZeroRenderSession) => {
        await session.renderTileRegions([this.makeTile(0, 0, 255, 0, 0)], W, H, true);
        this.appendLog('  → swap=true: 绿底+左上红瓦片(Direct-Retain保留未更新区域)');
      }
    },
    {
      label: 'T4: renderFullFrame 绿(重置)',
      run: async (session: ArkZeroRenderSession) => {
        const buf = this.makeSolidColor(W * H, 0, 255, 0);
        await session.renderFullFrame(buf.buffer.slice(0), W, H);
        this.appendLog('  → 应为全绿');
      }
    },
    {
      label: 'T5: 1红瓦片(0,0) swap=false + presentFrame',
      run: async (session: ArkZeroRenderSession) => {
        await session.renderTileRegions([this.makeTile(0, 0, 255, 0, 0)], W, H, false);
        await session.presentFrame();
        this.appendLog('  → swap=false+present: 应为绿底+左上红瓦片');
      }
    },
    {
      label: 'T6: 再1红瓦片(64,0) swap=false + presentFrame',
      run: async (session: ArkZeroRenderSession) => {
        await session.renderTileRegions([this.makeTile(TILE, 0, 255, 0, 0)], W, H, false);
        await session.presentFrame();
        this.appendLog('  → 应为绿底+左上2个红瓦片(增量累积)');
      }
    },
    {
      label: 'T7: 再1蓝瓦片(128,0) swap=false + presentFrame',
      run: async (session: ArkZeroRenderSession) => {
        await session.renderTileRegions([this.makeTile(TILE * 2, 0, 0, 0, 255)], W, H, false);
        await session.presentFrame();
        this.appendLog('  → 应为绿底+2红瓦片+1蓝瓦片(增量累积)');
      }
    },
    {
      label: 'T8: [255,0,0,255] renderFullFrame 字节序验证',
      run: async (session: ArkZeroRenderSession) => {
        const buf = this.makeSolidColor(W * H, 255, 0, 0);
        await session.renderFullFrame(buf.buffer.slice(0), W, H);
        this.appendLog('  RGBA下[R=255,G=0,B=0]→红; 若显蓝=组件按BGRA解读');
      }
    },
    {
      label: 'T9: [0,0,255,255] renderFullFrame 字节序对比',
      run: async (session: ArkZeroRenderSession) => {
        const buf = this.makeSolidColor(W * H, 0, 0, 255);
        await session.renderFullFrame(buf.buffer.slice(0), W, H);
        this.appendLog('  RGBA下[R=0,G=0,B=255]→蓝; 若显红=组件按BGRA解读');
      }
    }
  ];

  private async runAllTests(): Promise<void> {
    if (this.isRunning) return;
    if (!this.renderSession || !this.renderSession.ready) {
      this.appendLog('Session未准备好');
      return;
    }

    this.isRunning = true;
    this.logText = '';

    try {
      this.appendLog('=== RenderTest START ===');
      this.appendLog('单纹理Direct-Retain模型: swap=true立即Present, swap=false累积后手动presentFrame');
      await this.renderSession.resize(W, H);
      await this.renderSession.setVSync(false);
      this.appendLog('Resized ' + W + 'x' + H + ' VSync=off');

      for (let i = 0; i < this.testSteps.length; i++) {
        this.currentStep = i;
        this.statusText = 'Step ' + (i + 1) + '/' + this.testSteps.length;
        const step = this.testSteps[i];
        this.appendLog('\n--- ' + step.label + ' ---');
        try {
          await step.run(this.renderSession!);
          await this.waitMs(2500);
        } catch (e) {
          this.appendLog('  ERROR: ' + (e instanceof Error ? e.message : String(e)));
        }
      }

      this.appendLog('\n=== COMPLETE ===');
      this.statusText = '测试完成';
    } catch (error) {
      this.appendLog('FATAL: ' + (error instanceof Error ? error.message : String(error)));
      this.statusText = '测试出错';
    } finally {
      this.isRunning = false;
      this.currentStep = -1;
    }
  }

  private waitMs(ms: number): Promise<void> {
    return new Promise<void>((resolve: Function) => {
      setTimeout(() => { resolve(); }, ms);
    });
  }

  build() {
    Scroll() {
      Column() {
        Text('ArkZero 渲染测试')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#fff')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 24, bottom: 8 })

        Text(this.statusText)
          .fontSize(14)
          .fontColor('#aaa')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ bottom: 12 })

        Column() {
          ArkZeroSurfaceView({
            config: {
              renderWidth: W,
              renderHeight: H,
              format: PixelFormat.BGRA,
              originRatioX: 0.0,
              originRatioY: 0.0,
              sizeRatioX: 1.0,
              enableTouch: false,
              xComponentId: 'render_test_surface'
            } as SurfaceViewConfig,
            onSurfaceLoaded: (surfaceId: string) => {
              hilog.info(DOMAIN, TAG, 'Surface loaded: %{public}s', surfaceId);
              const session = new ArkZeroRenderSession({
                width: W,
                height: H,
                format: PixelFormat.BGRA,
                onError: (msg: string) => {
                  this.appendLog('Session ERROR: ' + msg);
                }
              } as RenderSessionConfig);
              session.attach(surfaceId).then(() => {
                session.setVSync(false);
                this.renderSession = session;
                this.sessionReady = true;
                this.statusText = '就绪 - 点击下方按钮开始';
                this.appendLog('Session attached');
              }).catch((err: Error) => {
                this.sessionReady = false;
                this.statusText = 'Session加载失败';
                this.appendLog('Attach FAILED: ' + err.message);
              });
            }
          })
        }
        .width(W)
        .height(H)
        .backgroundColor('#000')
        .borderRadius(8)
        .clip(true)
        .alignItems(HorizontalAlign.Center)
        .margin({ bottom: 16 })

        Row() {
          Button('← 返回')
            .height(40)
            .fontSize(14)
            .backgroundColor('#555')
            .fontColor('#fff')
            .layoutWeight(1)
            .onClick(() => {
              try {
                this.getUIContext().getRouter().back();
              } catch (_) {}
            })

          Blank().width(16)

          Button(this.isRunning ? this.statusText : '开始测试')
            .height(40)
            .fontSize(14)
            .backgroundColor(this.isRunning ? '#666' : '#3366cc')
            .fontColor('#fff')
            .enabled(!this.isRunning && this.sessionReady)
            .layoutWeight(2)
            .onClick(() => {
              this.runAllTests();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
        .margin({ bottom: 12 })

        Text('测试日志')
          .fontSize(13)
          .fontColor('#888')
          .width('100%')
          .padding({ left: 16 })
          .margin({ bottom: 4 })

        Text(this.logText)
          .fontSize(11)
          .fontColor('#ccc')
          .fontFamily('monospace')
          .width('100%')
          .padding(16)
          .backgroundColor('#111')
          .borderRadius(8)
          .margin({ left: 16, right: 16, bottom: 24 })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#1a1a1a')
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }
}
