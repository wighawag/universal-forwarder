import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {Contract} from '@ethersproject/contracts';

async function setupUsers<T extends {[contractName: string]: Contract}>(
  addresses: string[],
  contracts: T
): Promise<({address: string} & T)[]> {
  const users: ({address: string} & T)[] = [];
  for (const address of addresses) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const user: any = {address};
    for (const key of Object.keys(contracts)) {
      user[key] = contracts[key].connect(await ethers.getSigner(address));
    }
    users.push(user);
  }
  return users;
}

const setup = deployments.createFixture(async () => {
  await deployments.fixture('ForwarderRegistry');
  const users = await getUnnamedAccounts();
  const ForwarderRegistry = await ethers.getContract('ForwarderRegistry');

  const TestReceiverFactory = await ethers.getContractFactory('TestReceiver');
  const TestReceiver = await TestReceiverFactory.deploy(
    ForwarderRegistry.address
  );

  return {
    ForwarderRegistry,
    users: await setupUsers(users, {ForwarderRegistry, TestReceiver}),
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
