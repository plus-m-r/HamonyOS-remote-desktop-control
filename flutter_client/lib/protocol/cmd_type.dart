/// 命令类型枚举。
///
/// 每个值的【序号】(index) 就是帧头 cmdType 字节的取值，
/// 顺序与 Java 端 CmdType.java 完全一致，禁止调整顺序！
/// （序号 = 服务器识别命令的唯一依据，乱序会导致协议断裂）
enum CmdType {
  /// 心跳请求：客户端定时发给服务器，确认连接还活着
  reqPing, // 0

  /// 会话打开请求：控制端请求建立远程控制会话
  reqOpen, // 1

  /// 截屏控制：控制端请求开始/停止被控端截屏（携带设备码+密码+操作码）
  reqCapture, // 2

  /// 请求远程剪贴板：控制端请求读取被控端剪贴板
  reqRemoteClipboard, // 3

  /// 会话打开回应：服务器/被控端回复"同意/拒绝"
  resOpen, // 4

  /// 设备信息回应：回复本机设备码和密码（本机设置区显示的数据来源）
  resCliInfo, // 5

  /// 截屏回应：被控端回复"开始截屏了/失败原因"
  resCapture, // 6

  /// 心跳回应：对 reqPing 的应答
  resPong, // 7

  /// 远程剪贴板回应：返回被控端剪贴板内容
  resRemoteClipboard, // 8

  /// 屏幕画面数据：被控端一帧一帧传来的屏幕内容（核心流量）
  capture, // 9

  /// 压缩器配置：调整压缩方式（ZSTD/ZIP/XZ 等）
  compressorConfig, // 10

  /// 截屏参数配置：调整分辨率/帧率/瓦片大小等
  captureConfig, // 11

  /// 键盘控制：把按键操作发给被控端执行
  keyControl, // 12

  /// 鼠标控制：把鼠标移动/点击/滚轮发给被控端执行
  mouseControl, // 13

  /// 剪贴板文本：传输剪贴板的文字内容
  clipboardText, // 14

  /// 剪贴板文件：传输剪贴板的文件（配合 REST 上传下载）
  clipboardTransfer, // 15

  /// 请求设备信息：询问对方"你的设备码和密码是什么"
  reqCliInfo, // 16

  /// 屏幕切换：多显示器时切换查看哪块屏幕
  selectScreen, // 17

  /// 改密码：把临时密码修改为新值
  changePwd, // 18
}
