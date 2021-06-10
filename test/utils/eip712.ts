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
