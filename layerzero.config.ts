import { EndpointId } from '@layerzerolabs/lz-definitions'

import type { OAppOmniGraphHardhat, OmniPointHardhat } from '@layerzerolabs/toolbox-hardhat'

/**
 *  WARNING: ONLY 1 OFTAdapter should exist for a given global mesh.
 *  The token address for the adapter should be defined in hardhat.config. This will be used in deployment.
 *
 *  for example:
 *
 *    sepolia: {
 *         eid: EndpointId.SEPOLIA_V2_TESTNET,
 *         url: process.env.RPC_URL_SEPOLIA || 'https://rpc.sepolia.org/',
 *         accounts,
 *         oft-adapter: {
 *             tokenAddress: '0x0', // Set the token address for the OFT adapter
 *         },
 *     },
 */
const sepoliaContract: OmniPointHardhat = {
    eid: EndpointId.SEPOLIA_V2_TESTNET,
    contractName: 'MyOFTAdapter',
}

const sepoliaArbiContract: OmniPointHardhat = {
    eid: 40231,
    contractName: 'MyOFT',
}



const config: OAppOmniGraphHardhat = {
    contracts: [
        {
            contract: sepoliaArbiContract,
        },
        {
            contract: sepoliaContract,
        }
    ],
    connections: [
        {
            from: sepoliaArbiContract,
            to: sepoliaContract,
        },
        {
            from: sepoliaContract,
            to: sepoliaArbiContract,
        },
    ],
}

export default config
