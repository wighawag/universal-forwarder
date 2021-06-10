import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {ForwarderRegistry} from '../typechain';
import {setupUser, setupUsers} from './utils';

const setup = deployments.createFixture(async () => {
  await deployments.fixture('ForwarderRegistry');

  const TestReceiverFactory = await ethers.getContractFactory('TestReceiver');
  const ForwarderRegistry = <ForwarderRegistry>(
    await ethers.getContract('ForwarderRegistry')
  );
  const TestReceiver = await TestReceiverFactory.deploy(
    ForwarderRegistry.address
  );
  const contracts = {
    ForwarderRegistry,
    TestReceiver,
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);
  return {
    ...contracts,
    users,
  };
});

describe('ForwarderRegistry', function () {
  it('isTrustedForwarder', async function () {
    const {ForwarderRegistry} = await setup();
    expect(
      await ForwarderRegistry.isTrustedForwarder(ForwarderRegistry.address)
    ).to.be.equal(true);
  });
  it('TestReceiver', async function () {
    const {users} = await setup();
    await users[0].TestReceiver.test(42);
  });
});
