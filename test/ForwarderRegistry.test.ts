import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';

const setup = deployments.createFixture(async () => {
  await deployments.fixture('ForwarderRegistry');
  const others = await getUnnamedAccounts();
  return {
    ForwarderRegistry: await ethers.getContract('ForwarderRegistry'),
    others: others.map((acc: string) => {
      return {address: acc};
    }),
  };
});

describe('ForwarderRegistry', function () {
  it('isTrustedForwarder', async function () {
    const {ForwarderRegistry} = await setup();
    expect(
      await ForwarderRegistry.isTrustedForwarder(ForwarderRegistry.address)
    ).to.be.equal(true);
  });
});
