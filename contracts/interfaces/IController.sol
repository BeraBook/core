// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../libraries/OrderId.sol";
import "../libraries/Currency.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

interface IController {
    error InvalidAccess();
    error InvalidLength();
    error Deadline();
    error InvalidMarket();
    error ControllerSlippage();
    error ValueTransferFailed();
    error InvalidAction();

    enum Action {
        MAKE,
        TAKE,
        SPEND,
        CLAIM,
        CANCEL
    }

    struct ERC20PermitParams {
        address token;
        uint256 permitAmount;
        PermitSignature signature;
    }

    struct ERC721PermitParams {
        uint256 tokenId;
        PermitSignature signature;
    }

    struct PermitSignature {
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Todo Consider maker
    struct MakeOrderParams {
        BookId id;
        Tick tick;
        uint256 quoteAmount;
        uint256 claimBounty;
        bytes hookData;
    }

    // Todo Consider recipient
    struct TakeOrderParams {
        BookId id;
        uint256 limitPrice;
        uint256 quoteAmount;
        uint256 maxBaseAmount;
        bytes hookData;
    }

    // Todo Consider recipient
    struct SpendOrderParams {
        BookId id;
        uint256 limitPrice;
        uint256 baseAmount;
        uint256 minQuoteAmount;
        bytes hookData;
    }

    struct ClaimOrderParams {
        OrderId id;
        bytes hookData;
    }

    struct CancelOrderParams {
        OrderId id;
        uint256 leftQuoteAmount;
        bytes hookData;
    }

    function getDepth(BookId id, Tick tick) external view returns (uint256);

    function getLowestPrice(BookId id) external view returns (uint256);

    function getOrder(OrderId orderId)
        external
        view
        returns (address provider, uint256 price, uint256 openAmount, uint256 claimableAmount);

    function fromPrice(uint256 price) external pure returns (Tick);

    function toPrice(Tick tick) external pure returns (uint256);

    function execute(
        Action[] calldata actionList,
        bytes[] calldata paramsDataList,
        address[] calldata tokensToSettle,
        ERC20PermitParams[] calldata erc20PermitParamsList,
        ERC721PermitParams[] calldata erc721PermitParamsList,
        uint64 deadline
    ) external payable returns (OrderId[] memory ids);

    function make(
        MakeOrderParams[] calldata orderParamsList,
        address[] calldata tokensToSettle,
        ERC20PermitParams[] calldata permitParamsList,
        uint64 deadline
    ) external payable returns (OrderId[] memory ids);

    function take(
        TakeOrderParams[] calldata orderParamsList,
        address[] calldata tokensToSettle,
        ERC20PermitParams[] calldata permitParamsList,
        uint64 deadline
    ) external payable;

    function spend(
        SpendOrderParams[] calldata orderParamsList,
        address[] calldata tokensToSettle,
        ERC20PermitParams[] calldata permitParamsList,
        uint64 deadline
    ) external payable;

    function claim(ClaimOrderParams[] calldata orderParamsList, uint64 deadline) external;

    function cancel(
        CancelOrderParams[] calldata orderParamsList,
        ERC721PermitParams[] calldata permitParamsList,
        uint64 deadline
    ) external;

    //    function makeAfterClaim(
    //        ClaimOrderParams[] calldata claimOrderParamsList,
    //        MakeOrderParams[] calldata makeOrderParamsList
    //    ) external;
    //
    //    function takeAfterClaim(
    //        ClaimOrderParams[] calldata claimOrderParamsList,
    //        TakeOrderParams[] calldata takeOrderParamsList
    //    ) external;
    //
    //    function spendAfterClaim(
    //        ClaimOrderParams[] calldata claimOrderParamsList,
    //        SpendOrderParams[] calldata spendOrderParamsList
    //    ) external;
}