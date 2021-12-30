/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import { FunctionFragment, Result } from "@ethersproject/abi";
import { Listener, Provider } from "@ethersproject/providers";
import { TypedEventFilter, TypedEvent, TypedListener, OnEvent } from "./common";

export interface TestRewardMathInterface extends utils.Interface {
  functions: {
    "computeRewardAmount(uint256,uint160,uint256,uint256,uint128,uint160,uint160)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "computeRewardAmount",
    values: [
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish,
      BigNumberish
    ]
  ): string;

  decodeFunctionResult(
    functionFragment: "computeRewardAmount",
    data: BytesLike
  ): Result;

  events: {};
}

export interface TestRewardMath extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: TestRewardMathInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    computeRewardAmount(
      totalRewardUnclaimed: BigNumberish,
      totalSecondsClaimedX128: BigNumberish,
      startTime: BigNumberish,
      endTime: BigNumberish,
      liquidity: BigNumberish,
      secondsPerLiquidityInsideAccruedX128: BigNumberish,
      secondsPerLiquidityInsideX128: BigNumberish,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber] & {
        reward: BigNumber;
        secondsInsideX128: BigNumber;
      }
    >;
  };

  computeRewardAmount(
    totalRewardUnclaimed: BigNumberish,
    totalSecondsClaimedX128: BigNumberish,
    startTime: BigNumberish,
    endTime: BigNumberish,
    liquidity: BigNumberish,
    secondsPerLiquidityInsideAccruedX128: BigNumberish,
    secondsPerLiquidityInsideX128: BigNumberish,
    overrides?: CallOverrides
  ): Promise<
    [BigNumber, BigNumber] & { reward: BigNumber; secondsInsideX128: BigNumber }
  >;

  callStatic: {
    computeRewardAmount(
      totalRewardUnclaimed: BigNumberish,
      totalSecondsClaimedX128: BigNumberish,
      startTime: BigNumberish,
      endTime: BigNumberish,
      liquidity: BigNumberish,
      secondsPerLiquidityInsideAccruedX128: BigNumberish,
      secondsPerLiquidityInsideX128: BigNumberish,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber] & {
        reward: BigNumber;
        secondsInsideX128: BigNumber;
      }
    >;
  };

  filters: {};

  estimateGas: {
    computeRewardAmount(
      totalRewardUnclaimed: BigNumberish,
      totalSecondsClaimedX128: BigNumberish,
      startTime: BigNumberish,
      endTime: BigNumberish,
      liquidity: BigNumberish,
      secondsPerLiquidityInsideAccruedX128: BigNumberish,
      secondsPerLiquidityInsideX128: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    computeRewardAmount(
      totalRewardUnclaimed: BigNumberish,
      totalSecondsClaimedX128: BigNumberish,
      startTime: BigNumberish,
      endTime: BigNumberish,
      liquidity: BigNumberish,
      secondsPerLiquidityInsideAccruedX128: BigNumberish,
      secondsPerLiquidityInsideX128: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}
