import {HardhatRuntimeEnvironment} from 'hardhat/types';
import {DeployFunction} from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
	const {deployments, getNamedAccounts} = hre;
	const {deploy} = deployments;

	const {deployer} = await getNamedAccounts();

	await deploy('UniversalForwarder', {
		from: deployer,
		log: true,
		deterministicDeployment: true
	});
};
export default func;
func.tags = ['UniversalForwarder'];
