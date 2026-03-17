import localUnitTest from './LocalUnit.test';
import clipboardServiceTest from './ClipboardService.test';
import fileServiceTest from './FileService.test';
import remoteControlServiceTest from './RemoteControlService.test';

export default function testsuite() {
  localUnitTest();
  clipboardServiceTest();
  fileServiceTest();
  remoteControlServiceTest();
}