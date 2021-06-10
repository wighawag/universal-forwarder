import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {
  ForwarderRegistry,
  TestSpecificForwarderReceiver__factory,
} from '../typechain';
import {setupUsers} from './utils';

const setup = deployments.createFixture(async () => {
  await deployments.fixture(['ForwarderRegistry']);

  const ForwarderRegistry = <ForwarderRegistry>(
    await ethers.getContract('ForwarderRegistry')
  );
  const TestSpecificForwarderReceiverFactory = <
    TestSpecificForwarderReceiver__factory
  >await ethers.getContractFactory('TestSpecificForwarderReceiver');
  const TestSpecificForwarderReceiver =
    await TestSpecificForwarderReceiverFactory.deploy(
      ForwarderRegistry.address
    );

  const contracts = {
    ForwarderRegistry,
    TestSpecificForwarderReceiver,
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
  };
});

describe('SpecificForwarder', function () {
  it('isTrustedForwarder', async function () {
    const {TestSpecificForwarderReceiver, ForwarderRegistry} = await setup();
    expect(
      await TestSpecificForwarderReceiver.isTrustedForwarder(
        ForwarderRegistry.address
      )
    ).to.be.equal(true);
  });
  it('TestReceiver with msg.sender', async function () {
    const {users, TestSpecificForwarderReceiver} = await setup();
    await users[0].TestSpecificForwarderReceiver.test(42);
    const data = await TestSpecificForwarderReceiver.callStatic.getData(
      users[0].address
    );
    expect(data).to.equal(42);
  });
  it('TestReceiver with metatx', async function () {
    const {users, TestSpecificForwarderReceiver} = await setup();
    await users[0].TestSpecificForwarderReceiver.test(42);
    const data = await TestSpecificForwarderReceiver.callStatic.getData(
      users[0].address
    );
    expect(data).to.equal(42);
  });
});
