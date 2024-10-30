import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'
import { getChain, isDevelopmentNetwork } from '@nomicfoundation/hardhat-viem/internal/chains'
import { deployWithVerify } from '../utils'
import { Address } from 'viem'

const deployFunction: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts, network } = hre
  const deployer = (await getNamedAccounts())['deployer'] as Address
  const chain = await getChain(network.provider)

  if (await deployments.getOrNull('BookManager')) {
    return
  }

  let bookLibraryAddress = (await deployments.getOrNull('Book'))?.address
  if (!bookLibraryAddress) {
    bookLibraryAddress = await deployWithVerify(hre, 'Book', [])
  }

  let owner: Address = '0x'
  let defaultProvider: Address = '0x'
  if (chain.testnet || isDevelopmentNetwork(chain.id)) {
    owner = defaultProvider = deployer
  } else {
    throw new Error('Unknown chain')
  }

  await deployWithVerify(
    hre,
    'BookManager',
    [
      owner,
      defaultProvider,
      `https://berabook.fun/api/nft/chains/${chain.id}/orders/`,
      `https://berabook.fun/api/contract/chains/${chain.id}`,
      'BeraBook Orderbook Maker Order',
      'BERABOOK-ORDER',
    ],
    {
      libraries: {
        Book: bookLibraryAddress,
      },
    },
  )
}

deployFunction.tags = ['BookManager']
deployFunction.dependencies = []
export default deployFunction
