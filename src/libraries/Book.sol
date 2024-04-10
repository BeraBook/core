// SPDX-License-Identifier: -
// License: https://license.clober.io/LICENSE_V2.pdf

pragma solidity ^0.8.20;

import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {IBookManager} from "../interfaces/IBookManager.sol";
import {SegmentedSegmentTree} from "./SegmentedSegmentTree.sol";
import {Tick, TickLibrary} from "./Tick.sol";
import {OrderId, OrderIdLibrary} from "./OrderId.sol";
import {TotalClaimableMap} from "./TotalClaimableMap.sol";
import {TickBitmap} from "./TickBitmap.sol";

library Book {
    using Book for State;
    using TickBitmap for mapping(uint256 => uint256);
    using SegmentedSegmentTree for SegmentedSegmentTree.Core;
    using TotalClaimableMap for mapping(uint24 => uint256);
    using TickLibrary for Tick;
    using OrderIdLibrary for OrderId;

    error ZeroAmount();
    error BookAlreadyOpened();
    error BookNotOpened();
    error OrdersOutOfRange();
    error QueueReplaceFailed();
    error TooLargeTakeAmount();
    error CancelFailed(uint64 maxCancelableAmount);

    // @dev Due to the segment tree implementation, the maximum order size is 2 ** 15.
    uint40 internal constant MAX_ORDER = 2 ** 15; // 32768
    uint256 internal constant MAX_ORDER_M = 2 ** 15 - 1; // % 32768

    struct Order {
        address provider;
        uint64 pending; // @dev unfilled amount + filled(claimable) amount
    }

    struct Queue {
        SegmentedSegmentTree.Core tree;
        Order[] orders;
    }

    struct State {
        IBookManager.BookKey key;
        mapping(Tick tick => Queue) queues;
        mapping(uint256 => uint256) tickBitmap;
        // @dev Four values of totalClaimable are stored in one uint256
        mapping(uint24 groupIndex => uint256) totalClaimableOf;
    }

    function open(State storage self, IBookManager.BookKey calldata key) external {
        if (self.isOpened()) revert BookAlreadyOpened();
        self.key = key;
    }

    function isOpened(State storage self) internal view returns (bool) {
        return self.key.unit != 0;
    }

    function checkOpened(State storage self) internal view {
        if (!self.isOpened()) revert BookNotOpened();
    }

    function depth(State storage self, Tick tick) internal view returns (uint64) {
        return self.queues[tick].tree.total() - self.totalClaimableOf.get(tick);
    }

    function highest(State storage self) internal view returns (Tick) {
        return self.tickBitmap.highest();
    }

    function maxLessThan(State storage self, Tick tick) internal view returns (Tick) {
        return self.tickBitmap.maxLessThan(tick);
    }

    function isEmpty(State storage self) internal view returns (bool) {
        return self.tickBitmap.isEmpty();
    }

    function _getOrder(State storage self, Tick tick, uint40 index) private view returns (Order storage) {
        return self.queues[tick].orders[index];
    }

    function getOrder(State storage self, Tick tick, uint40 index) internal view returns (Order memory) {
        return _getOrder(self, tick, index);
    }

    function make(State storage self, Tick tick, uint64 amount, address provider)
        external
        returns (uint40 orderIndex)
    {
        if (amount == 0) revert ZeroAmount();
        if (!self.tickBitmap.has(tick)) self.tickBitmap.set(tick);

        Queue storage queue = self.queues[tick];
        // @dev Assume that orders.length cannot reach to type(uint40).max + 1.
        orderIndex = SafeCast.toUint40(queue.orders.length);

        if (orderIndex >= MAX_ORDER) {
            unchecked {
                uint40 staleOrderIndex = orderIndex - MAX_ORDER;
                uint64 stalePendingAmount = queue.orders[staleOrderIndex].pending;
                if (stalePendingAmount > 0) {
                    // If the order is not settled completely, we cannot replace it
                    uint64 claimable = calculateClaimableRawAmount(self, tick, staleOrderIndex);
                    if (claimable != stalePendingAmount) revert QueueReplaceFailed();
                }
            }

            // The stale order is settled completely, so remove it from the totalClaimableOf.
            // We can determine the stale order is claimable.
            uint64 staleOrderedAmount = queue.tree.get(orderIndex & MAX_ORDER_M);
            if (staleOrderedAmount > 0) self.totalClaimableOf.sub(tick, staleOrderedAmount);
        }

        queue.tree.update(orderIndex & MAX_ORDER_M, amount);

        queue.orders.push(Order({pending: amount, provider: provider}));
    }

    /**
     * @notice Take orders from the book
     * @param self The book state
     * @param maxTakeAmount The maximum amount to take
     * @return takenAmount The actual amount to take
     */
    function take(State storage self, Tick tick, uint64 maxTakeAmount) external returns (uint64 takenAmount) {
        uint64 currentDepth = depth(self, tick);
        if (currentDepth > maxTakeAmount) {
            takenAmount = maxTakeAmount;
        } else {
            takenAmount = currentDepth;
            self.tickBitmap.clear(tick);
        }

        self.totalClaimableOf.add(tick, takenAmount);
    }

    function cancel(State storage self, OrderId orderId, uint64 to)
        external
        returns (uint64 canceled, uint64 afterPending)
    {
        (, Tick tick, uint40 orderIndex) = orderId.decode();
        Queue storage queue = self.queues[tick];
        uint64 pending = queue.orders[orderIndex].pending;
        uint64 claimableRaw = calculateClaimableRawAmount(self, tick, orderIndex);
        afterPending = to + claimableRaw;
        unchecked {
            if (pending < afterPending) revert CancelFailed(pending - claimableRaw);
            canceled = pending - afterPending;

            self.queues[tick].tree.update(
                orderIndex & MAX_ORDER_M, self.queues[tick].tree.get(orderIndex & MAX_ORDER_M) - canceled
            );
        }
        queue.orders[orderIndex].pending = afterPending;

        if (depth(self, tick) == 0) {
            // clear() won't revert so we can cancel with to=0 even if the depth() is already zero
            // works even if bitmap is empty
            self.tickBitmap.clear(tick);
        }
    }

    function claim(State storage self, Tick tick, uint40 index) external returns (uint64 claimedRaw) {
        Order storage order = _getOrder(self, tick, index);

        claimedRaw = calculateClaimableRawAmount(self, tick, index);
        unchecked {
            order.pending -= claimedRaw;
        }
    }

    function calculateClaimableRawAmount(State storage self, Tick tick, uint40 index) public view returns (uint64) {
        uint64 orderAmount = self.getOrder(tick, index).pending;

        Queue storage queue = self.queues[tick];
        // @dev Book logic always considers replaced orders as claimable.
        unchecked {
            if (uint256(index) + MAX_ORDER < queue.orders.length) return orderAmount;
            uint64 totalClaimable = self.totalClaimableOf.get(tick);
            uint64 rangeRight = _getClaimRangeRight(queue, index);
            if (rangeRight - orderAmount >= totalClaimable) return 0;

            // -------- totalClaimable ---------|---
            // ------|---- orderAmount ----|--------
            //   rangeLeft           rangeRight
            if (rangeRight <= totalClaimable) return orderAmount;
            // -- totalClaimable --|----------------
            // ------|---- orderAmount ----|--------
            //   rangeLeft           rangeRight
            else return totalClaimable - (rangeRight - orderAmount);
        }
    }

    function _getClaimRangeRight(Queue storage queue, uint256 orderIndex) private view returns (uint64 rangeRight) {
        uint256 l = queue.orders.length & MAX_ORDER_M;
        uint256 r = (orderIndex + 1) & MAX_ORDER_M;
        rangeRight = (l < r) ? queue.tree.query(l, r) : queue.tree.total() - queue.tree.query(r, l);
    }
}