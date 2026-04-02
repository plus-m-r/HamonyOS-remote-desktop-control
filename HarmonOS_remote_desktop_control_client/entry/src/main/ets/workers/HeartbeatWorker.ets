import worker, { MessageEvent } from '@ohos.worker';

// 定义消息类型
interface HeartbeatConfigMessage {
  type: 'config';
  interval: number;
}

interface StartHeartbeatMessage {
  type: 'start';
}

interface StopHeartbeatMessage {
  type: 'stop';
}

interface CloseWorkerMessage {
  type: 'close';
}

interface HeartbeatTickMessage {
  type: 'tick';
  timestamp: number;
}

type WorkerMessage = HeartbeatConfigMessage | StartHeartbeatMessage | StopHeartbeatMessage | CloseWorkerMessage;

// Worker 内部状态
let heartbeatTimer: number = -1;
let heartbeatInterval: number = 3000;
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
  if (heartbeatTimer !== -1) {
    clearInterval(heartbeatTimer);
  }
  
  isRunning = true;
  sendHeartbeatTick();
  
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
workerPort.onmessage = (message: MessageEvent<WorkerMessage>) => {
  const data: WorkerMessage = message.data;
  
  switch (data.type) {
    case 'config':
      heartbeatInterval = data.interval;
      console.log(`HeartbeatWorker: Configured interval to ${heartbeatInterval}ms`);
      break;
      
    case 'start':
      console.log('HeartbeatWorker: Starting heartbeat');
      startHeartbeatTimer();
      break;
      
    case 'stop':
      console.log('HeartbeatWorker: Stopping heartbeat');
      stopHeartbeatTimer();
      break;
      
    case 'close':
      console.log('HeartbeatWorker: Closing, cleaning up resources');
      stopHeartbeatTimer();
      workerPort.close();
      break;
      
    default:
      console.warn('HeartbeatWorker: Unknown message type');
  }
};

console.log('HeartbeatWorker: Initialized');