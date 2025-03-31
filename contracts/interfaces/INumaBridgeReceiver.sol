//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;



interface INumaBridgeReceiver 
{

    function onReceive(
        uint _numaAmount,
        uint _minLstAmount,
        address _receiver
       
    ) external  returns (uint _lstOut);
   
}