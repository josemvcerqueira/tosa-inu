// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

contract BlackList {
    mapping(address => bool) private _isBlacklisted;

    constructor() {
        _isBlacklisted[0xE4882975f933A199C92b5A925C9A8fE65d599Aa8] = true;
        _isBlacklisted[0x86C70C4a3BC775FB4030448c9fdb73Dc09dd8444] = true;
        _isBlacklisted[0xa4A25AdcFCA938aa030191C297321323C57148Bd] = true;
        _isBlacklisted[0x20C00AFf15Bb04cC631DB07ee9ce361ae91D12f8] = true;
        _isBlacklisted[0x0538856b6d0383cde1709c6531B9a0437185462b] = true;
        _isBlacklisted[0x6e44DdAb5c29c9557F275C9DB6D12d670125FE17] = true;
        _isBlacklisted[0x90484Bb9bc05fD3B5FF1fe412A492676cd81790C] = true;
        _isBlacklisted[0xA62c5bA4D3C95b3dDb247EAbAa2C8E56BAC9D6dA] = true;
        _isBlacklisted[0xA94E56EFc384088717bb6edCccEc289A72Ec2381] = true;
        _isBlacklisted[0x3066Cc1523dE539D36f94597e233719727599693] = true;
        _isBlacklisted[0xf13FFadd3682feD42183AF8F3f0b409A9A0fdE31] = true;
        _isBlacklisted[0x376a6EFE8E98f3ae2af230B3D45B8Cc5e962bC27] = true;
        _isBlacklisted[0x0538856b6d0383cde1709c6531B9a0437185462b] = true;
        _isBlacklisted[0x90484Bb9bc05fD3B5FF1fe412A492676cd81790C] = true;
        _isBlacklisted[0xA62c5bA4D3C95b3dDb247EAbAa2C8E56BAC9D6dA] = true;
        _isBlacklisted[0xA94E56EFc384088717bb6edCccEc289A72Ec2381] = true;
        _isBlacklisted[0x3066Cc1523dE539D36f94597e233719727599693] = true;
        _isBlacklisted[0xf13FFadd3682feD42183AF8F3f0b409A9A0fdE31] = true;
        _isBlacklisted[0x376a6EFE8E98f3ae2af230B3D45B8Cc5e962bC27] = true;
        _isBlacklisted[0x201044fa39866E6dD3552D922CDa815899F63f20] = true;
        _isBlacklisted[0x6F3aC41265916DD06165b750D88AB93baF1a11F8] = true;
        _isBlacklisted[0x27C71ef1B1bb5a9C9Ee0CfeCEf4072AbAc686ba6] = true;
        _isBlacklisted[0xDEF441C00B5Ca72De73b322aA4e5FE2b21D2D593] = true;
        _isBlacklisted[0x5668e6e8f3C31D140CC0bE918Ab8bB5C5B593418] = true;
        _isBlacklisted[0x4b9BDDFB48fB1529125C14f7730346fe0E8b5b40] = true;
        _isBlacklisted[0x7e2b3808cFD46fF740fBd35C584D67292A407b95] = true;
        _isBlacklisted[0xe89C7309595E3e720D8B316F065ecB2730e34757] = true;
        _isBlacklisted[0x725AD056625326B490B128E02759007BA5E4eBF1] = true;
    }

    function _addToBlacklist(address _account) internal {
        _isBlacklisted[_account] = true;
    }

    function _removeFromBlacklist(address _account) internal {
        _isBlacklisted[_account] = false;
    }

    function isBlacklisted(address _account) public view returns (bool) {
        return _isBlacklisted[_account];
    }
}
