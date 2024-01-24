// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import "forge-std/Test.sol";

import "../../../../contracts/interfaces/IBookManager.sol";
import "../../../../contracts/libraries/Hooks.sol";
import "../../../../contracts/BookManager.sol";
import "../../mocks/MockHooks.sol";
import "../../mocks/MockERC20.sol";
import "../../Constants.sol";
import "../../routers/MakeRouter.sol";
import "../../routers/TakeRouter.sol";

contract HooksTest is Test {
    using BookIdLibrary for IBookManager.BookKey;
    using Hooks for IHooks;

    address payable public ALL_HOOKS_ADDRESS = payable(0xfFf0000000000000000000000000000000000000);
    MockHooks public mockHooks;
    MockERC20 public mockErc20;

    IBookManager.BookKey public key;
    IBookManager.BookKey public unopenedKey;
    IBookManager public manager;
    MakeRouter public makeRouter;
    TakeRouter public takeRouter;

    // Update this value when you add a new hook flag. And then update all appropriate asserts.
    uint256 public hookPermissionCount = 12;
    uint256 public clearAllHookPermisssionsMask;

    function setUp() public {
        clearAllHookPermisssionsMask = uint256(~uint160(0) >> (hookPermissionCount));

        mockErc20 = new MockERC20("Mock", "MOCK", 18);

        MockHooks impl = new MockHooks();
        vm.etch(ALL_HOOKS_ADDRESS, address(impl).code);
        mockHooks = MockHooks(ALL_HOOKS_ADDRESS);

        key = IBookManager.BookKey({
            base: CurrencyLibrary.NATIVE,
            unit: 1e12,
            quote: Currency.wrap(address(mockErc20)),
            makerPolicy: IBookManager.FeePolicy({rate: 0, useOutput: true}),
            takerPolicy: IBookManager.FeePolicy({rate: 0, useOutput: true}),
            hooks: mockHooks
        });
        unopenedKey = key;
        unopenedKey.unit = 1e11;

        manager = new BookManager(address(this), Constants.DEFAULT_PROVIDER, "url", "name", "symbol");
        manager.open(key, "");

        makeRouter = new MakeRouter(manager);
        takeRouter = new TakeRouter(manager);
    }

    function testOpenSucceedsWithHook() public {
        manager.open(unopenedKey, new bytes(123));

        assertEq(mockHooks.beforeOpenData(), new bytes(123));
        assertEq(mockHooks.afterOpenData(), new bytes(123));
    }

    function testBeforeOpenInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.beforeOpen.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.open(unopenedKey, "");
    }

    function testAfterOpenInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.afterOpen.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.open(unopenedKey, "");
    }

    function testMakeSucceedsWithHook() public {
        MockERC20(Currency.unwrap(key.quote)).mint(address(this), 1e18);
        MockERC20(Currency.unwrap(key.quote)).approve(address(makeRouter), 1e18);
        makeRouter.make(IBookManager.MakeParams(key, Tick.wrap(0), 100, address(0)), new bytes(111));
        assertEq(mockHooks.beforeMakeData(), new bytes(111));
        assertEq(mockHooks.afterMakeData(), new bytes(111));
    }

    function _make() internal returns (OrderId id) {
        MockERC20(Currency.unwrap(key.quote)).mint(address(this), 1e18);
        MockERC20(Currency.unwrap(key.quote)).approve(address(makeRouter), 1e18);
        (id,) = makeRouter.make(IBookManager.MakeParams(key, Tick.wrap(0), 100, address(0)), "");
    }

    function testBeforeMakeInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.beforeMake.selector, bytes4(0xdeadbeef));
        MockERC20(Currency.unwrap(key.quote)).mint(address(this), 1e18);
        MockERC20(Currency.unwrap(key.quote)).approve(address(makeRouter), 1e18);
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        makeRouter.make(IBookManager.MakeParams(key, Tick.wrap(0), 100, address(0)), "");
    }

    function testAfterMakeInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.afterMake.selector, bytes4(0xdeadbeef));
        MockERC20(Currency.unwrap(key.quote)).mint(address(this), 1e18);
        MockERC20(Currency.unwrap(key.quote)).approve(address(makeRouter), 1e18);
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        makeRouter.make(IBookManager.MakeParams(key, Tick.wrap(0), 100, address(0)), "");
    }

    function testTakeSucceedsWithHook() public {
        _make();
        vm.deal(address(this), 1 ether);
        takeRouter.take(IBookManager.TakeParams(key, 1 ether), new bytes(222));

        assertEq(mockHooks.beforeTakeData(), new bytes(222));
        assertEq(mockHooks.afterTakeData(), new bytes(222));
    }

    function testBeforeTakeInvalidReturn() public {
        _make();
        vm.deal(address(this), 1 ether);

        mockHooks.setReturnValue(mockHooks.beforeTake.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        takeRouter.take(IBookManager.TakeParams(key, 1 ether), "");
    }

    function testAfterTakeInvalidReturn() public {
        _make();
        vm.deal(address(this), 1 ether);

        mockHooks.setReturnValue(mockHooks.afterTake.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        takeRouter.take(IBookManager.TakeParams(key, 1 ether), "");
    }

    function _take() internal {
        vm.deal(address(this), 1 ether);
        takeRouter.take(IBookManager.TakeParams(key, 1 ether), "");
    }

    function testCancelSucceedsWithHook() public {
        OrderId id = _make();
        manager.cancel(IBookManager.CancelParams(id, 0), new bytes(222));

        assertEq(mockHooks.beforeCancelData(), new bytes(222));
        assertEq(mockHooks.afterCancelData(), new bytes(222));
    }

    function testBeforeCancelInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.beforeCancel.selector, bytes4(0xdeadbeef));
        OrderId id = _make();
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.cancel(IBookManager.CancelParams(id, 0), new bytes(222));
    }

    function testAfterCancelInvalidReturn() public {
        mockHooks.setReturnValue(mockHooks.afterCancel.selector, bytes4(0xdeadbeef));
        OrderId id = _make();
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.cancel(IBookManager.CancelParams(id, 0), new bytes(222));
    }

    function testClaimSucceedsWithHook() public {
        OrderId id = _make();
        _take();
        manager.claim(id, new bytes(222));

        assertEq(mockHooks.beforeClaimData(), new bytes(222));
        assertEq(mockHooks.afterClaimData(), new bytes(222));
    }

    function testBeforeClaimInvalidReturn() public {
        OrderId id = _make();
        _take();
        mockHooks.setReturnValue(mockHooks.beforeClaim.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.claim(id, new bytes(222));
    }

    function testAfterClaimInvalidReturn() public {
        OrderId id = _make();
        _take();
        mockHooks.setReturnValue(mockHooks.afterClaim.selector, bytes4(0xdeadbeef));
        vm.expectRevert(Hooks.InvalidHookResponse.selector);
        manager.claim(id, new bytes(222));
    }

    // hook validation
    function testValidateHookAddressNoHooks(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);

        IHooks hookAddr = IHooks(address(preAddr));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeOpen(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);

        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_OPEN_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: true,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAfterOpen(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);

        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.AFTER_OPEN_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: true,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeAndAfterOpen(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_OPEN_FLAG | Hooks.AFTER_OPEN_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: true,
                afterOpen: true,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeMake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_MAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: true,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAfterMake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.AFTER_MAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: true,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeAndAfterMake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_MAKE_FLAG | Hooks.AFTER_MAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: true,
                afterMake: true,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeTake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_TAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: true,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAfterTake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.AFTER_TAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: true,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeAfterTake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_TAKE_FLAG | Hooks.AFTER_TAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: true,
                afterTake: true,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeOpenAfterMake(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_OPEN_FLAG | Hooks.AFTER_MAKE_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: true,
                afterOpen: false,
                beforeMake: false,
                afterMake: true,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeCancel(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_CANCEL_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: true,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAfterCancel(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.AFTER_CANCEL_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: true,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeAndAfterCancel(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_CANCEL_FLAG | Hooks.AFTER_CANCEL_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: true,
                afterCancel: true,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeClaim(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_CLAIM_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: true,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAfterClaim(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.AFTER_CLAIM_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: true,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressBeforeAndAfterClaim(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.BEFORE_CLAIM_FLAG | Hooks.AFTER_CLAIM_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: true,
                afterClaim: true,
                noOp: false,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAccessLock(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(address(uint160(preAddr | Hooks.ACCESS_LOCK_FLAG)));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: true
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressAllHooks(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        uint160 allHookBitsFlipped = (~uint160(0)) << uint160((160 - hookPermissionCount));
        IHooks hookAddr = IHooks(address(uint160(preAddr) | allHookBitsFlipped));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: true,
                afterOpen: true,
                beforeMake: true,
                afterMake: true,
                beforeTake: true,
                afterTake: true,
                beforeCancel: true,
                afterCancel: true,
                beforeClaim: true,
                afterClaim: true,
                noOp: true,
                accessLock: true
            })
        );
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressNoOp(uint160 addr) public {
        uint160 preAddr = uint160(uint256(addr) & clearAllHookPermisssionsMask);
        IHooks hookAddr = IHooks(
            address(
                uint160(
                    preAddr | Hooks.BEFORE_MAKE_FLAG | Hooks.BEFORE_CANCEL_FLAG | Hooks.BEFORE_CLAIM_FLAG
                        | Hooks.NO_OP_FLAG
                )
            )
        );
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: true,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: true,
                afterCancel: false,
                beforeClaim: true,
                afterClaim: false,
                noOp: true,
                accessLock: false
            })
        );
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_OPEN_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_OPEN_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_MAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.BEFORE_TAKE_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_TAKE_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CANCEL_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CANCEL_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.BEFORE_CLAIM_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.AFTER_CLAIM_FLAG));
        assertTrue(hookAddr.hasPermission(Hooks.NO_OP_FLAG));
        assertFalse(hookAddr.hasPermission(Hooks.ACCESS_LOCK_FLAG));
    }

    function testValidateHookAddressFailsAllHooks(uint152 addr, uint8 mask) public {
        uint160 preAddr = uint160(uint256(addr));
        vm.assume(mask != 0xff8);
        IHooks hookAddr = IHooks(address(uint160(preAddr) | (uint160(mask) << 151)));
        vm.expectRevert(abi.encodeWithSelector(Hooks.HookAddressNotValid.selector, (address(hookAddr))));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: true,
                afterOpen: true,
                beforeMake: true,
                afterMake: true,
                beforeTake: false,
                afterTake: false,
                beforeCancel: true,
                afterCancel: true,
                beforeClaim: true,
                afterClaim: true,
                noOp: true,
                accessLock: true
            })
        );
    }

    function testValidateHookAddressFailsNoHooks(uint160 addr, uint16 mask) public {
        uint160 preAddr = addr & uint160(0x007ffffFfffffffffFffffFFfFFFFFFffFFfFFff);
        mask = mask & 0xff80; // the last 7 bits are all 0, we just want a 9 bit mask
        vm.assume(mask != 0); // we want any combination except no hooks
        IHooks hookAddr = IHooks(address(preAddr | (uint160(mask) << 144)));
        vm.expectRevert(abi.encodeWithSelector(Hooks.HookAddressNotValid.selector, (address(hookAddr))));
        Hooks.validateHookPermissions(
            hookAddr,
            Hooks.Permissions({
                beforeOpen: false,
                afterOpen: false,
                beforeMake: false,
                afterMake: false,
                beforeTake: false,
                afterTake: false,
                beforeCancel: false,
                afterCancel: false,
                beforeClaim: false,
                afterClaim: false,
                noOp: false,
                accessLock: false
            })
        );
    }

    function test_isValidHookAddressAnyFlags() public {
        assertTrue(Hooks.isValidHookAddress(IHooks(0x8000000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x4000000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x2000000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x1000000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x0800000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x0200000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0x0100000000000000000000000000000000000000)));
        assertTrue(Hooks.isValidHookAddress(IHooks(0xf09840a85d5Af5bF1d1762f925bdaDdC4201f984)));
    }

    function testIsValidHookAddressZeroAddress() public {
        assertTrue(Hooks.isValidHookAddress(IHooks(address(0))));
    }

    function test_invalidIfNoFlags() public {
        assertFalse(Hooks.isValidHookAddress(IHooks(0x0000000000000000000000000000000000000001)));
        assertFalse(Hooks.isValidHookAddress(IHooks(0x0020000000000000000000000000000000000001)));
        assertFalse(Hooks.isValidHookAddress(IHooks(0x003840a85d5Af5Bf1d1762F925BDADDc4201f984)));
    }

    receive() external payable {}
}