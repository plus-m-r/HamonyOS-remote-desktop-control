import abilityTest from './Ability.test';
import simpleUnitTest from './SimpleUnitTest.test';
import utilsUnitTest from './Utils.test';
import modelsUnitTest from './Models.test';

export default function testsuite() {
  abilityTest();
  simpleUnitTest();
  utilsUnitTest();
  modelsUnitTest();
}
