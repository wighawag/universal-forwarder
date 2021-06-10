import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {
  ForwarderRegistry,
  NoStorageUniversalForwarder,
  TestUniversalForwardingReceiver__factory,
} from '../typechain';
import {setupUsers} from './utils';
import {ForwarderRegistrySignerFactory} from './utils/eip712';

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

  const ForwarderRegistrySigner = ForwarderRegistrySignerFactory.createSigner({
    verifyingContract: contracts.ForwarderRegistry.address,
  });

  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
    ForwarderRegistrySigner,
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

  it('TestReceiver with metatx', async function () {
    const {
      users,
      TestUniversalForwardingReceiver,
      ForwarderRegistry,
      ForwarderRegistrySigner,
    } = await setup();
    const {to, data} =
      await users[0].TestUniversalForwardingReceiver.populateTransaction.test(
        42
      );
    if (!(to && data)) {
      throw new Error(`cannot populate transaction`);
    }
    const signature = await ForwarderRegistrySigner.sign(users[0], {
      forwarder: users[1].address,
      approved: true,
      nonce: 0,
    });

    const {data: relayerData} =
      await users[1].ForwarderRegistry.populateTransaction.checkApprovalAndForward(
        signature,
        0,
        to,
        data
      );

    await users[1].signer.sendTransaction({
      to: ForwarderRegistry.address,
      data: relayerData + users[0].address.slice(2),
    });

    const value = await TestUniversalForwardingReceiver.callStatic.getData(
      users[0].address
    );
    expect(value).to.equal(42);
  });
});
