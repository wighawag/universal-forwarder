import {expect} from './chai-setup';
import {ethers, deployments, getUnnamedAccounts} from 'hardhat';
import {ForwarderRegistry, TestSpecificForwarderReceiver__factory} from '../typechain';
import {setupUsers} from './utils';
import {ForwarderRegistrySignerFactory} from './utils/eip712';

const setup = deployments.createFixture(async () => {
	await deployments.fixture(['ForwarderRegistry']);

	const ForwarderRegistry = <ForwarderRegistry>await ethers.getContract('ForwarderRegistry');
	const TestSpecificForwarderReceiverFactory = <TestSpecificForwarderReceiver__factory>(
		await ethers.getContractFactory('TestSpecificForwarderReceiver')
	);
	const TestSpecificForwarderReceiver = await TestSpecificForwarderReceiverFactory.deploy(ForwarderRegistry.address);

	const contracts = {
		ForwarderRegistry,
		TestSpecificForwarderReceiver
	};

	const ForwarderRegistrySigner = ForwarderRegistrySignerFactory.createSigner({
		verifyingContract: contracts.ForwarderRegistry.address
	});

	const users = await setupUsers(await getUnnamedAccounts(), contracts);

	return {
		...contracts,
		users,
		ForwarderRegistrySigner
	};
});

describe('SpecificForwarder', function () {
	it('isTrustedForwarder', async function () {
		const {TestSpecificForwarderReceiver, ForwarderRegistry} = await setup();
		expect(await TestSpecificForwarderReceiver.isTrustedForwarder(ForwarderRegistry.address)).to.be.equal(true);
	});
	it('TestReceiver with msg.sender', async function () {
		const {users, TestSpecificForwarderReceiver} = await setup();
		await users[0].TestSpecificForwarderReceiver.test(42);
		const value = await TestSpecificForwarderReceiver.callStatic.getData(users[0].address);
		expect(value).to.equal(42);
	});
	it('TestReceiver with metatx', async function () {
		const {users, TestSpecificForwarderReceiver, ForwarderRegistry, ForwarderRegistrySigner} = await setup();
		const {to, data} = await users[0].TestSpecificForwarderReceiver.populateTransaction.test(42);
		if (!(to && data)) {
			throw new Error(`cannot populate transaction`);
		}
		const signature = await ForwarderRegistrySigner.sign(users[0], {
			signer: users[0].address,
			forwarder: users[1].address,
			approved: true,
			nonce: 0
		});

		const {data: relayerData} = await users[1].ForwarderRegistry.populateTransaction.checkApprovalAndForward(
			signature,
			false,
			to,
			data
		);

		await users[1].signer.sendTransaction({
			to: ForwarderRegistry.address,
			data: relayerData + users[0].address.slice(2)
		});

		const value = await TestSpecificForwarderReceiver.callStatic.getData(users[0].address);
		expect(value).to.equal(42);
	});
});
