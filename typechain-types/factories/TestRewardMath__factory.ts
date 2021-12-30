/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import { Provider, TransactionRequest } from "@ethersproject/providers";
import type {
  TestRewardMath,
  TestRewardMathInterface,
} from "../TestRewardMath";

const _abi = [
  {
    inputs: [
      {
        internalType: "uint256",
        name: "totalRewardUnclaimed",
        type: "uint256",
      },
      {
        internalType: "uint160",
        name: "totalSecondsClaimedX128",
        type: "uint160",
      },
      {
        internalType: "uint256",
        name: "startTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "endTime",
        type: "uint256",
      },
      {
        internalType: "uint128",
        name: "liquidity",
        type: "uint128",
      },
      {
        internalType: "uint160",
        name: "secondsPerLiquidityInsideAccruedX128",
        type: "uint160",
      },
      {
        internalType: "uint160",
        name: "secondsPerLiquidityInsideX128",
        type: "uint160",
      },
    ],
    name: "computeRewardAmount",
    outputs: [
      {
        internalType: "uint256",
        name: "reward",
        type: "uint256",
      },
      {
        internalType: "uint160",
        name: "secondsInsideX128",
        type: "uint160",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
];

const _bytecode =
  "0x608060405234801561001057600080fd5b506103ed806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c80639215dd5514610030575b600080fd5b61009d600480360360e081101561004657600080fd5b5080359073ffffffffffffffffffffffffffffffffffffffff60208201358116916040810135916060820135916fffffffffffffffffffffffffffffffff6080820135169160a082013581169160c00135166100cb565b6040805192835273ffffffffffffffffffffffffffffffffffffffff90911660208301528051918290030190f35b6000806100dd898989898989896100ed565b909a909950975050505050505050565b600080864210156100fa57fe5b86861161010357fe5b624f1a00878703111561011257fe5b61016361014b8473ffffffffffffffffffffffffffffffffffffffff168673ffffffffffffffffffffffffffffffffffffffff166101e5565b866fffffffffffffffffffffffffffffffff16610261565b905060006101b361019761018061017a8a426102db565b8b6101e5565b700100000000000000000000000000000000610261565b8a73ffffffffffffffffffffffffffffffffffffffff166101e5565b90506101d68a8373ffffffffffffffffffffffffffffffffffffffff16836102f2565b92505097509795505050505050565b60008282111561025657604080517f08c379a000000000000000000000000000000000000000000000000000000000815260206004820152601e60248201527f536166654d6174683a207375627472616374696f6e206f766572666c6f770000604482015290519081900360640190fd5b508082035b92915050565b6000826102705750600061025b565b8282028284828161027d57fe5b04146102d4576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260218152602001806103c06021913960400191505060405180910390fd5b9392505050565b6000818310156102eb57816102d4565b5090919050565b600080807fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff85870986860292508281109083900303905080610346576000841161033b57600080fd5b5082900490506102d4565b80841161035257600080fd5b6000848688096000868103871696879004966002600389028118808a02820302808a02820302808a02820302808a02820302808a02820302808a0290910302918190038190046001018684119095039490940291909403929092049190911791909102915050939250505056fe536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f77a164736f6c6343000706000a";

type TestRewardMathConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: TestRewardMathConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class TestRewardMath__factory extends ContractFactory {
  constructor(...args: TestRewardMathConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  deploy(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): Promise<TestRewardMath> {
    return super.deploy(overrides || {}) as Promise<TestRewardMath>;
  }
  getDeployTransaction(
    overrides?: Overrides & { from?: string | Promise<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  attach(address: string): TestRewardMath {
    return super.attach(address) as TestRewardMath;
  }
  connect(signer: Signer): TestRewardMath__factory {
    return super.connect(signer) as TestRewardMath__factory;
  }
  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): TestRewardMathInterface {
    return new utils.Interface(_abi) as TestRewardMathInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): TestRewardMath {
    return new Contract(address, _abi, signerOrProvider) as TestRewardMath;
  }
}