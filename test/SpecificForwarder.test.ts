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
    const value = await TestSpecificForwarderReceiver.callStatic.getData(
      users[0].address
    );
    expect(value).to.equal(42);
  });
  it('TestReceiver with metatx', async function () {
    const {users, TestSpecificForwarderReceiver, ForwarderRegistry} =
      await setup();
    const {to, data} =
      await users[0].TestSpecificForwarderReceiver.populateTransaction.test(42);
    if (!(to && data)) {
      throw new Error(`cannot populate transaction`);
    }
    const signature = await users[0].signer._signTypedData(
      {
        name: 'ForwarderRegistry',
        chainId: 31337,
        verifyingContract: ForwarderRegistry.address,
      },
      {
        ApproveForwarder: [
          {
            name: 'forwarder',
            type: 'address',
          },
          {
            name: 'approved',
            type: 'bool',
          },
          {
            name: 'nonce',
            type: 'uint256',
          },
        ],
      },
      {
        forwarder: users[1].address,
        approved: true,
        nonce: 0,
      }
    );

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

    const value = await TestSpecificForwarderReceiver.callStatic.getData(
      users[0].address
    );
    expect(value).to.equal(42);
  });
});
