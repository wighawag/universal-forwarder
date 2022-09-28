import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {
  ForwarderRegistry,
  UniversalForwarder,
  TestUniversalForwardingReceiver__factory,
} from '../typechain';
import {setupUsers} from './utils';
import {
  ForwarderRegistrySignerFactory,
  UniversalForwarderSignerFactory,
} from './utils/eip712';

const setup = deployments.createFixture(async () => {
  await deployments.fixture(['ForwarderRegistry', 'UniversalForwarder']);

  const ForwarderRegistry = <ForwarderRegistry>(
    await ethers.getContract('ForwarderRegistry')
  );
  const UniversalForwarder = <UniversalForwarder>(
    await ethers.getContract('UniversalForwarder')
  );
  const TestUniversalForwardingReceiverFactory = <
    TestUniversalForwardingReceiver__factory
  >await ethers.getContractFactory('TestUniversalForwardingReceiver');
  const TestUniversalForwardingReceiver =
    await TestUniversalForwardingReceiverFactory.deploy(
      ForwarderRegistry.address,
      UniversalForwarder.address
    );
  const contracts = {
    UniversalForwarder,
    ForwarderRegistry,
    TestUniversalForwardingReceiver,
  };

  const ForwarderRegistrySigner = ForwarderRegistrySignerFactory.createSigner({
    verifyingContract: contracts.ForwarderRegistry.address,
  });

  const UniversalForwarderSigner = UniversalForwarderSignerFactory.createSigner(
    {
      verifyingContract: UniversalForwarder.address,
    }
  );

  const users = await setupUsers(await getUnnamedAccounts(), contracts);

  return {
    ...contracts,
    users,
    ForwarderRegistrySigner,
    UniversalForwarderSigner,
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

  it('TestReceiver empty func with msg.sender', async function () {
    const {users, TestUniversalForwardingReceiver} = await setup();
    await users[0].TestUniversalForwardingReceiver.twelve();
    const data = await TestUniversalForwardingReceiver.callStatic.getData(
      users[0].address
    );
    expect(data).to.equal(12);
  });

  it('TestReceiver fallback with msg.sender', async function () {
    const {users, TestUniversalForwardingReceiver} = await setup();
    await users[0].signer.sendTransaction({
      to: TestUniversalForwardingReceiver.address,
    });
    const data = await TestUniversalForwardingReceiver.callStatic.getData(
      users[0].address
    );
    expect(data).to.equal(1);
  });

  it('ForwarderRegistry metatx', async function () {
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
      signer: users[0].address,
      forwarder: users[1].address,
      approved: true,
      nonce: 0,
    });

    const {data: relayerData} =
      await users[1].ForwarderRegistry.populateTransaction.checkApprovalAndForward(
        signature,
        false,
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

  it('UniversalForwarder metatx', async function () {
    const {
      users,
      TestUniversalForwardingReceiver,
      UniversalForwarder,
      UniversalForwarderSigner,
    } = await setup();
    const {to, data} =
      await users[0].TestUniversalForwardingReceiver.populateTransaction.test(
        42
      );
    if (!(to && data)) {
      throw new Error(`cannot populate transaction`);
    }
    const signature = await UniversalForwarderSigner.sign(users[0], {
      signer: users[0].address,
      forwarder: users[1].address,
    });

    const {data: relayerData} =
      await users[1].UniversalForwarder.populateTransaction.forward(
        signature,
        false,
        to,
        data
      );

    await users[1].signer.sendTransaction({
      to: UniversalForwarder.address,
      data: relayerData + users[0].address.slice(2),
    });

    const value = await TestUniversalForwardingReceiver.callStatic.getData(
      users[0].address
    );
    expect(value).to.equal(42);
  });
});
