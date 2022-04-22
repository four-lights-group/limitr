// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

struct DLL {
    mapping(uint256 => uint256) _next;
    mapping(uint256 => uint256) _prev;
}

library DoubleLinkedList {
    function first(DLL storage dll) internal view returns (uint256) {
        return dll._next[0];
    }

    function last(DLL storage dll) internal view returns (uint256) {
        return dll._prev[0];
    }

    function next(DLL storage dll, uint256 current)
        internal
        view
        returns (uint256)
    {
        return dll._next[current];
    }

    function previous(DLL storage dll, uint256 current)
        internal
        view
        returns (uint256)
    {
        return dll._prev[current];
    }

    function insertBeginning(DLL storage dll, uint256 value) internal {
        insertAfter(dll, value, 0);
    }

    function insertEnd(DLL storage dll, uint256 value) internal {
        insertBefore(dll, value, 0);
    }

    function insertAfter(
        DLL storage dll,
        uint256 value,
        uint256 _prev
    ) internal {
        uint256 _next = dll._next[_prev];
        dll._next[_prev] = value;
        dll._prev[_next] = value;
        dll._next[value] = _next;
        dll._prev[value] = _prev;
    }

    function insertBefore(
        DLL storage dll,
        uint256 value,
        uint256 _next
    ) internal {
        uint256 _prev = dll._prev[_next];
        dll._next[_prev] = value;
        dll._prev[_next] = value;
        dll._next[value] = _next;
        dll._prev[value] = _prev;
    }

    function remove(DLL storage dll, uint256 value) internal {
        uint256 p = dll._prev[value];
        uint256 n = dll._next[value];
        dll._prev[n] = p;
        dll._next[p] = n;
        dll._prev[value] = 0;
        dll._next[value] = 0;
    }
}
