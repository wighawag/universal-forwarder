import {EIP712SignerFactory} from '.';

export const ForwarderRegistrySignerFactory = new EIP712SignerFactory(
  {
    name: 'ForwarderRegistry',
    chainId: 0,
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
  }
);

export const UniversalForwarderSignerFactory = new EIP712SignerFactory(
  {
    name: 'UniversalForwarder',
    chainId: 0,
  },
  {
    ApproveForwarderForever: [
      {
        name: 'forwarder',
        type: 'address',
      },
    ],
  }
);
