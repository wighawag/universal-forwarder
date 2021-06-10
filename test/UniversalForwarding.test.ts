import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {
  ForwarderRegistry,
  NoStorageUniversalForwarder,
  TestUniversalForwardingReceiver__factory,
} from '../typechain';
import {setupUsers} from './utils';

const setup = deployments.createFixture(async () => {
  await deployments.fixture([
    'ForwarderRegistry',
    'NoStorageUniversalForwarder',
  ]);

  const ForwarderRegistry = <ForwarderRegistry>(
    await ethers.getContract('ForwarderRegistry')
  );
  const NoStorageUniversalForwarder = <NoStorageUniversalForwarder>(
    await ethers.getContract('NoStorageUniversalForwarder')
  );
  const TestUniversalForwardingReceiverFactory = <
    TestUniversalForwardingReceiver__factory
  >await ethers.getContractFactory('TestUniversalForwardingReceiver');
  const TestUniversalForwardingReceiver =
    await TestUniversalForwardingReceiverFactory.deploy(
      ForwarderRegistry.address,
      NoStorageUniversalForwarder.address
    );
  const contracts = {
    NoStorageUniversalForwarder,
    ForwarderRegistry,
    TestUniversalForwardingReceiver,
  };
  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
  };
});

describe('UniversalForwarding', function () {
  it('isTrustedForwarder', async function () {
    const {ForwarderRegistry} = await setup();
    expect(
      await ForwarderRegistry.isTrustedForwarder(ForwarderRegistry.address)
    ).to.be.equal(true);
  });
  it('TestReceiver with msg.sender', async function () {
    const {users, TestUniversalForwardingReceiver} = await setup();
    await users[0].TestUniversalForwardingReceiver.test(42);
    const data = await TestUniversalForwardingReceiver.callStatic.getData(
      users[0].address
    );
    expect(data).to.equal(42);
  });
});
