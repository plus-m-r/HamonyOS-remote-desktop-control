import worker from '@ohos.worker';

// 定义消息类型
interface HeartbeatConfigMessage {
  type: 'config';
  interval: number;  // 心跳间隔（毫秒）
}

interface StartHeartbeatMessage {
  type: 'start';
}

interface StopHeartbeatMessage {
  type: 'stop';
}

interface HeartbeatTickMessage {
  type: 'tick';
  timestamp: number;
}

type WorkerMessage = HeartbeatConfigMessage | StartHeartbeatMessage | StopHeartbeatMessage;

// Worker 内部状态
let heartbeatTimer: number = -1;
let heartbeatInterval: number = 3000; // 默认3秒
let isRunning: boolean = false;

// 初始化 Worker
const workerPort = worker.workerPort;

// 发送心跳 tick 到主线程
function sendHeartbeatTick(): void {
  const message: HeartbeatTickMessage = {
    type: 'tick',
    timestamp: Date.now()
  };
  workerPort.postMessage(message);
}

// 启动心跳定时器
function startHeartbeatTimer(): void {
  // 清除之前的定时器
  if (heartbeatTimer !== -1) {
    clearInterval(heartbeatTimer);
  }
  
  isRunning = true;
  
  // 立即发送第一次心跳
  sendHeartbeatTick();
  
  // 设置定时器
  heartbeatTimer = setInterval(() => {
    if (isRunning) {
      sendHeartbeatTick();
    }
  }, heartbeatInterval);
}

// 停止心跳定时器
function stopHeartbeatTimer(): void {
  isRunning = false;
  if (heartbeatTimer !== -1) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = -1;
  }
}

// 处理消息
workerPort.onmessage = (message: MessageEvent) => {
  const data = message.data as WorkerMessage;
  
  switch (data.type) {
    case 'config':
      // 配置心跳间隔
      heartbeatInterval = data.interval;
      console.log(`HeartbeatWorker: Configured interval to ${heartbeatInterval}ms`);
      break;
      
    case 'start':
      // 启动心跳
      console.log('HeartbeatWorker: Starting heartbeat');
      startHeartbeatTimer();
      break;
      
    case 'stop':
      // 停止心跳
      console.log('HeartbeatWorker: Stopping heartbeat');
      stopHeartbeatTimer();
      break;
      
    default:
      console.warn('HeartbeatWorker: Unknown message type');
  }
};

// Worker 终止时清理资源
workerPort.onclose = () => {
  console.log('HeartbeatWorker: Closing, cleaning up resources');
  stopHeartbeatTimer();
};

console.log('HeartbeatWorker: Initialized');
