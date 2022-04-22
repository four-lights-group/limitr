// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

struct SDLL {
    mapping(uint256 => uint256) _next;
    mapping(uint256 => uint256) _prev;
}

library SortedDoubleLinkedList {
    function first(SDLL storage s) internal view returns (uint256) {
        return s._next[0];
    }

    function last(SDLL storage s) internal view returns (uint256) {
        return s._prev[0];
    }

    function next(SDLL storage s, uint256 current)
        internal
        view
        returns (uint256)
    {
        return s._next[current];
    }

    function previous(SDLL storage s, uint256 current)
        internal
        view
        returns (uint256)
    {
        return s._prev[current];
    }

    function insertWithPointer(
        SDLL storage s,
        uint256 value,
        uint256 pointer
    ) internal returns (bool) {
        uint256 n = pointer;
        while (true) {
            n = s._next[n];
            if (n == 0 || n > value) {
                break;
            }
        }
        uint256 p = s._prev[n];
        s._next[p] = value;
        s._prev[n] = value;
        s._next[value] = n;
        s._prev[value] = p;
        return true;
    }

    function insert(SDLL storage s, uint256 value) internal returns (bool) {
        return insertWithPointer(s, value, 0);
    }

    function remove(SDLL storage s, uint256 value) internal {
        uint256 p = s._prev[value];
        uint256 n = s._next[value];
        s._prev[n] = p;
        s._next[p] = n;
        s._prev[value] = 0;
        s._next[value] = 0;
    }
}
