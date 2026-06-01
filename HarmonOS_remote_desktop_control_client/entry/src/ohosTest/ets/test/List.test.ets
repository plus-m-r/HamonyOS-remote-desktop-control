import UtilsUnitTest from './utils/Utils.test';
import ModelsUnitTest from './models/Models.test';
import ConfigCenterTest from './config/ConfigCenter.test';
import ModelsExtendedTest from './models/ModelsExtended.test';
import ServicesInterfacesTest from './services/ServicesInterfaces.test';
import AppStateManagerTest from './state/AppStateManager.test';
import SqueezeComponentsUnitTest from './squeeze/SqueezeComponents.test';

export default function testsuite() {
  UtilsUnitTest();
  ModelsUnitTest();
  ConfigCenterTest();
  ModelsExtendedTest();
  ServicesInterfacesTest();
  AppStateManagerTest();
  SqueezeComponentsUnitTest();
}
